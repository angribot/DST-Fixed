local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

--------------------------------------------------------------------------------
--------------------------- GREAT DEPTHS WORM TAIL -----------------------------
--------------------------------------------------------------------------------

-- Confirmed in DST build 761239: worm_boss.lua's OnLoad removes the tail chunk's
-- dirt_start and sets it to nil when a full-length worm is loaded. If the worm was
-- saved while digging to a new spot, the new chunk makes it longer than full length,
-- and when the head emerges there, worm_boss_util.lua's EmergeHead calls
-- chunks[1].dirt_start:IsValid() on nil.
-- After a game update, recheck EmergeHead. Remove this section once vanilla checks
-- for a missing tail dirt.
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

--------------------------------------------------------------------------------
----------------------------- WORM ATTACK TIMER --------------------------------
--------------------------------------------------------------------------------

-- Confirmed in DST build 761239: hounded.lua's PlanNextAttack(force) with no
-- active players clears _attackplanned but keeps the old positive _timetoattack,
-- then retries through an unsaved DoTaskInTime until a player joins. A Great
-- Depths Worm that despawns after everyone has left the caves takes this path.
-- If the shard saves and reloads before anyone returns, OnLoad replans without
-- force, which returns early because _timetoattack is positive, so OnUpdate never
-- counts down again and worm attacks stop for good.
-- After a game update, recheck PlanNextAttack and OnLoad in
-- scripts/components/hounded.lua. Remove this section once vanilla replans in that case.
AddComponentPostInit("hounded", function(self)
	local OnLoad = self.OnLoad
	self.OnLoad = function(self, data, ...)
		OnLoad(self, data, ...)

		if not data.attackplanned and self:GetTimeToAttack() > 0 then
			-- Restart the lost retry: a forced replan waits for players, as it would have before saving.
			self.inst:PushEvent("hounded_forceplannewattack")
		end
	end
end)
