local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

MATERIALS.MARBLE = "marble"
local function OnRepaired(inst)
	local workleft = inst.components.workable.workleft
	if inst.components.lootdropper.chanceloottable == nil and workleft >= 0 then
		inst.components.lootdropper:SetChanceLootTable("statueglommer")
	end
	if workleft <= 0 then
		inst.AnimState:PlayAnimation("low")
	else
		inst.AnimState:PlayAnimation(workleft < TUNING.ROCKS_MINE * 0.5 and "med" or "full")
	end
	inst.SoundEmitter:PlaySound("dontstarve/common/together/moonbase/repair")
end

local function RemoveComponentProxy(inst, name, ...)
	if name == "workable" then
		return true
	elseif name == "lootdropper" then
		inst.components.lootdropper:SetChanceLootTable(nil)
		return true
	end
end

local function MakeRemoveComponentProxy(fn)
	return function(inst, ...)
		local remove_component = inst.RemoveComponent
		inst.RemoveComponent = function(...)
			if RemoveComponentProxy(...) then
				return
			end
			return remove_component(...)
		end
		fn(inst, ...)
		inst.RemoveComponent = remove_component
	end
end

AddPrefabPostInit("statueglommer", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	if not inst.components.repairable then
		inst:AddComponent("repairable")
	end
	inst.components.repairable.repairmaterial = MATERIALS.MARBLE
	inst.components.repairable.onrepaired = OnRepaired
	inst.components.repairable.noannounce = true

	inst:DoTaskInTime(0, function()
		inst.components.workable:SetMaxWork(TUNING.ROCKS_MINE)
	end)
	inst.components.workable:SetOnWorkCallback(MakeRemoveComponentProxy(inst.components.workable.onwork))
	inst.components.workable:SetOnLoadFn(MakeRemoveComponentProxy(inst.components.workable.onloadfn))
	inst.OnLoad = MakeRemoveComponentProxy(inst.OnLoad)
end)

AddPrefabPostInit("marble", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	if not inst.components.repairer then
		inst:AddComponent("repairer")
	end
	inst.components.repairer.repairmaterial = MATERIALS.MARBLE
	inst.components.repairer.workrepairvalue = 2
end)
