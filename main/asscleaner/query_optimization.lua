local AddComponentPostInit = AddComponentPostInit
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local UpvalueUtil = require("upvalueutil")

-- Vanilla prefabs/storage_robot_common.lua:FindItemToPickupAndStore (763928): runs FindContainerWithItem for each item on the ground
-- Vanilla prefabs/storage_robot_common.lua:FindContainerWithItem (763928): queries the nearby containers and scans every slot on each call
-- Vanilla prefabs/winona_storage_robot.lua:TryReactivate (763928): repeats the whole search every 3 seconds while idle
local function PatchStorageRobotSearch()
	local StorageRobotCommon = require("prefabs/storage_robot_common")
	local FindItemToPickupAndStore = StorageRobotCommon.FindItemToPickupAndStore
	local FindContainerWithItem = StorageRobotCommon.FindContainerWithItem
	-- Vanilla prefabs/storage_robot_common.lua:FindContainerWithItem (763928): reads these from exports Klei marks as not guaranteed to stay
	local CONTAINER_MUST_TAGS = StorageRobotCommon.CONTAINER_MUST_TAGS
	local CONTAINER_CANT_TAGS = StorageRobotCommon.CONTAINER_CANT_TAGS
	local ALLOWED_CONTAINER_TYPES = StorageRobotCommon.ALLOWED_CONTAINER_TYPES
	if CONTAINER_MUST_TAGS == nil or CONTAINER_CANT_TAGS == nil or ALLOWED_CONTAINER_TYPES == nil then
		return
	end

	local call_lookups = nil

	local function IsStorageContainer(ent, platform)
		local container = ent.components.container
		return container ~= nil
			and ent.components.dryingrack == nil
			and table.contains(ALLOWED_CONTAINER_TYPES, container.type)
			and (container.canbeopened or container.canacceptgivenitems)
			and ent:IsOnPassablePoint()
			and ent:GetCurrentPlatform() == platform
	end

	local function GetStorageContainers(inst)
		if call_lookups.containers == nil then
			local x, y, z = StorageRobotCommon.GetSpawnPoint(inst):Get()
			local platform = inst:GetCurrentPlatform()
			local containers = {}
			local ents = TheSim:FindEntities(x, y, z, TUNING.STORAGE_ROBOT_WORK_RADIUS, CONTAINER_MUST_TAGS, CONTAINER_CANT_TAGS)
			for _, ent in ipairs(ents) do
				if IsStorageContainer(ent, platform) then
					table.insert(containers, ent)
				end
			end
			call_lookups.containers = containers
		end
		return call_lookups.containers
	end

	local function GetContainersWithPrefab(inst, prefab)
		local containers = call_lookups.byprefab[prefab]
		if containers == nil then
			containers = {}
			for _, ent in ipairs(GetStorageContainers(inst)) do
				if ent.components.container:Has(prefab, 1) then
					table.insert(containers, ent)
				end
			end
			call_lookups.byprefab[prefab] = containers
		end
		return containers
	end

	StorageRobotCommon.FindContainerWithItem = function(inst, item, count, ...)
		if call_lookups == nil then
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
		call_lookups = { byprefab = {} }
		local item, container = FindItemToPickupAndStore(inst, ...)
		call_lookups = nil
		return item, container
	end
end

-- Vanilla components/temperature.lua:Temperature:OnUpdate (763928): calls GetTemperatureAtXZ every frame, even for sleeping or stored Thermal Stones
-- Vanilla prefabs/heatrock.lua:TemperatureChange (763928): looks up the temperature at the same point again on each temperaturedelta
local function PatchTemperatureLookup()
	local overriders = UpvalueUtil.GetUpvalue(GetTemperatureAtXZ, "_overriders")

	-- Vanilla components/temperatureoverrider.lua:GetTemperatureAtXZ (763928): copy with GetDistanceSqToPoint and math2d.DistSq inlined
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
		in_temperature_update = false
		ForgetLastLookup()
	end
end

-- Vanilla prefabs/globalmapicon.lua:TrackEntity (763928): copies the target's position every frame unless passed noupdate, and the icon never sleeps
-- Vanilla components/walkableplatformmanager.lua:WalkablePlatformManager:PostUpdate (763928): attaches a structure loaded on a boat only after its icon exists
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

		OnTargetSleep()
	end
end)

-- Vanilla components/healthsyncer.lua:HealthSyncer:OnUpdate (763928): recomputes the trend arrow every frame, which only teammate health badges read
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

PatchStorageRobotSearch()
PatchTemperatureLookup()
