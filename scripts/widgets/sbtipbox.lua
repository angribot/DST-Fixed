local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")
local SBItemTile = require("widgets/sbitemtile")
local ItemSlot = require("widgets/itemslot")
local UIAnim = require("widgets/uianim")
local containers = require("containers")

local Tipbox = Class(Widget, function(self, data, widget_override)
	Widget._ctor(self, "Tipbox")

	self:Hide()

	self:SetScaleMode(SCALEMODE_PROPORTIONAL)

	self.scale = TheFrontEnd:GetHUDScale()
	self.root_scale = 0.95
	self.offset = Vector3(0, 95)

	self.bg_scale = 0.46
	self.slot_scale = 0.55

	self.root = self:AddChild(Widget("showbundle_tipbox"))

	self.bg = self.root:AddChild(UIAnim())
	self.bg:SetClickable(false)

	self.itemslots = {}
	self.items = {}

	self.default_widget_data = {
		slotpos = {
			Vector3(-37.5, 32 + 4),
			Vector3(37.5, 32 + 4),
			Vector3(-37.5, -(32 + 4)),
			Vector3(37.5, -(32 + 4)),
		},
		animbank = "ui_bundle_2x2",
		animbuild = "ui_showbundle",
		scale = 0.95,
		slot_scale = 0.55,
		bg_scale = 0.46,
		pos = Vector3(0, 92),
	}

	self:WidgetSetup(widget_override, true)
	self:UpdateScales()
	self:SetData(data, true)
end)

function Tipbox:WidgetSetup(override_data, force)
	override_data = override_data or {}

	local prefab = override_data.prefab
	if not force and prefab == self.widget_prefabname then
		return
	end
	self.widget_prefabname = prefab

	local widget = prefab and containers.params[prefab] and containers.params[prefab].widget or self.default_widget_data

	if override_data.animbuild then
		self.bg:GetAnimState():SetBank(override_data.animbank)
	elseif widget.animbank then
		self.bg:GetAnimState():SetBank(widget.animbank)
	end

	if override_data.animbuild then
		self.bg:GetAnimState():SetBuild(override_data.animbuild)
	elseif widget.animbuild then
		self.bg:GetAnimState():SetBuild(widget.animbuild)
	end

	local widget_data_map = {
		pos = { map = "offset", default = Vector3(0, 95) },
		scale = { map = "root_scale", default = 0.52 },
		slot_scale = { map = "slot_scale", default = 1 },
		bg_scale = { map = "bg_scale", default = 1 },
	}
	for k, v in pairs(widget_data_map) do
		if override_data[k] then
			self[v.map] = override_data[k]
		elseif widget[k] then
			self[v.map] = widget[k]
		else
			self[v.map] = v.default
		end
	end

	for _, slot in ipairs(self.itemslots) do
		slot:Kill()
	end
	self.itemslots = {}

	for i, v in ipairs(override_data.slotpos or widget.slotpos or {}) do
		local slotbg = override_data.slotbg and override_data.slotbg[i] or widget.slotbg and widget.slotbg[i] or {}
		local slot = ItemSlot(slotbg.atlas or "images/hud.xml", slotbg.image or "inv_slot.tex")
		self.itemslots[i] = self.root:AddChild(slot)

		slot:SetClickable(false)
		slot.OnGainFocus = function() end
		slot.OnLoseFocus = function() end

		slot:SetPosition(v * self.slot_scale)
		slot:SetScale(self.slot_scale)
	end

	self:UpdateScales()
end

function Tipbox:SetData(data, force)
	if not force and data == self.items then
		return
	end
	self.items = data or {}
	for i, slot in ipairs(self.itemslots) do
		local item_data = self.items[i]
		if item_data then
			if slot.tile then
				slot.tile:SetItemData(item_data)
			else
				slot:SetTile(SBItemTile(item_data))
			end
		else
			slot:SetTile(nil)
		end
	end
end

function Tipbox:UpdatePosition(x, y)
	local pos = Vector3(x, y)
	local offset = Vector3(self.offset.x, self.offset.y)
	local screen_width, screen_height = TheSim:GetScreenSize()
	local mouse_pos = TheInput:GetScreenPosition()
	if screen_height and mouse_pos.y > 0.8 * screen_height then
		offset.y = -self.offset.y
	end
	self:SetPosition(pos)
	self.root:SetPosition(offset)
end

function Tipbox:UpdateScales()
	for _, slot in ipairs(self.itemslots) do
		slot:SetScale(self.slot_scale)
	end
	self.bg:SetScale(self.bg_scale)
	self.root:SetScale(self.root_scale)
	self:SetScale(self.scale)
end

function Tipbox:ChangeScale(scale)
	self.scale = scale
	self:SetScale(self.scale)
end

function Tipbox:OnShow()
	self.bg:GetAnimState():PlayAnimation("open")
	if self.followhandler == nil then
		self.followhandler = TheInput:AddMoveHandler(function(x, y)
			self:UpdatePosition(x, y)
		end)
		local pos = TheInput:GetScreenPosition()
		self:UpdatePosition(pos.x, pos.y)
	end
end

function Tipbox:OnHide()
	self:StopFollowMouse()
end

return Tipbox
