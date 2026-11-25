table.insert(Assets, Asset("ANIM", "anim/ui_showbundle.zip"))
table.insert(Assets, Asset("ANIM", "anim/ui_showbundle_3x2.zip"))

local modname = modname
local modimport = modimport
local AddClassPostConstruct = AddClassPostConstruct
GLOBAL.setfenv(1, GLOBAL)

SB = {}

modimport("main/showbundle_widgetcreation.lua")

SB.supported_items = {
	bundle = {},
	gift = {},
	redpouch = {},
	redpouch_yotp = {},
	redpouch_yotc = {},
	redpouch_yotb = {},
	redpouch_yot_catcoon = {},
	redpouch_yotr = {},
	myth_bundle = {},
	alterguardianhat = {
		prefab = "showbundle_alterguardianhat",
		is_container = true,
	},
	cookpackage = {},
	cookgift = {},
}

local Tipbox = require("widgets/sbtipbox")

local function make_itemdata(items)
	local itemdata = {}
	for _, slot, item in sorted_pairs(items) do
		local is_string = type(item) == "string"
		if is_string then
			item = SpawnPrefab(item)
		end
		if item.components then
			local data = {}
			local c = item.components

			data.prefab = item.prefab

			data.image = (c.inventoryitem and c.inventoryitem.imagename or data.prefab) .. ".tex"
			if c.inventoryitem then
				if c.inventoryitem.atlasname ~= GetInventoryItemAtlas(data.image, true) then
					data.atlas = c.inventoryitem.atlasname
				end
			else
				data.atlas = GetInventoryItemAtlas(data.image, true)
			end

			data.iswet = item:GetIsWet() or nil
			if c.stackable then
				data.stack = c.stackable:StackSize()
			end
			if c.fueled then
				data.fuel = c.fueled:GetPercent()
			end
			if c.finiteuses then
				data.uses = c.finiteuses:GetPercent()
			end
			if c.armor then
				data.armor = c.armor:GetPercent()
			end
			if c.perishable then
				data.perish = c.perishable:GetPercent()
			end
			if c.rechargeable then
				local percent = c.rechargeable:GetPercent()
				data.recharge = percent ~= 1 and percent or nil
			end

			if item:HasTag("show_spoiled") then
				data.show_spoiled = true
			end
			if item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled") then
				if item:HasTag("show_spoilage") then
					data.spoil = true
				else
					for _, t in pairs(FOODTYPE) do
						if item:HasTag("edible_" .. t) then
							data.spoil = true
							break
						end
					end
				end
			end

			if c.edible and c.edible.spice and item.nameoverride then
				data.nameoverride = item.nameoverride
			end
			itemdata[slot] = data
		else
			print("SHOW BUNDLE WARNING: this wrap contains an item without components", slot, item)
		end
		if is_string then
			item:Remove()
		end
	end
	return itemdata
end

local function handle_redpouch_data(target, data)
	if not (target and string.find(target.prefab, "redpouch")) then
		return
	end
	local nugget_count = 0
	for _, v in pairs(data) do
		if v.prefab == "lucky_goldnugget" then
			nugget_count = nugget_count + (v.stack or 1)
		else
			return
		end
	end
	return nugget_count ~= 0
		and {
			{
				prefab = "lucky_goldnugget",
				image = "lucky_goldnugget.tex",
				stack = nugget_count,
			},
		}
end

local function make_itemdata_for_unwrappable(unwrappable)
	if unwrappable and unwrappable.itemdata then
		local items = {}
		local creator = unwrappable.origin
				and TheWorld.meta.session_identifier ~= unwrappable.origin
				and { sessionid = unwrappable.origin }
			or nil
		for i, v in ipairs(unwrappable.itemdata) do
			local item = SpawnPrefab(v.prefab, v.skinname, v.skin_id, creator)
			if item and item:IsValid() then
				item:SetPersistData(v.data)
				table.insert(items, item)
			end
		end
		unwrappable.itemdata.showbundle_itemdata = make_itemdata(items)
		for _, v in ipairs(items) do
			v:Remove()
		end
	end
end

local function refresh_all_bundle_data()
	for _, ent in pairs(Ents) do
		local unwrappable = ent.components.unwrappable
		make_itemdata_for_unwrappable(unwrappable)
	end
end

local Unwrappable = require("components/unwrappable")

local wrap_items = Unwrappable.WrapItems
function Unwrappable:WrapItems(items, doer, ...)
	wrap_items(self, items, doer, ...)
	if #items > 0 and self.itemdata then
		self.itemdata.showbundle_itemdata = make_itemdata(items)
	end
end

local function HasEmptyEntry(showbundle_itemdata)
	for _, data in ipairs(showbundle_itemdata) do
		if IsTableEmpty(data) then
			return true
		end
	end
	return false
end

local onload = Unwrappable.OnLoad or function() end
function Unwrappable:OnLoad(data, ...)
	local ret = onload(self, data, ...)
	if self.itemdata then
		local showbundle_itemdata = self.itemdata.showbundle_itemdata
		if not showbundle_itemdata or HasEmptyEntry(showbundle_itemdata) then
			make_itemdata_for_unwrappable(self)
		end
	end
	return ret
end

local function draw_tipbox(data, target)
	if SB.tipbox then
		local widget_settings = FunctionOrValue(SB.supported_items[target.prefab], target) or {}
		SB.tipbox:WidgetSetup(widget_settings)
		SB.tipbox:SetData(data)
		if target.replica.container and (not data or (IsTableEmpty(data) and not widget_settings.show_on_empty)) then
			SB.tipbox:Hide()
		elseif not SB.tipbox.shown then
			SB.tipbox:Show()
		end
	end
end

local function should_show_tip(target)
	local data = target and FunctionOrValue(SB.supported_items[target.prefab], target)
	return data
		and (not data.is_container or target.replica.container and not target.replica.container:IsOpenedBy(ThePlayer))
end

local last_target

local function send_showbundle_request(target)
	SendModRPCToServer(MOD_RPC[modname]["ShowBundle"], target)
	target.showbundle_last_update_request_time = GetTime()
end

local function should_invalidate_last_data(target)
	return target.showbundle_last_update_request_time and GetTime() - target.showbundle_last_update_request_time >= 1
end

local function show_tip(target)
	if target ~= last_target then
		if last_target and last_target.replica.container then
			last_target.showbundle_itemdata = nil
		elseif target and target.replica.container and should_invalidate_last_data(target) then
			target.showbundle_itemdata = nil
		end
	end
	last_target = target

	if should_show_tip(target) then
		if target.showbundle_itemdata then
			draw_tipbox(target.showbundle_itemdata, target)
			if target.replica.container and GetTime() - target.showbundle_last_update_request_time >= 1 then
				send_showbundle_request(target)
			end
		else
			send_showbundle_request(target)
			SB.tipbox:Hide()
		end
	else
		SB.tipbox:Hide()
	end
end

AddClassPostConstruct("widgets/controls", function(self)
	if self.owner and self.owner == ThePlayer then
		SB.tipbox = Tipbox()
		self.showbundle_tipbox = self:AddChild(SB.tipbox)
	end

	local set_hud_size = self.SetHUDSize
	self.SetHUDSize = function(self, ...)
		if self.showbundle_tipbox then
			self.showbundle_tipbox:ChangeScale(TheFrontEnd:GetHUDScale())
		end
		return set_hud_size(self, ...)
	end
end)

local ItemTile = require("widgets/itemtile")

local function text_on_show()
	if not ThePlayer then
		return
	end

	local hoverinst = TheInput.hoverinst
	if hoverinst and hoverinst.entity:IsValid() and hoverinst.entity:IsVisible() then
		if hoverinst.Transform then
			show_tip(hoverinst)
			return
		end
		local parent = hoverinst.widget and hoverinst.widget.parent
		if parent and parent.is_a and parent:is_a(ItemTile) then
			local item = parent.item
			if item and item.is_a and item:is_a(EntityScript) and item:IsValid() and item.Transform then
				show_tip(item)
				return
			end
		end
	end
	show_tip(nil)
end

AddClassPostConstruct("widgets/hoverer", function(self)
	local onshow = self.text.OnShow
	self.text.OnShow = function(...)
		text_on_show()
		return onshow(...)
	end

	local onhide = self.text.OnHide
	self.text.OnHide = function(...)
		show_tip(nil)
		return onhide(...)
	end
end)

local function serialize(data_table)
	local serialized = DataDumper(data_table, nil, true)
	return string.sub(serialized, #"return {" + 1, -2)
end

local function unserialize(data_str)
	local succeed, result = RunInSandboxSafe("return {" .. data_str .. "}")
	if succeed then
		return result
	else
		print("Failed to unserialize", data_str)
	end
end

AddClientModRPCHandler(modname, "ShowBundleCallback", function(target, data)
	target.showbundle_itemdata = unserialize(data) or {}
	if target == last_target then
		draw_tipbox(target.showbundle_itemdata, target)
	end
end)

AddModRPCHandler(modname, "ShowBundle", function(player, target)
	if not checkentity(target) then
		print(string.format("Invalid %s RPC from (%s) %s", "ShowBundle", player.userid or "", player.name or ""))
		return
	end
	local itemdata = {}
	local showbundle_itemdata = target.components.unwrappable
		and target.components.unwrappable.itemdata
		and target.components.unwrappable.itemdata.showbundle_itemdata
	if showbundle_itemdata then
		itemdata = showbundle_itemdata
	elseif target.components.container then
		itemdata = make_itemdata(target.components.container.slots)
	end
	itemdata = handle_redpouch_data(target, itemdata) or itemdata
	SendModRPCToClient(CLIENT_MOD_RPC[modname]["ShowBundleCallback"], player.userid, target, serialize(itemdata))
end)

local ShowMe_Hint = MOD_RPC.ShowMeSHint and MOD_RPC.ShowMeSHint.Hint
if ShowMe_Hint then
	local send_mod_rpc_to_server = SendModRPCToServer
	function SendModRPCToServer(code, GUID, ...)
		local ent = Ents[GUID]
		if code == ShowMe_Hint and ent and (ent.prefab == "bundle" or ent.prefab == "gift") then
			return
		end
		return send_mod_rpc_to_server(code, GUID, ...)
	end
end

SB.make_itemdata = make_itemdata
SB.MakeItemData = make_itemdata

SB.make_itemdata_for_unwrappable = make_itemdata_for_unwrappable
SB.MakeItemDataForUnwrappable = make_itemdata_for_unwrappable

SB.refresh_all_bundle_data = refresh_all_bundle_data
SB.RefreshAllBundleData = refresh_all_bundle_data

SB.send_showbundle_request = send_showbundle_request
SB.SendShowBundleRequest = send_showbundle_request
