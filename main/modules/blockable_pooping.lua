local AddPrefabPostInit = AddPrefabPostInit
local AddSimPostInit = AddSimPostInit
GLOBAL.setfenv(1, GLOBAL)

local BUNG_PREFAB = "trinket_8"

local __dummy = function() end

local function do_block(inst)
	inst.no_periodicspawn = true

	if inst.components.periodicspawner then
		inst.components.periodicspawner:Stop()
	end

	if inst.components.lootdropper then
		local lootsetupfn = inst.components.lootdropper.lootsetupfn or __dummy
		inst.components.lootdropper:SetLootSetupFn(function(lootdropper, ...)
			lootdropper:AddChanceLoot(BUNG_PREFAB, 1)
			return lootsetupfn(lootdropper, ...)
		end)
	end
end

local function on_trade(inst, data)
	if data.item.prefab == BUNG_PREFAB then
		do_block(inst)
	end
end

local function post_init(inst)
	if not TheWorld.ismastersim then
		return
	end

	if not inst.components.trader then
		inst:AddComponent("trader")
	end

	local should_accept_fn = inst.components.trader.test or __dummy
	inst.components.trader:SetAcceptTest(function(inst, item, giver, ...)
		if item.prefab == BUNG_PREFAB and not inst.no_periodicspawn then
			return true
		end
		return should_accept_fn(inst, item, giver, ...)
	end)

	inst:ListenForEvent("trade", on_trade)

	local on_save = inst.OnSave or __dummy
	inst.OnSave = function(inst, data, ...)
		data.no_periodicspawn = inst.no_periodicspawn
		return on_save(inst, data, ...)
	end

	local on_load = inst.OnLoad or __dummy
	inst.OnLoad = function(inst, data, ...)
		if data and data.no_periodicspawn then
			do_block(inst)
		end
		return on_load(inst, data, ...)
	end
end

local change_list = { "beefalo", "babybeefalo", "koalefant_summer", "koalefant_winter" }
for _, v in ipairs(change_list) do
	AddPrefabPostInit(v, post_init)
end

local UpvalueUtil = require("upvalueutil")
AddSimPostInit(function()
	-- Vanilla prefabs/beefaloherd.lua:SpawnableParent (763928): copy that skips members plugged with a Hardened Rubber Bung
	UpvalueUtil.SetUpvalue(Prefabs["beefaloherd"].fn, "OnSpawned.SpawnableParent", function(inst)
		for member in pairs(inst.components.herd.members) do
			if not member.no_periodicspawn then
				if member.components.domesticatable == nil or (member.components.domesticatable:IsDomesticated() == false and member.components.rideable:GetRider() == nil) then
					return member
				end
			end
		end
		return nil
	end)
end)
