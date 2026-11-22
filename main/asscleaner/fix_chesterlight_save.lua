local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 762172: scripts/prefabs/chesterlight.lua never sets
-- persists = false, so a light beam that exists when the world saves is written
-- to the save. Whatever was going to turn it off and remove it is not saved, so
-- after loading nothing ever removes it; it loads without an animation and with
-- a light radius of 0, and stays invisible but networked. Chester's "transition"
-- state in scripts/stategraphs/SGchester.lua keeps its light only in
-- sg.statemem, so a save during the transformation leaves one behind. Mourning
-- Glory into Dug Grave left one per honored grave at every dawn before 2.30.2.
-- This patch removes light beams restored from a save.
-- After a game update, recheck the chesterlight prefab and the "transition"
-- state in SGchester.lua. Remove this file and its modmain entry once
-- chesterlight no longer persists.

AddPrefabPostInit("chesterlight", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst.OnLoad = function(inst)
		inst:DoTaskInTime(0, inst.Remove)
	end
end)
