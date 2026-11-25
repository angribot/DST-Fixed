local Text = require("widgets/text")
local Image = require("widgets/image")
local Widget = require("widgets/widget")
local UIAnim = require("widgets/uianim")

local SBItemTile = Class(Widget, function(self, itemt)
	Widget._ctor(self, "Tipbox")

	self.bg = self:AddChild(Image())
	self.bg:SetTexture(HUD_ATLAS, "inv_slot_spoiled.tex")
	self.bg:SetClickable(false)
	self.bg:Hide()

	self.spoilage = self:AddChild(UIAnim())
	self.spoilage:GetAnimState():SetBank("spoiled_meter")
	self.spoilage:GetAnimState():SetBuild("spoiled_meter")
	self.spoilage:SetClickable(false)
	self.spoilage:Hide()

	self.wetness = self:AddChild(UIAnim())
	self.wetness:GetAnimState():SetBank("wet_meter")
	self.wetness:GetAnimState():SetBuild("wet_meter")
	self.wetness:GetAnimState():PlayAnimation("idle")
	self.wetness:SetClickable(false)
	self.wetness:Hide()

	self.imagebg = self:AddChild(Image())
	self.imagebg:SetClickable(false)
	self.imagebg:Hide()

	self.image = self:AddChild(Image())
	self.image:Hide()

	self.rechargeframe = self:AddChild(UIAnim())
	self.rechargeframe:GetAnimState():SetBank("recharge_meter")
	self.rechargeframe:GetAnimState():SetBuild("recharge_meter")
	self.rechargeframe:GetAnimState():PlayAnimation("frame")
	self.rechargeframe:SetClickable(false)
	self.rechargeframe:Hide()

	self.recharge = self:AddChild(UIAnim())
	self.recharge:GetAnimState():SetBank("recharge_meter")
	self.recharge:GetAnimState():SetBuild("recharge_meter")
	self.recharge:SetClickable(false)
	self.recharge:Hide()

	self.quantity = self:AddChild(Text(NUMBERFONT, 42))
	self.quantity:SetPosition(2, 16, 0)
	self.quantity:Hide()

	self.percent = self:AddChild(Text(NUMBERFONT, 42))
	if JapaneseOnPS4() then
		self.percent:SetHorizontalSqueeze(0.7)
	end
	self.percent:SetPosition(5, -32 + 15, 0)
	self.percent:Hide()

	self:SetItemData(itemt)
end)

function SBItemTile:SetItemData(data)
	self.data = data

	if self.data.show_spoiled or self.data.spoil then
		self.bg:Show()
	else
		self.bg:Hide()
	end

	if self.data.iswet then
		self.wetness:Show()
	else
		self.wetness:Hide()
	end

	if self.data.nameoverride then
		local inv_image_bg = { image = self.data.nameoverride .. ".tex" }
		inv_image_bg.atlas = GetInventoryItemAtlas(inv_image_bg.image)
		self.imagebg:SetTexture(inv_image_bg.atlas, inv_image_bg.image)
		self.imagebg:Show()
	else
		self.imagebg:Hide()
	end

	self.image:SetTexture(self.data.atlas or GetInventoryItemAtlas(self.data.image), self.data.image)
	self.image:Show()

	if self.data.recharge then
		self:SetChargePercent(self.data.recharge)
		self.rechargeframe:Show()
		self.recharge:Show()
	else
		self.rechargeframe:Hide()
		self.recharge:Hide()
	end

	if self.data.stack then
		self:SetQuantity(self.data.stack)
		self.quantity:Show()
	else
		self.quantity:Hide()
	end

	if self.data.fuel then
		self:SetPercent(self.data.fuel)
		self.percent:Show()
	elseif self.data.uses then
		self:SetPercent(self.data.uses)
		self.percent:Show()
	elseif self.data.armor then
		self:SetPercent(self.data.armor)
		self.percent:Show()
	else
		self.percent:Hide()
	end

	if self.data.perish then
		if self.data.spoil then
			self:SetPerishPercent(self.data.perish)
		else
			self:SetPercent(self.data.perish)
			self.percent:Show()
		end
	end

	if self.data.spoil then
		self.spoilage:Show()
	else
		self.spoilage:Hide()
	end
end

function SBItemTile:SetQuantity(quantity)
	self.quantity:SetString(tostring(quantity))
end

function SBItemTile:SetPerishPercent(percent)
	self.spoilage:GetAnimState():SetPercent("anim", 1 - percent)
end

function SBItemTile:SetPercent(percent)
	local val_to_show = percent * 100
	if val_to_show > 0 and val_to_show < 1 then
		val_to_show = 1
	end
	self.percent:SetString(string.format("%2.0f%%", val_to_show))
end

function SBItemTile:SetChargePercent(percent)
	self.recharge:GetAnimState():SetPercent("recharge", percent)
end

function SBItemTile:SetBaseScale(sc)
	self:SetScale(sc)
end

return SBItemTile
