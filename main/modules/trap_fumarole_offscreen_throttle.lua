local AddComponentPostInit = AddComponentPostInit
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla keeps Coals running at full rate away from players: each placed Coals
-- scans for targets every 0.5 seconds, and trapfumaroleburning updates every
-- frame on everything it burns. A Coals farm covered in loot spends most of the
-- server frame on items nobody is near. trap_fumarole.lua declares
-- UPDATE_TIME_ASLEEP = 2.5 for this but never uses it; this module applies it to
-- both the scans and the burning items while they sleep.
local ASLEEP_PERIOD = 2.5
-- StartUpdateTask in trap_fumarole.lua
local AWAKE_PERIOD = 0.5

--------------------------------------------------------------------------
-- Burning items

local function AsleepUpdate(inst, self)
	local time = GetTime()
	local dt = time - self._asleepupdatetime
	self._asleepupdatetime = time
	self:OnUpdate(dt)
end

local function StartAsleepUpdate(self)
	-- Health:OnUpdate ends a burn after 0.5 seconds without fire damage
	-- (FIRE_TIMEOUT), and Health:DoFireDamage deals none during a burn's first
	-- second (fire_timestart), so creatures updated less often than that never
	-- take damage. Leave them on per-frame updates.
	if self._asleeptask ~= nil or self.inst.components.health ~= nil then
		return
	end

	self.inst:StopUpdatingComponent(self)
	self._asleepupdatetime = GetTime()
	-- A random first delay spreads items that fall asleep together across frames.
	self._asleeptask = self.inst:DoPeriodicTask(ASLEEP_PERIOD, AsleepUpdate, math.random() * ASLEEP_PERIOD, self)
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

	self._asleeptask:Cancel()
	self._asleeptask = nil
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
			self._asleeptask:Cancel()
			self._asleeptask = nil
		end
		return OnRemoveFromEntity(self, ...)
	end

	-- Coals scanning while asleep add this component to items already asleep,
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
local function RestartScanTask(inst, period)
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
	RestartScanTask(inst, ASLEEP_PERIOD)
end

local function OnEntityWake(inst)
	-- Restart instead of waiting out the slow period, so targets arriving as the
	-- Coals wake are found within 0.5 seconds as in vanilla.
	RestartScanTask(inst, AWAKE_PERIOD)
end

AddPrefabPostInit("trap_fumarole", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst:ListenForEvent("entitysleep", OnEntitySleep)
	inst:ListenForEvent("entitywake", OnEntityWake)
end)
