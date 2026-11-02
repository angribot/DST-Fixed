GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 761239: worm_boss.lua's OnLoad removes the tail chunk's
-- dirt_start and sets it to nil when a full-length worm is loaded. If the worm was
-- saved while digging to a new spot, the new chunk makes it longer than full length,
-- and when the head emerges there, worm_boss_util.lua's EmergeHead calls
-- chunks[1].dirt_start:IsValid() on nil.
-- After a game update, recheck EmergeHead. Remove this module and its modmain entry
-- once vanilla checks for a missing tail dirt.
local WORMBOSS_UTILS = require("prefabs/worm_boss_util")

-- EmergeHead checks IsValid() before every use of the tail's dirt_start, so this
-- stand-in is skipped like a removed entity.
local REMOVED_DIRT = {
	IsValid = function()
		return false
	end,
}

local EmergeHead = WORMBOSS_UTILS.EmergeHead
WORMBOSS_UTILS.EmergeHead = function(inst, ...)
	local tail = inst.chunks[1]
	if tail == nil or tail.dirt_start ~= nil then
		return EmergeHead(inst, ...)
	end

	tail.dirt_start = REMOVED_DIRT
	EmergeHead(inst, ...)
	tail.dirt_start = nil
end
