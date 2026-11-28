modimport("main/actions/repairable_equipment.lua")
local AddPrefabPostInitAny = AddPrefabPostInitAny
local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

local function MakeRepairable(inst)
	if not TheWorld.ismastersim then
		return
	end
	if not inst.components.inventoryitem then
		return
	end

	if inst.components.finiteuses or inst.components.fueled or inst.components.armor or (inst.components.perishable and inst.components.equippable) then
		inst:AddComponent("sewingnew")
		inst.components.sewingnew:AddRepairMap(inst.prefab)
	end
end

AddPrefabPostInitAny(MakeRepairable)
AddComponentPostInit("playercontroller", function(self)
	local do_action_auto_equip = self.DoActionAutoEquip
	self.DoActionAutoEquip = function(self, buffaction, ...)
		if buffaction.action == ACTIONS.SEWINGNEW then
			return
		end
		return do_action_auto_equip(self, buffaction, ...)
	end
end)
