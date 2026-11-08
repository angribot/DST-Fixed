local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 762172: a shadow hand that falls asleep while creeping
-- toward its fire never moves again. LocoMotor:OnEntitySleep calls Stop(), which
-- clears the destination, and OnEntityWake only resumes an updating locomotor.
-- The hand then waits for an outside trigger such as its fire going out, its
-- arm entering light, a player within 2 units, or "startday". Caves never push
-- "startday" (worldstate.lua keeps isnight true), so stuck hands and their arms
-- pile up around long-lasting cave fires (e.g. at the Ancient Gateway) until
-- the shard reloads, since neither persists.
-- After a game update, recheck LocoMotor:OnEntitySleep/StartUpdatingInternal,
-- and in scripts/prefabs/shadowhand.lua the hand's WatchWorldState, its
-- playerprox callbacks (Retreat/Regroup) and its use of inst.task and inst.fire.
-- Remove this module and its modmain entry once vanilla resumes or cleans up
-- sleeping hands.

local function OnEntityWake(inst)
	-- playerprox exists only until the hand grabs its fire or dissipates, and
	-- holds the vanilla Retreat (onnear) and Regroup (onfar, which restarts
	-- creeping after a short delay). A pending task or destination means the
	-- hand is still moving.
	local playerprox = inst.components.playerprox
	if
		playerprox == nil
		or playerprox.onnear == nil
		or playerprox.onfar == nil
		or inst.dissipating
		or inst.task ~= nil
		or inst.fire == nil
		or not inst.fire:IsValid()
		or inst.components.locomotor.dest ~= nil
	then
		return
	end
	-- Resume whichever move was cut off. playerprox wakes after this and
	-- switches between the two if players moved meanwhile.
	if playerprox:IsPlayerClose() then
		playerprox.onnear(inst)
	else
		playerprox.onfar(inst)
	end
end

local function CaveTimeout(inst)
	-- No one can see a sleeping hand, and its dissipate animation would not
	-- play until something woke it.
	if inst:IsAsleep() then
		inst:Remove()
	elseif inst.Dissipate ~= nil then
		inst:Dissipate()
	end
end

local function PatchHand(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst:ListenForEvent("entitywake", OnEntityWake)

	-- Stands in for the "startday" cleanup that caves never trigger.
	if TheWorld:HasTag("cave") then
		inst:DoTaskInTime(TUNING.TOTAL_DAY_TIME, CaveTimeout)
	end
end

AddPrefabPostInit("shadowhand", PatchHand)
AddPrefabPostInit("shadowhand_shrouded", PatchHand)
