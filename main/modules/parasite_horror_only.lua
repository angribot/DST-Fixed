GLOBAL.setfenv(1, GLOBAL)

-- Vanilla componentutil.lua:TryLuckRoll (763928): succeeds when math.random() <= chance, which a chance of 0 still allows
TUNING.DROP_SHADOWTHRALL_MASKHAT_CHANCE = -1

-- Vanilla prefabs/hats.lua:fns.shadowthrall_parasite_ondeath (763928): sets was_shadowthrall_parasited before the death state drops loot
local _DropDeathLoot = EntityScript.DropDeathLoot
function EntityScript:DropDeathLoot(...)
	if self.was_shadowthrall_parasited then
		-- Vanilla entityscript.lua:EntityScript:DropDeathLoot (763928): marks the death loot as dropped first
		self:SetDeathLootLevel(1)
		return
	end
	return _DropDeathLoot(self, ...)
end
