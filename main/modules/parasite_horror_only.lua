GLOBAL.setfenv(1, GLOBAL)

-- Negative so the mask roll fails even when math.random() returns 0.
TUNING.DROP_SHADOWTHRALL_MASKHAT_CHANCE = -1

-- The mask's death handler sets was_shadowthrall_parasited before the buffered death state drops loot.
local _DropDeathLoot = EntityScript.DropDeathLoot
function EntityScript:DropDeathLoot(...)
	if self.was_shadowthrall_parasited then
		-- Still mark the death loot as handled, as the vanilla function does.
		self:SetDeathLootLevel(1)
		return
	end
	return _DropDeathLoot(self, ...)
end
