local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla's highlightchild dirty listener passes syncowner:value() straight to the
-- prefab's onchangeownerfn. While a client rebuilds entities (shard transitions,
-- deserialization), that netvar can still point at an entity that has not been
-- registered yet, so the owner arrives as nil and king_cane.lua:71 indexes it.
-- Wait for the owner to replicate instead of dropping the update.
local RETRY_FRAMES = 60

AddPrefabPostInit("king_cane_fx", function(inst)
	local highlightchild = inst.components.highlightchild
	local onchangeownerfn = highlightchild ~= nil and highlightchild.onchangeownerfn or nil
	if onchangeownerfn == nil then
		return
	end

	-- Bumped on every owner change so a stale retry cannot override a newer one.
	local generation = 0

	highlightchild.onchangeownerfn = function(inst, owner)
		generation = generation + 1

		if owner ~= nil then
			onchangeownerfn(inst, owner)
			return
		end

		local syncowner = highlightchild.syncowner
		if syncowner == nil then
			return
		end

		local token = generation
		local frames = 0
		local function retry()
			if token ~= generation then
				return
			end
			local resolved = syncowner:value()
			if resolved ~= nil then
				onchangeownerfn(inst, resolved)
			elseif frames < RETRY_FRAMES then
				frames = frames + 1
				inst:DoTaskInTime(0, retry)
			end
		end
		inst:DoTaskInTime(0, retry)
	end
end)
