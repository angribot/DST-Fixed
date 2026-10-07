local modname = modname
local AddSimPostInit = AddSimPostInit
local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Both RPC directions reserve two of the engine's 50 arguments for metadata.
local CONTAINERS_PER_RPC = 48

local highlighted = {}
local active_item
local generation = 0

local function IsCandidate(inst)
	return inst:IsValid() and not inst:IsAsleep() and not inst:HasTag("INLIMBO")
		and inst.AnimState ~= nil and (inst.replica.container ~= nil or inst.components.container_proxy ~= nil)
end

local function ApplyHighlightColour(inst)
	local green = highlighted[inst] and .5 or 0
	inst.AnimState:SetHighlightColour(0, green, 0, 0)
	for _, child in ipairs(inst.highlightchildren or {}) do
		child.AnimState:SetHighlightColour(0, green, 0, 0)
	end
end

-- Keep search colour separate from base tint and preserve vanilla hover/flash effects.
AddComponentPostInit("highlight", function(self)
	local ApplyColour = self.ApplyColour
	self.ApplyColour = function(self)
		local green = self.base_add_colour_green
		if highlighted[self.inst] then
			self.base_add_colour_green = (green or 0) + .5
		end
		ApplyColour(self)
		self.base_add_colour_green = green
	end
	local OnRemoveFromEntity = self.OnRemoveFromEntity
	self.OnRemoveFromEntity = function(self)
		OnRemoveFromEntity(self)
		if highlighted[self.inst] and self.inst:IsValid() then
			ApplyHighlightColour(self.inst)
		end
	end
end)

local function RefreshHighlight(inst)
	if inst.components.highlight ~= nil then
		inst.components.highlight:ApplyColour()
	else
		ApplyHighlightColour(inst)
	end
end

local function ClearHighlight(inst)
	if highlighted[inst] then
		highlighted[inst] = nil
		if inst:IsValid() then
			RefreshHighlight(inst)
		end
	end
end

local function ClearHighlights()
	for inst in pairs(highlighted) do
		ClearHighlight(inst)
	end
end

-- Entity RPC arguments let the engine resolve network IDs. Return only match flags.
AddModRPCHandler(modname, "HighlightContainers", function(player, request, prefab, ...)
	local count = select("#", ...)
	if type(request) ~= "number" or type(prefab) ~= "string" or count > CONTAINERS_PER_RPC then
		return
	end
	local inventory = player.components.inventory
	local item = inventory ~= nil and inventory:GetActiveItem() or nil
	local matches = {}
	for i = 1, count do
		local inst = select(i, ...)
		local container
		if item ~= nil and item.prefab == prefab and EntityScript.is_instance(inst) and inst:IsValid() and not inst:HasTag("INLIMBO") then
			local proxy = inst.components.container_proxy
			local master = proxy ~= nil and proxy:GetMaster() or inst
			container = master ~= nil and master.components.container or nil
		end
		matches[i] = container ~= nil and container:Has(prefab, 1) and "1" or "0"
	end
	SendModRPCToClient(CLIENT_MOD_RPC[modname].HighlightContainers, player.userid, request, table.concat(matches), ...)
end)

AddClientModRPCHandler(modname, "HighlightContainers", function(request, matches, ...)
	if request ~= generation or ThePlayer == nil or ThePlayer.replica.inventory == nil
		or ThePlayer.replica.inventory:GetActiveItem() ~= active_item or active_item == nil then
		return
	end
	for i = 1, select("#", ...) do
		local inst = select(i, ...)
		if inst ~= nil and IsCandidate(inst) and matches:sub(i, i) == "1" then
			highlighted[inst] = true
			RefreshHighlight(inst)
		elseif inst ~= nil then
			ClearHighlight(inst)
		end
	end
end)

AddSimPostInit(function()
	if TheNet:IsDedicated() then
		return
	end
	local player
	local OnActiveItemChanged
	local function Update()
		local current = ThePlayer
		local inventory = current ~= nil and current.replica.inventory or nil
		local item = inventory ~= nil and inventory:GetActiveItem() or nil
		if current ~= player then
			if player ~= nil and player:IsValid() then
				player:RemoveEventCallback("newactiveitem", OnActiveItemChanged)
			end
			generation = generation + 1
			player = current
			if player ~= nil then
				player:ListenForEvent("newactiveitem", OnActiveItemChanged)
			end
			ClearHighlights()
		end
		if item ~= active_item then
			generation = generation + 1
			ClearHighlights()
			active_item = item
		end
		if item == nil then
			ClearHighlights()
			return
		end
		local containers = {}
		for _, inst in pairs(Ents) do
			if IsCandidate(inst) then
				containers[#containers + 1] = inst
			end
		end
		for inst in pairs(highlighted) do
			if not IsCandidate(inst) then
				ClearHighlight(inst)
			end
		end
		for i = 1, #containers, CONTAINERS_PER_RPC do
			SendModRPCToServer(MOD_RPC[modname].HighlightContainers, generation, item.prefab, unpack(containers, i, math.min(i + CONTAINERS_PER_RPC - 1, #containers)))
		end
	end
	OnActiveItemChanged = function(inst)
		generation = generation + 1
		ClearHighlights()
		-- Inventory prediction raises this event before sending the pickup RPC.
		inst:DoTaskInTime(0, Update)
	end
	TheWorld:DoPeriodicTask(.5, Update, 0)
end)
