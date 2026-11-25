local AddAction = AddAction
local AddPrefabPostInit = AddPrefabPostInit
local AddComponentAction = AddComponentAction
local AddStategraphActionHandler = AddStategraphActionHandler
local AddStategraphState = AddStategraphState
GLOBAL.setfenv(1, GLOBAL)

AddPrefabPostInit("pocketwatch_recall", function(inst)
	if not inst.components.talker then
		inst:AddComponent("talker")
	end
end)

local JUMPINWATCH = Action({ rmb = true, distance = 0.1, priority = 2 })
JUMPINWATCH.id = "JUMPINWATCH"
JUMPINWATCH.str = ACTIONS.JUMPIN.str
JUMPINWATCH.fn = function(act)
	local doer = act.doer
	if
		doer
		and doer.sg
		and doer.sg.currentstate.name == "wortox_pocketwatch_jumpin_pre"
		and act.target
		and act.target.components.pocketwatch
		and doer.components.inventory
		and doer.components.inventory:Has("wortox_soul", 1)
		and act.target.components.pocketwatch:CastSpell(doer)
	then
		doer.components.inventory:ConsumeByName("wortox_soul", 1)
		doer.sg.statemem.spell_watch = act.target
		-- Vanilla prefabs/pocketwatch.lua:Recall_DoCastSpell (763928): sets sg.statemem.warpback
		doer.sg:GoToState("wortox_pocketwatch_jumpin", doer.sg.statemem)
	end
	return true
end

AddAction(JUMPINWATCH)
AddComponentAction("SCENE", "pocketwatch", function(inst, doer, actions, right)
	if
		right
		and inst.prefab == "pocketwatch_recall"
		and inst:HasTag("pocketwatch_inactive")
		and not inst:HasTag("recall_unmarked")
		and doer:HasTag("souleater")
		and doer.replica.inventory:Has("wortox_soul", 1)
	then
		table.insert(actions, ACTIONS.JUMPINWATCH)
	end
end)

local actionhandlers = {
	ActionHandler(JUMPINWATCH, "wortox_pocketwatch_jumpin_pre"),
}

local function DoWortoxPortalTint(inst, val)
	if val > 0 then
		inst.components.colouradder:PushColour("portaltint", 154 / 255 * val, 23 / 255 * val, 19 / 255 * val, 0)
		val = 1 - val
		inst.AnimState:SetMultColour(val, val, val, 1)
	else
		inst.components.colouradder:PopColour("portaltint")
		inst.AnimState:SetMultColour(1, 1, 1, 1)
	end
end

local states = {
	State({
		name = "wortox_pocketwatch_jumpin_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("wortox_portal_jumpin_pre")

			local buffaction = inst:GetBufferedAction()
			if buffaction ~= nil and buffaction.pos ~= nil then
				inst:ForceFacePoint(buffaction:GetActionPoint():Get())
			end
		end,

		events = {
			EventHandler("animover", function(inst)
				if inst.AnimState:AnimDone() and not inst:PerformBufferedAction() then
					inst.sg:GoToState("idle")
				end
			end),
		},
	}),

	State({
		name = "wortox_pocketwatch_jumpin",
		tags = { "busy", "pausepredict", "nodangle", "nomorph" },

		onenter = function(inst, data)
			inst.sg.statemem = data

			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("wortox_portal_jumpin")
			SpawnPrefab("wortox_portal_jumpin_fx").Transform:SetPosition(inst.Transform:GetWorldPosition())
			inst.sg:SetTimeout(11 * FRAMES)

			local warpback = inst.sg.statemem.warpback
			local dest_worldid = warpback.dest_worldid
			if dest_worldid and dest_worldid == TheShard:GetShardId() then
				inst:ForceFacePoint(warpback.dest_x, warpback.dest_y, warpback.dest_z)
			end

			if inst.components.playercontroller then
				inst.components.playercontroller:RemotePausePrediction()
			end
		end,

		onupdate = function(inst)
			if inst.sg.statemem.tints then
				DoWortoxPortalTint(inst, table.remove(inst.sg.statemem.tints))
				if #inst.sg.statemem.tints <= 0 then
					inst.sg.statemem.tints = nil
				end
			end
		end,

		timeline = {
			TimeEvent(FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/infection_post", nil, 0.7)
				inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, 0.5)
			end),
			TimeEvent(2 * FRAMES, function(inst)
				inst.sg.statemem.tints = { 1, 0.6, 0.3, 0.1 }
				PlayFootstep(inst)
			end),
			TimeEvent(4 * FRAMES, function(inst)
				inst.sg:AddStateTag("noattack")
				inst.components.health:SetInvincible(true)
				inst.DynamicShadow:Enable(false)
				local spell_watch = inst.sg.statemem.spell_watch
				if spell_watch:IsValid() then
					spell_watch.components.talker:Say("󰂡 ?")
					Launch(spell_watch, inst, 0.5)
				end
			end),
		},

		ontimeout = function(inst)
			local warpback = inst.sg.statemem.warpback
			local dest_worldid = warpback.dest_worldid
			if dest_worldid and dest_worldid ~= TheShard:GetShardId() then
				if Shard_IsWorldAvailable(dest_worldid) then
					TheWorld:PushEvent("ms_playerdespawnandmigrate", {
						player = inst,
						worldid = dest_worldid,
						x = warpback.dest_x,
						y = warpback.dest_y,
						z = warpback.dest_z,
					})
					return
				else
					warpback.dest_x, warpback.dest_y, warpback.dest_z = inst.Transform:GetWorldPosition()
				end
			end
			inst.sg.statemem.portaljumping = true
			inst.sg:GoToState("wortox_pocketwatch_jumpout", inst.sg.statemem)
		end,

		onexit = function(inst)
			if not inst.sg.statemem.portaljumping then
				inst.components.health:SetInvincible(false)
				inst.DynamicShadow:Enable(true)
				DoWortoxPortalTint(inst, 0)
			end
		end,
	}),

	State({
		name = "wortox_pocketwatch_jumpout",
		tags = { "busy", "nopredict", "nomorph", "noattack", "nointerrupt" },

		onenter = function(inst, data)
			inst.sg.statemem = data

			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("wortox_portal_jumpout")

			local warpback = inst.sg.statemem.warpback
			local x, y, z = warpback.dest_x, warpback.dest_y, warpback.dest_z
			inst.Physics:Teleport(x, y, z)

			SpawnPrefab("wortox_portal_jumpout_fx").Transform:SetPosition(x, y, z)
			inst.DynamicShadow:Enable(false)
			inst.sg:SetTimeout(14 * FRAMES)
			DoWortoxPortalTint(inst, 1)
			inst.components.health:SetInvincible(true)
			inst:PushEvent("soulhop")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.tints ~= nil then
				DoWortoxPortalTint(inst, table.remove(inst.sg.statemem.tints))
				if #inst.sg.statemem.tints <= 0 then
					inst.sg.statemem.tints = nil
				end
			end
		end,

		timeline = {
			TimeEvent(FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/hop_out")
			end),
			TimeEvent(5 * FRAMES, function(inst)
				inst.sg.statemem.tints = { 0, 0.4, 0.7, 0.9 }
			end),
			TimeEvent(7 * FRAMES, function(inst)
				inst.components.health:SetInvincible(false)
				inst.sg:RemoveStateTag("noattack")
				inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
			end),
			TimeEvent(8 * FRAMES, function(inst)
				inst.DynamicShadow:Enable(true)
			end),
		},

		ontimeout = function(inst)
			inst.sg:GoToState("idle", true)
		end,

		onexit = function(inst)
			inst.components.health:SetInvincible(false)
			inst.DynamicShadow:Enable(true)
			DoWortoxPortalTint(inst, 0)
		end,
	}),
}

local TIMEOUT = 2
local states_client = {
	State({
		name = "wortox_pocketwatch_jumpin_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()

			inst.AnimState:PlayAnimation("wortox_portal_jumpin_pre")
			inst.AnimState:PushAnimation("wortox_portal_jumpin_lag", false)

			local buffaction = inst:GetBufferedAction()
			if buffaction ~= nil then
				inst:PerformPreviewBufferedAction()

				if buffaction.pos ~= nil then
					inst:ForceFacePoint(buffaction:GetActionPoint():Get())
				end
			end

			inst.sg:SetTimeout(TIMEOUT)
		end,

		onupdate = function(inst)
			if inst:HasTag("busy") then
				if inst.entity:FlattenMovementPrediction() then
					inst.sg:GoToState("idle", "noanim")
				end
			elseif inst.bufferedaction == nil then
				inst.sg:GoToState("idle")
			end
		end,

		ontimeout = function(inst)
			inst:ClearBufferedAction()
			inst.sg:GoToState("idle")
		end,
	}),
}

for _, actionhandler in pairs(actionhandlers) do
	AddStategraphActionHandler("wilson", actionhandler)
	AddStategraphActionHandler("wilson_client", actionhandler)
end

for _, state in pairs(states) do
	AddStategraphState("wilson", state)
end
for _, state in pairs(states_client) do
	AddStategraphState("wilson_client", state)
end
