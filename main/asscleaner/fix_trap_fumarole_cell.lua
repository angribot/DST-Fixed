local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/trap_fumarole_util.lua:SetTrap (763928): asserts that each 2x2 cell holds at most one placed Coals
-- Vanilla prefabs/trap_fumarole.lua:OnLoad (763928): runs SetTrap for each saved placed Coals, so two in one cell crash every load
-- Vanilla prefabs/worm_boss_util.lua:CollectThingsToEat (763928): flings placed Coals without SetItem, leaving their old cell registered
local TrapFumaroleUtil = require("prefabs/trap_fumarole_util")

AddPrefabPostInit("trap_fumarole", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	local OnLoad = inst.OnLoad
	if OnLoad == nil then
		return
	end

	inst.OnLoad = function(inst, data, ...)
		if data ~= nil and data.settrap ~= nil then
			local x, _, z = inst.Transform:GetWorldPosition()
			if TrapFumaroleUtil.HasTrapAtXZ(x, z) then
				data = shallowcopy(data)
				data.settrap = nil
			end
		end
		return OnLoad(inst, data, ...)
	end
end)

local function PatchWormHeadFling(inst)
	if not TheWorld.ismastersim then
		return
	end

	local lootdropper = inst.components.lootdropper
	if lootdropper == nil then
		return
	end

	local FlingItem = lootdropper.FlingItem
	lootdropper.FlingItem = function(self, loot, ...)
		if loot ~= nil and loot.prefab == "trap_fumarole" and not loot:IsItem() then
			-- Vanilla componentutil.lua:DeactivateInventoryItemBeforeLaunch (763928): calls SetItem before other launches
			loot:SetItem()
		end
		return FlingItem(self, loot, ...)
	end
end

AddPrefabPostInit("worm_boss_head", PatchWormHeadFling)
AddPrefabPostInit("worm_boss_shadow_head", PatchWormHeadFling)
