-- Adapted from No More Cave Bug 1.5 by Cutlass.
-- https://steamcommunity.com/sharedfiles/filedetails/?id=3828908041
local Screen = require("widgets/screen")
local TEMPLATES = require("widgets/redux/templates")

local DSTFixedCaveMigrationWaitingPopup = Class(Screen, function(self)
	Screen._ctor(self, "DSTFixedCaveMigrationWaitingPopup")

	self.black = self:AddChild(TEMPLATES.BackgroundTint())
	self.black:SetTint(0, 0, 0, 1)
	self.proot = self:AddChild(TEMPLATES.ScreenRoot())

	local width = 470
	self.dialog = self.proot:AddChild(TEMPLATES.CurlyWindow(width, 100, STRINGS.UI.FESTIVALEVENTSCREEN.HOST_WAITINGFORWORLD, nil, nil, "."))
	self.dialog.title:SetRegionSize(width + 50, 80)
	self.dialog.title:SetPosition(0, -50)
	self.dialog.title:EnableWordWrap(true)

	self.default_focus = self.dialog

	self.time = 0
	self.progress = 0
end)

function DSTFixedCaveMigrationWaitingPopup:OnUpdate(dt)
	self.time = self.time + dt
	if self.time > 0.75 then
		self.progress = self.progress + 1
		if self.progress > 5 then
			self.progress = 1
		end
		self.dialog.body:SetString(string.rep(".", self.progress))
		self.time = 0
	end
end

function DSTFixedCaveMigrationWaitingPopup:OnControl(control, down)
	DSTFixedCaveMigrationWaitingPopup._base.OnControl(self, control, down)
	return true
end

return DSTFixedCaveMigrationWaitingPopup
