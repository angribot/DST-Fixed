GLOBAL.setfenv(1, GLOBAL)
local UpvalueUtil = require("upvalueutil")

local FUELTYPE = "nightmarefuel"
local CHS_CODE = {
	zh = true,
	zht = true,
	chs = true,
}
STRINGS.ACTIONS.BLINK_MAP.GENERIC = CHS_CODE[LanguageTranslator.defaultlang] and "传送({uses})" or "Telepoof({uses})"

local function IsMioBoosted(doer)
	return doer and doer:HasTag("mio_boosted_task")
end

local function IsOrangeKingCane(staff)
	return staff and staff.prefab == "king_cane" and staff._gem:value() == "orangegem"
end

local function ValidateUses(act)
	if IsOrangeKingCane(act.invobject) then
		return not act.invobject:HasTag("nomagiccast") and act.invobject.components.rechargeable:IsCharged()
	end
	if act.invobject and act.invobject.components.blinkstaff then
		local num = act.distancecount
		local staffuses = act.invobject.components.finiteuses:GetUses()

		if IsMioBoosted(act.doer) then
			local is_fuel_enough, fuel_num = act.doer.components.inventory:Has(FUELTYPE, num)
			return is_fuel_enough or (fuel_num + staffuses) >= num
		end
		return staffuses >= num
	end
end

local function ClientValidateUses(act)
	if IsOrangeKingCane(act.invobject) then
		return not act.invobject:HasTag("nomagiccast")
	end
	if act.invobject and act.invobject.prefab == "orangestaff" then
		local num = act.distancecount
		local staffuses = (act.invobject.replica.inventoryitem.classified.percentused:value() or 0) * TUNING.ORANGESTAFF_USES / 100

		if IsMioBoosted(act.doer) then
			local is_fuel_enough, fuel_num = act.doer.replica.inventory:Has(FUELTYPE, num)
			return is_fuel_enough or (fuel_num + staffuses) >= num
		end
		return staffuses >= num
	end
end

local BlinkStaff = require("components/blinkstaff")
local on_blinked = UpvalueUtil.GetUpvalue(BlinkStaff.Blink, "OnBlinked")
local function OnBlinked(...)
	on_blinked(...)

	-- == -- == --
	-- CV from KELI :angri:
	if TheWorld and TheWorld.components.walkableplatformmanager then -- NOTES(JBK): Workaround for teleporting too far causing the client to lose sync.
		TheWorld.components.walkableplatformmanager:PostUpdate(0)
	end
	-- == -- == --
end
UpvalueUtil.SetUpvalue(BlinkStaff.Blink, "OnBlinked", OnBlinked)

local function BlinkKingCaneOnMap(act)
	local act_pos = act:GetActionPoint()
	local staff = act.invobject
	local blinkstaff = staff.components.blinkstaff
	local corruption = staff.components.corruption
	local corruption_per_use = TUNING.KING_CANE_CORRUPTION.orangegem
	local uncorrupted_uses = 0
	if not corruption:IsCorrupted() then
		local uses_until_corrupted = math.ceil((TUNING.KING_CANE_MAX_CORRUPTION - corruption:GetCurrent()) / corruption_per_use)
		uncorrupted_uses = math.min(act.distancecount, uses_until_corrupted)
	end
	local corrupted_uses = act.distancecount - uncorrupted_uses
	local onblinkfn = blinkstaff.onblinkfn

	if onblinkfn then
		blinkstaff.onblinkfn = function(inst, pos, caster)
			-- Settle the uncorrupted portion before the native onblink event adds corruption.
			for i = 1, math.max(1, uncorrupted_uses) do
				onblinkfn(inst, pos, caster)
			end
		end
	end
	local ok, blinked = pcall(blinkstaff.Blink, blinkstaff, act_pos, act.doer)
	blinkstaff.onblinkfn = onblinkfn
	if not ok then
		error(blinked, 0)
	end
	if blinked then
		if uncorrupted_uses > 1 then
			-- Blink already applied the first use's corruption through its native event.
			corruption:DoDelta(corruption_per_use * (uncorrupted_uses - 1))
		end
		if corrupted_uses > 0 then
			if uncorrupted_uses > 0 and onblinkfn then
				-- The remaining distance costs one corrupted cast, now that the staff is corrupted.
				onblinkfn(staff, act_pos, act.doer)
			end
			local rechargeable = staff.components.rechargeable
			rechargeable:SetChargeTime(rechargeable:GetChargeTime() * math.min(corrupted_uses, 20))
		end
	end
	return blinked
end

local function onblink_map(act)
	if IsOrangeKingCane(act.invobject) then
		return BlinkKingCaneOnMap(act)
	end
	local act_pos = act:GetActionPoint()
	if act.invobject.components.blinkstaff:Blink(act_pos, act.doer) then
		if act.invobject and act.invobject.components.blinkstaff.onblinkfn then
			-- Cunsume Extra Uses
			local num = act.distancecount - 1
			if num > 0 then
				for i = 1, num do
					act.invobject.components.blinkstaff.onblinkfn(act.invobject, act_pos, act.doer)
				end
			end
		end
		return true
	end
end

local blink_map_code = ACTIONS_MAP_REMAP[ACTIONS.BLINK.code]

local action_can_map_soulhop = UpvalueUtil.GetUpvalue(ACTIONS.BLINK_MAP.fn, "ActionCanMapSoulhop")

local function ActionCanMapSoulhop(act)
	if act.doer and ClientValidateUses(act) then
		return true
	end
	return action_can_map_soulhop(act)
end
UpvalueUtil.SetUpvalue(ACTIONS.BLINK_MAP.fn, "ActionCanMapSoulhop", ActionCanMapSoulhop)

local blink_map_fn = ACTIONS.BLINK_MAP.fn
ACTIONS.BLINK_MAP.fn = function(act)
	if ActionCanMapSoulhop(act) then
		if act.invobject and act.invobject.components.blinkstaff and ValidateUses(act) then
			return onblink_map(act)
		end
	end
	return blink_map_fn(act)
end

local blink_map_stroverridefn = ACTIONS.BLINK_MAP.stroverridefn
ACTIONS.BLINK_MAP.stroverridefn = function(act)
	if IsOrangeKingCane(act.invobject) and act.doer then
		local uses = act.invobject:HasTag("corrupted") and 1 or act.distancecount
		return subfmt(STRINGS.ACTIONS.BLINK_MAP.GENERIC, { uses = uses })
	end
	local blinkstaff = act.invobject and act.invobject.prefab == "orangestaff"
	local doer = act.doer

	if blinkstaff and doer then
		if IsMioBoosted(doer) then
			if doer.replica.inventory:Has(FUELTYPE, 1) then
				return subfmt(STRINGS.ACTIONS.BLINK_MAP.FUEL, { uses = act.distancecount })
			end
		end
		return subfmt(STRINGS.ACTIONS.BLINK_MAP.GENERIC, { uses = act.distancecount })
	end
	return blink_map_stroverridefn(act)
end
