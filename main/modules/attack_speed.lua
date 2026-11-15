local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

TUNING.WILSON_ATTACK_PERIOD = 0.1

-- The blowdart state keeps its "attack" tag until a 14-frame (chained) or 18-frame
-- timeout, so the next attack on the same target waits although the dart leaves at
-- frame 9 or 14. Only admins with movement prediction skip this wait, because the
-- server checks "abouttoattack" for them instead. End the attack phase as soon as the
-- dart is fired so every player can chain the next shot.
local function PatchBlowdartState(sg)
	local state = sg.states.blowdart
	if state == nil then
		return
	end

	local function EndAttackAfterShot(inst)
		local inst_sg = inst.sg
		if inst_sg.currentstate == state
			and inst_sg:HasStateTag("attack")
			and not inst_sg:HasStateTag("abouttoattack") then
			-- Same as the vanilla ontimeout, which later repeats it harmlessly.
			inst_sg:RemoveStateTag("attack")
			inst_sg:AddStateTag("idle")
		end
	end

	-- Hook after the shot instead of shortening the timeout: the timeout and the timeline
	-- track time separately, so a timeout on the firing frame may expire one frame early
	-- and let a new attack restart the state before the dart is fired.
	for _, event in ipairs(state.timeline or {}) do
		local fn = event.fn
		event.fn = function(inst, ...)
			fn(inst, ...)
			EndAttackAfterShot(inst)
		end
	end

	-- Weapons with a projectile delay fire from onupdate instead of the timeline.
	local onupdate = state.onupdate
	state.onupdate = function(inst, ...)
		if onupdate ~= nil then
			onupdate(inst, ...)
		end
		EndAttackAfterShot(inst)
	end
end

AddStategraphPostInit("wilson", PatchBlowdartState)
-- Lag-compensated clients predict with this copy, so keep its timing in sync.
AddStategraphPostInit("wilson_client", PatchBlowdartState)
