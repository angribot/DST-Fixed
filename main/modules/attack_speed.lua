local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

TUNING.WILSON_ATTACK_PERIOD = 0.1

-- Vanilla stategraphs/SGwilson.lua:blowdart (763928): keeps the "attack" tag until a 14-frame (chained) or 18-frame timeout; the dart leaves at frame 9 or 14
-- Vanilla components/playercontroller.lua:PlayerController:OnRemoteAttackButton (763928): checks "abouttoattack" instead only for remote predicting authorities
local function PatchBlowdartState(sg)
	local state = sg.states.blowdart
	if state == nil then
		return
	end

	local function EndAttackAfterShot(inst)
		local inst_sg = inst.sg
		if inst_sg.currentstate == state and inst_sg:HasStateTag("attack") and not inst_sg:HasStateTag("abouttoattack") then
			-- Vanilla stategraphs/SGwilson.lua:blowdart (763928): ontimeout makes the same change later
			inst_sg:RemoveStateTag("attack")
			inst_sg:AddStateTag("idle")
		end
	end

	-- Vanilla stategraphs/SGwilson.lua:blowdart (763928): runs the timeout apart from the timeline, so one on the firing frame can expire a frame before the shot
	for _, event in ipairs(state.timeline or {}) do
		local fn = event.fn
		event.fn = function(inst, ...)
			fn(inst, ...)
			EndAttackAfterShot(inst)
		end
	end

	-- Vanilla stategraphs/SGwilson.lua:blowdart (763928): fires from onupdate instead of the timeline for weapons with a projectiledelay
	local onupdate = state.onupdate
	state.onupdate = function(inst, ...)
		if onupdate ~= nil then
			onupdate(inst, ...)
		end
		EndAttackAfterShot(inst)
	end
end

AddStategraphPostInit("wilson", PatchBlowdartState)
-- Vanilla stategraphs/SGwilson_client.lua:blowdart (763928): the state lag-compensated clients predict with
AddStategraphPostInit("wilson_client", PatchBlowdartState)
