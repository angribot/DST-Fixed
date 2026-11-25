local AddComponentPostInit = AddComponentPostInit
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/trap_fumarole.lua:StartUpdateTask (763928): scans every 0.5 seconds whether asleep or not, leaving UPDATE_TIME_ASLEEP = 2.5 unused
-- Vanilla components/trapfumaroleburning.lua:TrapFumaroleBurning:OnUpdate (763928): runs every frame on each burning target, asleep or not
local ASLEEP_PERIOD = 2.5
local AWAKE_PERIOD = 0.5

-- Vanilla components/trapfumaroleburning.lua:TrapFumaroleBurning:OnUpdate (763928): adds a fixed TRAP_FUMAROLE_PROPAGATOR_RATE of heat per call once ignitetime passes TRAP_FUMAROLE_IGNITE_TIME
-- Vanilla components/propagator.lua:Propagator:AddHeat (763928): caps the heat per propagator update and adds none during a delay, to fireimmune targets, or at zero heat resistance
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

	-- Vanilla components/trapfumaroleburning.lua:TrapFumaroleBurning:OnUpdate (763928): removes this component off Coals, and the entity when it cooks a single item
	if inst:IsValid() and inst.components.trapfumaroleburning == self then
		local period = GetAsleepPeriod(self)
		if period ~= self._asleeptask.period then
			CancelAsleepUpdate(self)
			ScheduleAsleepUpdate(self, period)
		end
	end
end

local function StartAsleepUpdate(self)
	-- Vanilla components/health.lua:Health:OnUpdate (763928): ends a burn after FIRE_TIMEOUT (0.5 seconds) without fire damage
	-- Vanilla components/health.lua:Health:DoFireDamage (763928): deals no damage during a burn's first fire_timestart (1 second)
	if self.inst.components.health ~= nil then
		return
	end

	-- Vanilla mainfunctions.lua:OnEntitySleep (763928): runs twice without a wake for a target spawned this tick in a sleeping area, such as Rot
	if self._asleeptask ~= nil then
		return
	end

	self.inst:StopUpdatingComponent(self)
	self._asleepupdatetime = GetTime()
	local period = GetAsleepPeriod(self)
	ScheduleAsleepUpdate(self, period, math.random() * period)
end

local function CatchUp(inst, self, dt)
	if inst.components.trapfumaroleburning == self then
		self:OnUpdate(dt)
	end
end

local function StopAsleepUpdate(self)
	if self._asleeptask == nil then
		return
	end

	CancelAsleepUpdate(self)
	self.inst:StartUpdatingComponent(self)
	-- Vanilla mainfunctions.lua:OnEntityWake (763928): wakes the remaining components after this one, which would start tasks on an entity OnUpdate cooked away
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

	-- Vanilla prefabs/trap_fumarole.lua:OnUpdate (763928): adds this component to targets that may already be asleep
	if inst:IsAsleep() then
		StartAsleepUpdate(self)
	end
end)

-- Vanilla prefabs/trap_fumarole.lua:CheckActiveTrap (763928): starts and cancels the scan task as inst.task
-- Vanilla prefabs/trap_fumarole.lua:IsActiveTrap (763928): only checks that inst.task exists
local function SetScanPeriod(inst, period)
	local task = inst.task
	if task ~= nil and task.period ~= period then
		-- Vanilla scheduler.lua:Periodic:Cancel (763928): clears fn
		local fn = task.fn
		task:Cancel()
		-- Vanilla prefabs/trap_fumarole.lua:StartUpdateTask (763928): randomizes the first delay the same way
		inst.task = inst:DoPeriodicTask(period, fn, math.random() * period)
	end
end

local function OnEntitySleep(inst)
	SetScanPeriod(inst, ASLEEP_PERIOD)
end

local function OnEntityWake(inst)
	SetScanPeriod(inst, AWAKE_PERIOD)
end

AddPrefabPostInit("trap_fumarole", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst:ListenForEvent("entitysleep", OnEntitySleep)
	inst:ListenForEvent("entitywake", OnEntityWake)
end)
