local AddAction = AddAction
local AddComponentAction = AddComponentAction
local AddStategraphActionHandler = AddStategraphActionHandler
GLOBAL.setfenv(1, GLOBAL)

local SEWINGNEW = Action({ mount_valid = true })
SEWINGNEW.id = "SEWINGNEW"
SEWINGNEW.str = ACTIONS.REPAIR.str
SEWINGNEW.fn = function(act)
	local sewtool = act.invobject
	local item = act.target
	if sewtool and sewtool.components.sewingnew and item and (item.components.perishable or item.components.finiteuses or item.components.fueled or item.components.armor) then
		sewtool.components.sewingnew:DoSewing(item, act.doer)
	end
	return true
end

AddAction(SEWINGNEW)
AddComponentAction("USEITEM", "sewingnew", function(inst, doer, target, actions, right)
	if not inst:HasTag("sewingnew") then
		return
	end
	if right then
		if inst.prefab == target.prefab then
			table.insert(actions, 1, ACTIONS.SEWINGNEW)
		end
	end
end)
for _, stage in ipairs({ "wilson", "wilson_client" }) do
	AddStategraphActionHandler(stage, ActionHandler(SEWINGNEW, "dolongaction"))
end
