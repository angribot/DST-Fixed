local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/chesterlight.lua:fn (763928): saves the beam but not what turns it off, so a loaded beam stays invisible and networked forever
-- Vanilla stategraphs/SGchester.lua:transition (763928): keeps its beam only in sg.statemem

AddPrefabPostInit("chesterlight", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst.OnLoad = function(inst)
		inst:DoTaskInTime(0, inst.Remove)
	end
end)
