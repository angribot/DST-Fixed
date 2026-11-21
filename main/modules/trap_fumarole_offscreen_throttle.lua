local AddComponentPostInit = AddComponentPostInit
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla keeps Coals running at full rate away from players: each placed Coals
-- scans for targets every 0.5 seconds, and trapfumaroleburning updates every
-- frame on everything it burns, so a Coals farm covered in loot keeps costing
-- server time with nobody nearby. trap_fumarole.lua declares
-- UPDATE_TIME_ASLEEP = 2.5 for this but never uses it; this module applies it to
-- both the scans and the burning targets while they sleep.
local ASLEEP_PERIOD = 2.5
-- StartUpdateTask in trap_fumarole.lua
local AWAKE_PERIOD = 0.5

--------------------------------------------------------------------------
-- Burning targets

-- Once a burnable passes TRAP_FUMAROLE_IGNITE_TIME, each OnUpdate call adds a
-- fixed TRAP_FUMAROLE_PROPAGATOR_RATE of heat. Propagator:AddHeat accepts only
-- max_heat_this_update per 0.5-second propagator update and the heat decays in
-- between, so the burnable reaches its flashpoint only at per-frame call rates.
-- AddHeat adds nothing during a propagator delay, to fireimmune targets, or on
-- tiles with no_fire_spread, where GetHeatResistance is 0; those stay slow.
local function IsHeatingToIgnite(self)
	local inst = self.inst
	local propagator = inst.components.propagator
	return self.ignitetime > TUNING.TRAP_FUMAROLE_IGNITE_TIME
		and inst.components.cookable == nil
		and propagator ~= nil
		and propagator:AcceptsHeat()
		and propagator.delay == nil
		and not inst:HasTag("fireimmune")
		and propagator:GetHeatResistance() > 0
end

local function GetAsleepPeriod(self)
	return IsHeatingToIgnite(self) and FRAMES or ASLEEP_PERIOD
end

local AsleepUpdate

local function ScheduleAsleepUpdate(self, period, initialdelay)
	self._asleeptask = self.inst:DoPeriodicTask(period, AsleepUpdate, initialdelay, self)
end

local function CancelAsleepUpdate(self)
	self._asleeptask:Cancel()
	self._asleeptask = nil
end

AsleepUpdate = function(inst, self)
	local time = GetTime()
	local dt = time - self._asleepupdatetime
	self._asleepupdatetime = time
	self:OnUpdate(dt)

	-- OnUpdate removes this component once the target is off Coals, and removes
	-- the entity when it cooks a single item.
	if inst:IsValid() and inst.components.trapfumaroleburning == self then
		local period = GetAsleepPeriod(self)
		if period ~= self._asleeptask.period then
			CancelAsleepUpdate(self)
			ScheduleAsleepUpdate(self, period)
		end
	end
end

local function StartAsleepUpdate(self)
	-- Health:OnUpdate ends a burn after 0.5 seconds without fire damage
	-- (FIRE_TIMEOUT), and Health:DoFireDamage deals none during a burn's first
	-- second (fire_timestart), so creatures updated less often than that never
	-- take damage. Leave them on per-frame updates.
	if self.inst.components.health ~= nil then
		return
	end

	self.inst:StopUpdatingComponent(self)
	self._asleepupdatetime = GetTime()
	local period = GetAsleepPeriod(self)
	-- A random first delay spreads targets that fall asleep together across frames.
	ScheduleAsleepUpdate(self, period, math.random() * period)
end

local function CatchUp(inst, self, dt)
	if inst.components.trapfumaroleburning == self then
		self:OnUpdate(dt)
	end
end

local function StopAsleepUpdate(self)
	-- Creatures never left per-frame updates.
	if self._asleeptask == nil then
		return
	end

	CancelAsleepUpdate(self)
	self.inst:StartUpdatingComponent(self)
	-- Catch up on the time since the last asleep update in a later tick: OnUpdate
	-- can remove the entity by cooking it, and OnEntityWake in mainfunctions.lua
	-- goes on to wake its other components, such as inventoryitemmoisture, which
	-- would start tasks on the removed entity.
	self.inst:DoTaskInTime(0, CatchUp, self, GetTime() - self._asleepupdatetime)
end

AddComponentPostInit("trapfumaroleburning", function(self, inst)
	self.OnEntitySleep = StartAsleepUpdate
	self.OnEntityWake = StopAsleepUpdate

	local OnRemoveFromEntity = self.OnRemoveFromEntity
	function self:OnRemoveFromEntity(...)
		if self._asleeptask ~= nil then
			CancelAsleepUpdate(self)
		end
		return OnRemoveFromEntity(self, ...)
	end

	-- Coals scanning while asleep add this component to targets already asleep,
	-- which get no OnEntitySleep call.
	if inst:IsAsleep() then
		StartAsleepUpdate(self)
	end
end)

--------------------------------------------------------------------------
-- Coals scans

-- inst.task is the scan task that CheckActiveTrap in trap_fumarole.lua starts
-- and cancels; IsActiveTrap only checks that it exists. Restarting it keeps
-- the vanilla scan function and only changes the period.
local function SetScanPeriod(inst, period)
	local task = inst.task
	if task ~= nil and task.period ~= period then
		-- Periodic:Cancel clears fn, so read it first.
		local fn = task.fn
		task:Cancel()
		-- A random first delay spreads Coals that change state together across
		-- frames, like StartUpdateTask does.
		inst.task = inst:DoPeriodicTask(period, fn, math.random() * period)
	end
end

local function OnEntitySleep(inst)
	SetScanPeriod(inst, ASLEEP_PERIOD)
end

local function OnEntityWake(inst)
	-- Restart instead of waiting out the slow period, so targets arriving as the
	-- Coals wake are found within 0.5 seconds as in vanilla.
	SetScanPeriod(inst, AWAKE_PERIOD)
end

AddPrefabPostInit("trap_fumarole", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst:ListenForEvent("entitysleep", OnEntitySleep)
	inst:ListenForEvent("entitywake", OnEntityWake)
end)
