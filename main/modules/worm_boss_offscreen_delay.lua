local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local UpvalueUtil = require("upvalueutil")

local OFFSCREEN_REMOVAL_DELAY = 300

-- Vanilla prefabs/worm_boss.lua:Worm_OnEntitySleep (763928): shares the file-local OFFSCREEN_REMOVAL_DELAY with Worm_TestForRemoval
-- Vanilla prefabs/worm_boss.lua:Worm_TestForRemoval (763928): stores a living worm in hounded before removing it
local function SetRemovalDelay(inst)
	if not TheWorld.ismastersim then
		return
	end

	UpvalueUtil.SetUpvalue(inst.OnEntitySleep, "OFFSCREEN_REMOVAL_DELAY", OFFSCREEN_REMOVAL_DELAY)
end

AddPrefabPostInit("worm_boss", SetRemovalDelay)
AddPrefabPostInit("worm_boss_shadow", SetRemovalDelay)
