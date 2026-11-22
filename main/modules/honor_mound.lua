local AddAction = AddAction
local AddComponentAction = AddComponentAction
local AddPrefabPostInit = AddPrefabPostInit
local AddStategraphActionHandler = AddStategraphActionHandler
GLOBAL.setfenv(1, GLOBAL)

local BURRYMOUND = Action()

BURRYMOUND.id = "BURRYMOUND"
BURRYMOUND.str = "Burry"
BURRYMOUND.fn = function(act)
	if act.target.AnimState:IsCurrentAnimation("dug") then
		if act.invobject.components.stackable then
			act.invobject.components.stackable:Get():Remove()
		else
			act.invobject:Remove()
		end
		act.target:StartHonored()
		SpawnPrefab("sand_puff").entity:SetParent(act.target.entity)
		return true
	end
end

AddAction(BURRYMOUND)
AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
	if inst.prefab == "ghostflower" and target.prefab == "mound" and target.AnimState:IsCurrentAnimation("dug") then
		table.insert(actions, ACTIONS.BURRYMOUND)
	end
end)

local handler = ActionHandler(ACTIONS.BURRYMOUND, "dolongaction")
AddStategraphActionHandler("wilson", handler)
AddStategraphActionHandler("wilson_client", handler)

local function turnoff(inst)
	inst:TurnOff()
	inst:DoTaskInTime(2, inst.Remove)
end

local function OnCyclesChanged(inst)
	if inst.is_honored and not inst.components.workable then
		inst:AddComponent("workable")
		inst.components.workable:SetWorkAction(ACTIONS.DIG)
		inst.components.workable:SetWorkLeft(1)
		inst.components.workable:SetOnFinishCallback(inst.on_workable_finish)

		if not inst.components.lootdropper then
			inst:AddComponent("lootdropper")
		end

		inst.AnimState:PlayAnimation("gravedirt")

		inst._light = SpawnPrefab("chesterlight")
		-- The dawn autosave runs 1 second after "cycles" changes (autosaver.lua),
		-- and the light removes itself only after 4 seconds, so every light would
		-- otherwise be saved.
		inst._light.persists = false
		inst._light.Transform:SetPosition(inst.Transform:GetWorldPosition())
		inst._light:TurnOn()
		-- inst.SoundEmitter:PlaySound("dontstarve/creatures/chester/raise")

		inst._light:DoTaskInTime(2, turnoff)
	end
	inst:StopHonored()
end

local function StartHonored(inst)
	inst.is_honored = true
	inst.AnimState:PlayAnimation("gravedirt")
	inst:WatchWorldState("cycles", OnCyclesChanged)
end

local function StopHonored(inst)
	inst.is_honored = nil
	inst:StopWatchingWorldState("cycles", OnCyclesChanged)
end

AddPrefabPostInit("mound", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst.on_workable_finish = inst.components.workable and inst.components.workable.onfinish

	inst.StartHonored = StartHonored
	inst.StopHonored = StopHonored

	local getstatus = inst.components.inspectable.getstatus
	inst.components.inspectable.getstatus = function(inst, ...)
		if inst.is_honored then
			return
		end
		if getstatus then
			return getstatus(inst, ...)
		end
	end

	local on_save = inst.OnSave
	inst.OnSave = function(inst, data, ...)
		data.is_honored = inst.is_honored or nil
		if on_save then
			return on_save(inst, data, ...)
		end
	end

	local on_load = inst.OnLoad
	inst.OnLoad = function(inst, data, ...)
		if on_load then
			on_load(inst, data, ...)
		end
		if data and data.is_honored then
			inst:StartHonored()
		end
	end
end)
