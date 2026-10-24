AddPrefabPostInit("horseshoe", function(inst)
	if not GLOBAL.TheWorld.ismastersim then
		return
	end

	if inst.components.stackable ~= nil then
		inst.components.stackable.maxsize = 40
	end
end)
