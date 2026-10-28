local AddAction = AddAction
local AddComponentAction = AddComponentAction
local AddPrefabPostInit = AddPrefabPostInit
local AddStategraphActionHandler = AddStategraphActionHandler
GLOBAL.setfenv(1, GLOBAL)

local HANDRESKIN = Action({ mount_valid = true, priority = 5 })

HANDRESKIN.id = "HANDRESKIN"
HANDRESKIN.str = STRINGS.ACTIONS.CASTSPELL.RESKIN
HANDRESKIN.fn = function(act)
	if not act.invobject then
		return false
	end
	local staff = act.doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	local act_pos = act:GetActionPoint()
	if staff and staff.components.spellcaster then
		staff.components.spellcaster:CastSpell(act.invobject, act_pos)
		return true
	end
end

AddAction(HANDRESKIN)
local CANT_PREFABS = {
	["cane"] = true,
	["king_cane"] = true,
	["orangestaff"] = true,
	["reskin_tool"] = true,
}

AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions)
	if
		CANT_PREFABS[inst.prefab]
		or (inst.replica.equippable and inst.replica.equippable:IsEquipped())
		or not PREFAB_SKINS[inst.prefab]
	then
		return
	end
	local tool = doer.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	if tool and tool ~= inst and tool.prefab == "reskin_tool" then
		table.insert(actions, ACTIONS.HANDRESKIN)
	end
end)

local handler = ActionHandler(HANDRESKIN, "veryquickcastspell")
AddStategraphActionHandler("wilson", handler)
AddStategraphActionHandler("wilson_client", handler)
