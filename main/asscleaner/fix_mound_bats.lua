local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/mound.lua:onfinishcallback (763928): the Halloween bat task calls pos:Get() on FindNearbyLand's result, which is nil offshore
local function FindLandForGraveBats(position, range)
	-- Bats can fly over water, so the grave itself is a valid fallback.
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
	if rawget(env, "FindNearbyLand") == FindLandForGraveBats then
		return
	end

	-- Delayed tasks inherit this environment. Patch the shared vanilla callback
	-- once, including honor_mound's saved reference, without changing the global finder.
	setfenv(onfinish, setmetatable({ FindNearbyLand = FindLandForGraveBats }, { __index = env }))
end)
