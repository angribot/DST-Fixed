local preserve = require("ickerpreserve")

-- Temporary vanilla collapsed-chest artwork; storage remains an inventoryitemholder, not a container.
local assets = { Asset("ANIM", "anim/treasure_chest_upgraded.zip") }
local prefabs = { "gelblob_storage", "construction_rebuild_container", "collapse_small", "chestupgrade_stacksize_fx", "alterguardianhatshard" }

local function SetPreserve(inst, storage)
	inst.storage = storage
	storage.no_delete_on_deconstruct = true
	storage.components.workable:SetWorkLeft(4)
	storage.components.workable:SetWorkable(false)
	local item = storage.components.inventoryitemholder.item
	if item then
		if item.Follower then
			item.Follower:StopFollowing()
		end
		item:RemoveFromScene()
	end
	storage:RemoveFromScene()
	inst:AddChild(storage)
	storage.Transform:SetPosition(0, 0, 0)
end

local function Finish(inst)
	inst.components.constructionsite:DropAllMaterials()
	local fx = SpawnPrefab("collapse_small")
	fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
	fx:SetMaterial("rock")
	inst:Remove()
end

local function OnPicked(inst, picker)
	local holder = inst.storage and inst.storage.components.inventoryitemholder
	if holder then
		holder:TakeItem(picker)
	end
	if not holder or not holder:IsHolding() then
		Finish(inst)
	else
		inst.AnimState:PlayAnimation("collapsed_hit")
		inst.AnimState:PushAnimation("collapsed_idle", false)
	end
end

local function OnSink(inst)
	if inst.storage then
		-- Match vanilla's one normal drop followed by bounded excess drops; the remainder is lost.
		preserve.DropStacks(inst.storage, 1 + TUNING.COLLAPSED_CHEST_MAX_EXCESS_STACKS_DROPS)
	end
	Finish(inst)
end

local function OnConstructed(inst)
	if not inst.components.constructionsite:IsComplete() then
		inst.AnimState:PlayAnimation("collapsed_hit")
		inst.AnimState:PushAnimation("collapsed_idle", false)
		return
	end
	local storage = inst.storage
	if storage then
		inst:RemoveChild(storage)
		inst.storage = nil
		storage.Transform:SetPosition(inst.Transform:GetWorldPosition())
		storage:ReturnToScene()
		storage.no_delete_on_deconstruct = nil
		storage.components.workable:SetWorkable(true)
		local item = storage.components.inventoryitemholder.item
		if item then
			item:ReturnToScene()
			item.Follower:FollowSymbol(storage.GUID, "swap_object", 0, 0, 0, true)
		end
		if storage.OnBuiltFn then
			storage:OnBuiltFn()
		end
		storage:PushEvent("restoredfromcollapsed")
	end
	inst:Remove()
end

local function OnSave(inst, data)
	if inst.storage then
		local refs
		data.storage, refs = inst.storage:GetSaveRecord()
		return refs
	end
end

local function OnLoad(inst, data, newents)
	if data and data.storage then
		local storage = SpawnSaveRecord(data.storage, newents)
		if storage then
			-- This prefab stays registered when the option is off. Only its retained preserve
			-- needs upgrade support; ordinary disabled preserves have no migration layer.
			preserve.RestoreRetained(storage, data.storage.data)
			inst:SetPreserve(storage)
		end
	end
end

local function fn()
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()
	inst.AnimState:SetBank("chest_upgraded")
	inst.AnimState:SetBuild("treasure_chest_upgraded")
	inst.AnimState:PlayAnimation("collapsed_idle")
	inst:AddTag("pickable_rummage_str")
	inst:AddTag("constructionsite")
	inst:AddTag("rebuildconstructionsite")
	inst:SetPrefabNameOverride("collapsedchest")
	MakeSnowCoveredPristine(inst)
	inst.entity:SetPristine()
	if not TheWorld.ismastersim then
		return inst
	end
	inst:AddComponent("inspectable")
	inst:AddComponent("constructionsite")
	inst.components.constructionsite:SetConstructionPrefab("construction_rebuild_container")
	inst.components.constructionsite:SetOnConstructedFn(OnConstructed)
	inst:AddComponent("pickable")
	inst.components.pickable.picksound = "dontstarve/wilson/pickup_wood"
	inst.components.pickable.onpickedfn = OnPicked
	inst.components.pickable:SetUp(nil, 0)
	inst:ListenForEvent("onsink", OnSink)
	MakeSnowCovered(inst)
	inst.SetPreserve = SetPreserve
	inst.OnSave = OnSave
	inst.OnLoad = OnLoad
	return inst
end

return Prefab("collapsed_icker_preserve", fn, assets, prefabs)
