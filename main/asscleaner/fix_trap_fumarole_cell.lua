local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 762172: trap_fumarole_util.lua's SetTrap asserts that
-- each 2x2 cell holds at most one placed Coals. A placed Coals moved without
-- SetItem keeps its old cell registered, so it can be saved inside another placed
-- Coals' cell. Loading then runs SetTrap for both, and the assert crashes the
-- shard on every load. A Great Depths Worm with a full inventory moves placed
-- Coals this way: worm_boss_util.lua's CollectThingsToEat passes them to the
-- head's LootDropper:FlingItem, which teleports them next to the head.
-- After a game update, recheck SetTrap in scripts/prefabs/trap_fumarole_util.lua,
-- OnLoad in scripts/prefabs/trap_fumarole.lua, and CollectThingsToEat in
-- scripts/prefabs/worm_boss_util.lua. Remove each patch once vanilla handles its
-- case, and this module and its modmain entry once both are fixed.
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
				-- Another placed Coals already holds this cell; load this one as an item.
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
			-- Same as DeactivateInventoryItemBeforeLaunch: unregister the cell and
			-- restore item physics before the Coals moves.
			loot:SetItem()
		end
		return FlingItem(self, loot, ...)
	end
end

AddPrefabPostInit("worm_boss_head", PatchWormHeadFling)
AddPrefabPostInit("worm_boss_shadow_head", PatchWormHeadFling)
