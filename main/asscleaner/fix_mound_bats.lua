local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/mound.lua:onfinishcallback (763928): the Halloween bat task calls pos:Get() on FindNearbyLand's result, which is nil offshore
local function FindLandOrStayOverWater(position, range)
	return FindNearbyLand(position, range) or position
end

AddPrefabPostInit("mound", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	local workable = inst.components.workable
	local onfinish = workable ~= nil and workable.onfinish or nil
	if onfinish == nil or not debug.getinfo(onfinish, "S").source:match("scripts/prefabs/mound%.lua$") then
		return
	end

	local env = getfenv(onfinish)
	if rawget(env, "FindNearbyLand") == FindLandOrStayOverWater then
		return
	end

	-- Vanilla prefabs/mound.lua:onfinishcallback (763928): reads FindNearbyLand in a DoTaskInTime closure, which takes this function's environment
	setfenv(onfinish, setmetatable({ FindNearbyLand = FindLandOrStayOverWater }, { __index = env }))
end)
