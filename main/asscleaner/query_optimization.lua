local AddComponentPostInit = AddComponentPostInit
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 762172: some vanilla code repeats the same work every
-- frame or for every item, which adds up in large, long-running worlds. Each
-- patch below skips repeated work and leaves its results unchanged.
-- After a game update, recheck the functions named in each section, and remove
-- a patch once vanilla stops repeating that work.
local UpvalueUtil = require("upvalueutil")

--------------------------------------------------------------------------
-- W.O.B.O.T. and W.I.N.bot container search

-- FindItemToPickupAndStore in scripts/prefabs/storage_robot_common.lua runs
-- FindContainerWithItem for each item on the ground, and each run queries the
-- nearby containers again and scans every slot. An idle W.I.N.bot repeats the
-- whole search every 3 seconds (TryReactivate in winona_storage_robot.lua). This
-- patch keeps the container lookups for the duration of one
-- FindItemToPickupAndStore call: one container query, the item-independent
-- checks once per container, and Has once per container and prefab. It returns
-- the same container as vanilla: all checks are read-only queries, so their
-- results cannot change within the call, and containers are still tried in
-- FindEntities order.

local function PatchStorageRobotSearch()
	local StorageRobotCommon = require("prefabs/storage_robot_common")
	local FindItemToPickupAndStore = StorageRobotCommon.FindItemToPickupAndStore
	local FindContainerWithItem = StorageRobotCommon.FindContainerWithItem
	-- Klei marks these fields as not guaranteed to stay.
	local CONTAINER_MUST_TAGS = StorageRobotCommon.CONTAINER_MUST_TAGS
	local CONTAINER_CANT_TAGS = StorageRobotCommon.CONTAINER_CANT_TAGS
	local ALLOWED_CONTAINER_TYPES = StorageRobotCommon.ALLOWED_CONTAINER_TYPES
	if CONTAINER_MUST_TAGS == nil or CONTAINER_CANT_TAGS == nil or ALLOWED_CONTAINER_TYPES == nil then
		return
	end

	-- Lookups for the FindItemToPickupAndStore call in progress.
	local search = nil

	-- The FindContainerWithItem checks that do not depend on the item.
	local function IsStorageContainer(ent, platform)
		local container = ent.components.container
		return container ~= nil
			and ent.components.dryingrack == nil
			and table.contains(ALLOWED_CONTAINER_TYPES, container.type)
			and (container.canbeopened or container.canacceptgivenitems)
			and ent:IsOnPassablePoint()
			and ent:GetCurrentPlatform() == platform
	end

	-- Containers passing the item-independent checks, in FindEntities order.
	local function GetStorageContainers(inst)
		if search.containers == nil then
			local x, y, z = StorageRobotCommon.GetSpawnPoint(inst):Get()
			local platform = inst:GetCurrentPlatform()
			local containers = {}
			local ents = TheSim:FindEntities(x, y, z, TUNING.STORAGE_ROBOT_WORK_RADIUS, CONTAINER_MUST_TAGS, CONTAINER_CANT_TAGS)
			for _, ent in ipairs(ents) do
				if IsStorageContainer(ent, platform) then
					table.insert(containers, ent)
				end
			end
			search.containers = containers
		end
		return search.containers
	end

	local function GetContainersWithPrefab(inst, prefab)
		local containers = search.byprefab[prefab]
		if containers == nil then
			containers = {}
			for _, ent in ipairs(GetStorageContainers(inst)) do
				if ent.components.container:Has(prefab, 1) then
					table.insert(containers, ent)
				end
			end
			search.byprefab[prefab] = containers
		end
		return containers
	end

	StorageRobotCommon.FindContainerWithItem = function(inst, item, count, ...)
		if search == nil then
			return FindContainerWithItem(inst, item, count, ...)
		end

		count = count or 0
		local stack_maxsize = item.components.stackable ~= nil and item.components.stackable.maxsize or 1
		for _, ent in ipairs(GetContainersWithPrefab(inst, item.prefab)) do
			if ent.components.container:CanAcceptCount(item, stack_maxsize) > count then
				return ent
			end
		end
	end

	StorageRobotCommon.FindItemToPickupAndStore = function(inst, ...)
		search = { byprefab = {} }
		local item, container = FindItemToPickupAndStore(inst, ...)
		search = nil
		return item, container
	end
end

--------------------------------------------------------------------------
-- Thermal Stone local temperature

-- Temperature:OnUpdate calls GetTemperatureAtXZ every frame, which measures the
-- distance to every enabled temperatureoverrider (Ice Crystaleyezers, the
-- Shrouded Queen's arena). Each update then pushes "temperaturedelta", and the
-- Thermal Stone's handler (TemperatureChange in scripts/prefabs/heatrock.lua)
-- calls GetLocalTemperature at the same position, measuring every distance
-- again. Thermal Stones keep updating while asleep and inside containers.
-- This patch:
-- - inlines EntityScript:GetDistanceSqToPoint and math2d.DistSq in the loop,
--   with the same arithmetic, comparisons and iteration order;
-- - during one Temperature:OnUpdate, reuses the result of the last lookup for a
--   repeated lookup at the same point. Overriders change only on player actions
--   and spawns, never inside an update, so the reused result is the one vanilla
--   would compute.

local function PatchTemperatureLookup()
	local overriders = UpvalueUtil.GetUpvalue(GetTemperatureAtXZ, "_overriders")

	-- Same as vanilla GetTemperatureAtXZ in scripts/components/temperatureoverrider.lua.
	local function LookupTemperatureAtXZ(x, z)
		local mindsq = math.huge
		local closest_ent = nil
		for ent in pairs(overriders) do
			local ex, _, ez = ent.Transform:GetWorldPosition()
			local dx, dz = ex - x, ez - z
			local dsq = dx * dx + dz * dz
			if dsq < mindsq then
				local r = ent.components.temperatureoverrider:GetActiveRadius()
				if dsq <= r * r then
					mindsq = dsq
					closest_ent = ent
				end
			end
		end

		return (closest_ent and closest_ent.components.temperatureoverrider:GetTemperature())
			or (TheWorld.net.components.fumarolelocaltemperature and TheWorld.net.components.fumarolelocaltemperature:GetTemperatureAtXZ(x, z))
			or TheWorld.state.temperature
	end

	local in_temperature_update = false
	local last_x, last_z, last_temperature

	local function ForgetLastLookup()
		last_x, last_z, last_temperature = nil, nil, nil
	end

	function GetTemperatureAtXZ(x, z)
		if in_temperature_update and x == last_x and z == last_z then
			return last_temperature
		end
		local temperature = LookupTemperatureAtXZ(x, z)
		if in_temperature_update then
			last_x, last_z, last_temperature = x, z, temperature
		end
		return temperature
	end

	local Temperature = require("components/temperature")
	local OnUpdate = Temperature.OnUpdate
	function Temperature:OnUpdate(...)
		in_temperature_update = true
		OnUpdate(self, ...)
		-- When updates nest, this also ends reuse for the rest of the outer
		-- update, which only costs repeated lookups.
		in_temperature_update = false
		ForgetLastLookup()
	end
end

--------------------------------------------------------------------------
-- Global map icons of structures

-- TrackEntity in scripts/prefabs/globalmapicon.lua makes the icon copy its
-- target's position every frame, and the icon never sleeps. These structures
-- move only as platform followers of a boat (EntityScript:AddPlatformFollower),
-- so while one is asleep and not on a boat, its icon stops updating, and resumes
-- when the structure wakes. Vanilla skips the updates entirely for an icon that
-- can never move (oceanwhirlbigportal.lua passes noupdate).
-- The check waits a tick: a structure loaded on a boat becomes its platform
-- follower only in that tick's WalkablePlatformManager:PostUpdate, which runs
-- after the icon is created and possibly after the structure falls asleep.
local STATIC_ICON_TARGETS = {
	deerclopseyeball_sentryward = true,
	moondial = true,
	sentryward = true,
	townportal = true,
}

AddPrefabPostInit("globalmapicon", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	local TrackEntity = inst.TrackEntity
	inst.TrackEntity = function(inst, target, ...)
		TrackEntity(inst, target, ...)

		local updatelooper = inst.components.updatelooper
		if updatelooper == nil or not STATIC_ICON_TARGETS[target.prefab] then
			return
		end

		local function PauseIfIdle()
			if target:IsAsleep() and target.platform == nil then
				inst:StopUpdatingComponent(updatelooper)
			end
		end

		local function OnTargetSleep()
			inst:DoTaskInTime(0, PauseIfIdle)
		end

		inst:ListenForEvent("entitysleep", OnTargetSleep, target)
		inst:ListenForEvent("entitywake", function()
			inst:StartUpdatingComponent(updatelooper)
		end, target)

		-- Icons are created after their target, which may already be asleep.
		OnTargetSleep()
	end
end)

--------------------------------------------------------------------------
-- Boat health trend

-- HealthSyncer:OnUpdate in scripts/components/healthsyncer.lua recomputes the
-- health trend arrow every frame, and the component never stops updating.
-- Only teammate health badges read the arrow (teammatehealthbadge.lua); the boat
-- health meter reads only the health percent, which health events keep in sync.
-- Boats stop updating the arrow while asleep, and resume when they wake.

local function HealthSyncerOnEntitySleep(self)
	if self.inst.components.walkableplatform ~= nil then
		self.inst:StopUpdatingComponent(self)
		self._sleeppaused = true
	end
end

local function HealthSyncerOnEntityWake(self)
	if self._sleeppaused then
		self._sleeppaused = nil
		self.inst:StartUpdatingComponent(self)
	end
end

AddComponentPostInit("healthsyncer", function(self, inst)
	if not TheWorld.ismastersim then
		return
	end

	self.OnEntitySleep = HealthSyncerOnEntitySleep
	self.OnEntityWake = HealthSyncerOnEntityWake
end)

--------------------------------------------------------------------------

PatchStorageRobotSearch()
PatchTemperatureLookup()
