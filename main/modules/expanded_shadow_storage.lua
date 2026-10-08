table.insert(Assets, Asset("ANIM", "anim/ui_fish_box_5x4.zip"))

GLOBAL.setfenv(1, GLOBAL)

local widget = {
	slotpos = {},
	animbank = "ui_fish_box_5x4",
	animbuild = "ui_fish_box_5x4",
	pos = Vector3(0, 220, 0),
	side_align_tip = 160,
}

for y = 1.5, -1.5, -1 do
	for x = -2, 2 do
		table.insert(widget.slotpos, Vector3(75 * x, 75 * y, 0))
	end
end

require("containers").params.shadow_container.widget = widget
