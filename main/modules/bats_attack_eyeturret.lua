local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

AddPrefabPostInit("eyeturret", function(inst)
	local RETARGET_MUST_TAGS = { "_combat" }
	local RETARGET_CANT_TAGS = { "INLIMBO", "player", "eyeturret", "engineering" }

	local function NewRetargetfn(inst)
		local target = inst.components.combat.target
		if target ~= nil and target:IsValid() and inst:IsNear(target, TUNING.EYETURRET_RANGE + 3) then
			return
		end

		local playertargets = {}
		for _, v in ipairs(AllPlayers) do
			if v.components.combat.target ~= nil then
				playertargets[v.components.combat.target] = true
			end
		end

		local x, y, z = inst.Transform:GetWorldPosition()
		local ents = TheSim:FindEntities(x, y, z, TUNING.EYETURRET_RANGE + 3, RETARGET_MUST_TAGS, RETARGET_CANT_TAGS)
		for _, v in ipairs(ents) do
			if v ~= inst
				and v ~= target
				and v.entity:IsVisible()
				and inst.components.combat:CanTarget(v)
				and (
					playertargets[v]
					or v.components.combat:TargetIs(inst)
					or (v.components.combat.target ~= nil and v.components.combat.target:HasTag("player"))
					or v:HasTag("bat")
				)
			then
				return v
			end
		end
		return nil
	end

	if inst.components.combat then
		inst.components.combat:SetRetargetFunction(1, NewRetargetfn)
	end
end)
