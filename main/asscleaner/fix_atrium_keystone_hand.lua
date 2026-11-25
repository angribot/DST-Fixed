local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/atrium_gate.lua:OnPlayerFar (763928): the only place that clears inst.players and cancels charlie_hand_keystone_task
-- Vanilla components/playerprox.lua:AllPlayers (763928): drops removed players without calling onfar
-- Vanilla prefabs/charlie_hand.lua:Initialize (763928): moves the hand before spawning its arm, and the keystone hand removes itself on sleep

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
		-- Vanilla prefabs/atrium_gate.lua:OnPlayerFar (763928): indexes inst.players, which is nil once the last player has left
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
		-- Vanilla prefabs/charlie_hand.lua:OnRemove (763928): removes the arm only if it existed when the hand was removed
		arm:Remove()
		return nil
	end
end)
