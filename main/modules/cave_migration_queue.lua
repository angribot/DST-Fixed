-- Adapted from No More Cave Bug 1.5 by Cutlass.
-- https://steamcommunity.com/sharedfiles/filedetails/?id=3828908041
local _G = GLOBAL
local NAMESPACE = "DSTFixedCaveMigrationQueue"
local maxwaittime = 30
local GATE_MARGIN = 5

AddClientModRPCHandler(NAMESPACE, "hold", function()
	_G.DeactivateWorld()
	_G.TheFrontEnd:SetFadeLevel(0)
	local WaitingPopup = require("screens/dst_fixed_cavemigrationwaitingpopup")
	local cover = WaitingPopup()
	cover.dialog:Hide()
	_G.TheFrontEnd:PushScreen(cover)
end)

AddClientModRPCHandler(NAMESPACE, "wait", function()
	_G.DeactivateWorld()
	_G.TheFrontEnd:SetFadeLevel(0)
	local WaitingPopup = require("screens/dst_fixed_cavemigrationwaitingpopup")
	_G.TheFrontEnd:PushScreen(WaitingPopup())
end)

local resume
local gatepopup
local gatetask

local function Resume()
	if gatetask ~= nil then
		gatetask:Cancel()
		gatetask = nil
	end
	if resume ~= nil then
		local fn = resume
		resume = nil
		fn()
	end
end

local function StartGateTimer(timeout)
	if gatetask ~= nil then
		gatetask:Cancel()
	end
	gatetask = _G.TheWorld:DoStaticTaskInTime(timeout + GATE_MARGIN, Resume)
end

AddClientModRPCHandler(NAMESPACE, "gatewait", function(timeout)
	if resume == nil then
		return
	end
	if gatepopup == nil then
		_G.TheFrontEnd:SetFadeLevel(0)
		local WaitingPopup = require("screens/dst_fixed_cavemigrationwaitingpopup")
		gatepopup = WaitingPopup()
		_G.TheFrontEnd:PushScreen(gatepopup)
		_G.TheWorld:ListenForEvent("playeractivated", function()
			if gatepopup ~= nil then
				_G.TheFrontEnd:PopScreen(gatepopup)
				gatepopup = nil
			end
		end)
	end
	StartGateTimer(timeout)
end)

AddClientModRPCHandler(NAMESPACE, "go", Resume)

local OnReady

AddModRPCHandler(NAMESPACE, "ready", function(userid)
	OnReady(userid)
end)
_G.MarkUserIDRPC(NAMESPACE, "ready")

-- Delay the engine's loading-complete handshake until the server grants a slot.
if not _G.TheNet:GetIsServer() then
	local Net = _G.getmetatable(_G.TheNet).__index
	local _DoneLoadingMap = Net.DoneLoadingMap
	Net.DoneLoadingMap = function(net)
		resume = function()
			_DoneLoadingMap(net)
		end
		SendModRPCToServer(GetModRPC(NAMESPACE, "ready"))
		StartGateTimer(maxwaittime)
	end
	return
end

local MASTER = _G.SHARDID.MASTER
local StartMigration
local pending = {}
local gated = {}
local authed = {}
-- Only the master shard coordinates this shared FIFO for migrations and loading gates.
local queue = {}
local holder
local holder_shardid
local holder_dest
local timeout_task

local GrantNext

local function Release(userid)
	if holder ~= userid then
		return
	end
	if timeout_task ~= nil then
		timeout_task:Cancel()
		timeout_task = nil
	end
	holder = nil
	holder_shardid = nil
	holder_dest = nil
	GrantNext()
end

local function OnTimeout()
	timeout_task = nil
	holder = nil
	holder_shardid = nil
	holder_dest = nil
	GrantNext()
end

local function Arrived(userid, shardid, spawned)
	if holder ~= userid then
		return
	end
	if holder_dest ~= nil then
		-- A migration completes at destination authentication, not at source departure.
		if spawned or shardid ~= holder_dest then
			return
		end
	elseif shardid == MASTER then
		if not spawned then
			return
		end
	elseif spawned then
		return
	end
	Release(userid)
end

local function NotifyDone(userid)
	if _G.Shard_IsMaster() then
		Release(userid)
	else
		SendModRPCToShard(GetShardModRPC(NAMESPACE, "done"), MASTER, userid)
	end
end

local function NotifyArrived(userid)
	if _G.Shard_IsMaster() then
		Arrived(userid, MASTER, false)
	else
		SendModRPCToShard(GetShardModRPC(NAMESPACE, "arrived"), MASTER, userid)
	end
end

local function Proceed(userid)
	local worldid = pending[userid]
	local gate = gated[userid]
	pending[userid] = nil
	gated[userid] = nil
	if worldid ~= nil and _G.TheNet:GetClientTableForUser(userid) ~= nil then
		StartMigration(_G.TheShard, userid, worldid)
	elseif gate then
		SendModRPCToClient(GetClientModRPC(NAMESPACE, "go"), userid)
	else
		NotifyDone(userid)
	end
end

local function SendWaiting(userid)
	if pending[userid] ~= nil then
		SendModRPCToClient(GetClientModRPC(NAMESPACE, "wait"), userid)
	elseif gated[userid] then
		SendModRPCToClient(GetClientModRPC(NAMESPACE, "gatewait"), userid, maxwaittime)
	end
end

GrantNext = function()
	if holder ~= nil then
		return
	end
	local entry = table.remove(queue, 1)
	if entry == nil then
		return
	end
	holder = entry.userid
	holder_shardid = entry.shardid
	holder_dest = entry.dest
	timeout_task = _G.TheWorld:DoTaskInTime(maxwaittime, OnTimeout)
	local myshard = _G.TheShard:GetShardId()
	if entry.shardid == myshard then
		Proceed(entry.userid)
	else
		SendModRPCToShard(GetShardModRPC(NAMESPACE, "grant"), entry.shardid, entry.userid)
	end
	for i, v in ipairs(queue) do
		if v.dest == nil then
			if v.shardid == myshard then
				SendWaiting(v.userid)
			else
				SendModRPCToShard(GetShardModRPC(NAMESPACE, "progress"), v.shardid, v.userid)
			end
		end
	end
end

local function Enqueue(userid, shardid, dest)
	table.insert(queue, { userid = userid, shardid = tostring(shardid), dest = dest ~= nil and tostring(dest) or nil })
	GrantNext()
	return holder ~= userid
end

local function Request(userid, dest)
	if _G.Shard_IsMaster() then
		if Enqueue(userid, _G.TheShard:GetShardId(), dest) then
			SendWaiting(userid)
		end
	elseif _G.Shard_IsWorldAvailable(MASTER) then
		SendModRPCToShard(GetShardModRPC(NAMESPACE, "request"), MASTER, userid, dest)
	else
		Proceed(userid)
	end
end

AddShardModRPCHandler(NAMESPACE, "request", function(shardid, userid, dest)
	if Enqueue(userid, shardid, dest) then
		SendModRPCToShard(GetShardModRPC(NAMESPACE, "queued"), shardid, userid)
	end
end)

AddShardModRPCHandler(NAMESPACE, "queued", function(shardid, userid)
	SendWaiting(userid)
end)

AddShardModRPCHandler(NAMESPACE, "grant", function(shardid, userid)
	Proceed(userid)
end)

AddShardModRPCHandler(NAMESPACE, "done", function(shardid, userid)
	Release(userid)
end)

AddShardModRPCHandler(NAMESPACE, "arrived", function(shardid, userid)
	Arrived(userid, tostring(shardid), false)
end)

AddShardModRPCHandler(NAMESPACE, "progress", function(shardid, userid)
	SendWaiting(userid)
end)

local function OnShardDisconnected(world_id)
	if _G.Shard_IsMaster() then
		world_id = tostring(world_id)
		for i = #queue, 1, -1 do
			if queue[i].shardid == world_id then
				table.remove(queue, i)
			end
		end
		if holder_shardid == world_id then
			Release(holder)
		end
	elseif world_id == MASTER then
		for userid in pairs(pending) do
			Proceed(userid)
		end
		for userid in pairs(gated) do
			Proceed(userid)
		end
	end
end

local _Shard_UpdateWorldState = _G.Shard_UpdateWorldState
_G.Shard_UpdateWorldState = function(world_id, state, ...)
	_Shard_UpdateWorldState(world_id, state, ...)
	if state ~= _G.REMOTESHARDSTATE.READY then
		OnShardDisconnected(world_id)
	end
end

local function QueueMigration(shard, userid, worldid)
	pending[userid] = worldid
	if not _G.Shard_IsMaster() and _G.Shard_IsWorldAvailable(MASTER) then
		SendModRPCToClient(GetClientModRPC(NAMESPACE, "hold"), userid)
	end
	Request(userid, worldid)
end

OnReady = function(userid)
	if authed[userid] then
		SendModRPCToClient(GetClientModRPC(NAMESPACE, "go"), userid)
	elseif not gated[userid] then
		gated[userid] = true
		Request(userid)
	end
end

AddComponentPostInit("playerspawner", function(self, inst)
	local Shard = _G.getmetatable(_G.TheShard).__index
	StartMigration = Shard.StartMigration
	Shard.StartMigration = QueueMigration

	inst:ListenForEvent("ms_clientauthenticationcomplete", function(world, data)
		authed[data.userid] = true
		NotifyArrived(data.userid)
	end)

	inst:ListenForEvent("ms_clientdisconnected", function(world, data)
		authed[data.userid] = nil
		gated[data.userid] = nil
	end)

	if _G.Shard_IsMaster() then
		inst:ListenForEvent("ms_playerjoined", function(world, player)
			Arrived(player.userid, MASTER, true)
		end)
	end
end)
