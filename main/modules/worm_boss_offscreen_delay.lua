local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local UpvalueUtil = require("upvalueutil")

-- Seconds a Great Depths Worm stays offscreen before it is removed. A living
-- worm is stored in hounded first; a dead one is removed outright.
local OFFSCREEN_REMOVAL_DELAY = 300

-- Worm_OnEntitySleep and Worm_TestForRemoval in worm_boss.lua share the
-- file-local OFFSCREEN_REMOVAL_DELAY upvalue, so setting it once changes both
-- the first check delay and the removal threshold.
local function SetRemovalDelay(inst)
	if not TheWorld.ismastersim then
		return
	end

	UpvalueUtil.SetUpvalue(inst.OnEntitySleep, "OFFSCREEN_REMOVAL_DELAY", OFFSCREEN_REMOVAL_DELAY)
end

AddPrefabPostInit("worm_boss", SetRemovalDelay)
AddPrefabPostInit("worm_boss_shadow", SetRemovalDelay)
