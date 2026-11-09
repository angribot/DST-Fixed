local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 762172: the Ancient Gateway can spawn a keystone hand
-- every second and leak its shadowhand_arm each time, piling up thousands of
-- arms until the shard restarts. Two vanilla bugs combine:
-- - atrium_gate.lua clears inst.players and cancels charlie_hand_keystone_task
--   only in OnPlayerFar, but playerprox's AllPlayers mode drops removed players
--   without calling onfar. After a player disconnects or migrates inside the
--   arena, the task keeps running while the gateway sleeps, and respawns the
--   keystone hand whenever a Keystone lies nearby.
-- - charlie_hand.lua's Initialize moves the hand before spawning its arm. The
--   keystone hand removes itself on entity sleep, so if it lands in a sleeping
--   area it is gone before the arm exists, and nothing removes the arm.
-- After a game update, recheck OnPlayerNear/OnPlayerFar and
-- UpdateCharlieHandKeyStone in scripts/prefabs/atrium_gate.lua, and Initialize,
-- SpawnShadowArm and the keystone hand's OnEntitySleep in
-- scripts/prefabs/charlie_hand.lua. Remove each patch once vanilla handles its
-- case, and this module and its modmain entry once both are fixed.

AddPrefabPostInit("atrium_gate", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	local playerprox = inst.components.playerprox
	local onnear = playerprox ~= nil and playerprox.onnear or nil
	local onfar = playerprox ~= nil and playerprox.onfar or nil
	if onnear == nil or onfar == nil then
		return
	end

	local function OnPlayerRemoved(player)
		-- Vanilla OnPlayerFar indexes inst.players, which is nil once the last
		-- player has left.
		if inst.players ~= nil and inst.players[player] then
			onfar(inst, player)
		end
	end

	playerprox:SetOnPlayerNear(function(inst, player)
		inst:RemoveEventCallback("onremove", OnPlayerRemoved, player)
		inst:ListenForEvent("onremove", OnPlayerRemoved, player)
		onnear(inst, player)
	end)

	playerprox:SetOnPlayerFar(function(inst, player)
		inst:RemoveEventCallback("onremove", OnPlayerRemoved, player)
		onfar(inst, player)
	end)
end)

AddPrefabPostInit("charlie_hand_keystone", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	local SpawnShadowArm = inst.SpawnShadowArm
	if SpawnShadowArm == nil then
		return
	end

	inst.SpawnShadowArm = function(inst, ...)
		local arm = SpawnShadowArm(inst, ...)
		if inst:IsValid() then
			return arm
		end
		-- The hand already ran its OnRemoveEntity without an arm to clean up.
		arm:Remove()
		return nil
	end
end)
