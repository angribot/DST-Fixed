local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 761239: mound.lua's Halloween bat task calls pos:Get()
-- without checking whether FindNearbyLand returned nil (e.g. offshore graves).
-- After a game update, recheck that task in scripts/prefabs/mound.lua. Remove
-- this module and its modmain entry once vanilla handles a missing land position.
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
