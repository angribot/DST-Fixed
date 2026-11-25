GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/worm_boss.lua:OnLoad (763928): clears the tail's dirt_start on a full-length worm, which a worm saved mid-dig exceeds
-- Vanilla prefabs/worm_boss_util.lua:EmergeHead (763928): calls chunks[1].dirt_start:IsValid() without a nil check
local WORMBOSS_UTILS = require("prefabs/worm_boss_util")

-- Vanilla prefabs/worm_boss_util.lua:EmergeHead (763928): checks IsValid() before every use of the tail's dirt_start
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
