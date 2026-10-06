local M = {}

local function Refresh(inst)
	local holder = inst.components.inventoryitemholder
	local item = holder.item
	if item and item.components.stackable then
		item.components.stackable:SetIgnoreMaxSize(true)
	end
	if not item or item.components.stackable then
		inst:AddTag("inventoryitemholder_give")
	end
end

local function OnUpgrade(inst, doer, item)
	inst.components.upgradeable.upgradetype = nil
	Refresh(inst)
	inst.components.lootdropper:SetLoot({ "alterguardianhatshard" })
	if item then
		local fx = SpawnPrefab("chestupgrade_stacksize_fx")
		fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
	end
end

local function TakeItem(holder, taker, wholestack)
	if not holder:CanTake(taker) then
		return false
	end
	local inst = holder.inst
	local held = holder.item
	local stack = held.components.stackable
	local item = stack and stack:Get(wholestack == false and 1 or (stack.originalmaxsize or stack.maxsize)) or held
	local whole = item == held
	if whole then
		inst:RemoveChild(item)
		inst:RemoveEventCallback("onremove", holder._onitemremoved, item)
		inst:RemoveEventCallback("ondropped", holder._onitemmissing, item)
		inst:RemoveEventCallback("onputininventory", holder._onitemmissing, item)
	end
	-- Run the preserve's release callback before inventory merging can remove the item.
	if holder.onitemtakenfn then
		holder.onitemtakenfn(inst, item, taker, whole)
	end
	item:RemoveTag("outofreach")
	item:RemoveTag("NOCLICK")
	if item.Follower then
		item.Follower:StopFollowing()
	end
	item:ReturnToScene()
	item.components.inventoryitem.canbepickedup = true
	if item.components.stackable then
		item.components.stackable:SetIgnoreMaxSize(false)
	end
	if not whole and item.components.perishable and inst._wasperishing == false then
		item.components.perishable:StopPerishing()
	end
	if whole then
		holder.item = nil
	end
	Refresh(inst)
	item.components.inventoryitem:InheritWorldWetnessAtTarget(inst)
	local pos = inst:GetPosition()
	if taker and taker:IsValid() and taker.components.inventory then
		taker.components.inventory:GiveItem(item, nil, pos)
	else
		item.Transform:SetPosition(pos:Get())
		item.components.inventoryitem:OnDropped(true)
	end
	return true
end

function M.DropStacks(inst, count)
	local holder = inst.components.inventoryitemholder
	for i = 1, count do
		if not holder:TakeItem() then
			break
		end
	end
end

local function Destroy(inst, deconstruct)
	local holder = inst.components.inventoryitemholder
	local stack = holder.item and holder.item.components.stackable
	local excess = stack and math.ceil(stack:StackSize() / (stack.originalmaxsize or stack.maxsize)) or (holder.item and 1 or 0)
	if deconstruct then
		inst.components.lootdropper:SpawnLootPrefab("alterguardianhatshard")
	else
		inst.components.lootdropper:DropLoot()
		local fx = SpawnPrefab("collapse_small")
		fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
		fx:SetMaterial("rock")
	end
	if excess >= TUNING.COLLAPSED_CHEST_EXCESS_STACKS_THRESHOLD then
		if TheWorld.Map:IsPassableAtPoint(inst.Transform:GetWorldPosition()) then
			M.DropStacks(inst, TUNING.COLLAPSED_CHEST_MAX_EXCESS_STACKS_DROPS)
			if holder:IsHolding() then
				local pile = SpawnPrefab("collapsed_icker_preserve")
				pile.Transform:SetPosition(inst.Transform:GetWorldPosition())
				pile:SetPreserve(inst)
				inst.no_delete_on_deconstruct = true
				return
			end
		else
			-- As with vanilla collapsed chests, sinking can discard excess contents.
			M.DropStacks(inst, TUNING.COLLAPSED_CHEST_EXCESS_STACKS_THRESHOLD)
		end
	else
		M.DropStacks(inst, excess)
	end
	if not deconstruct then
		inst:Remove()
	end
end

function M.Install(inst)
	if inst._ickerpreserve then
		return
	end
	inst._ickerpreserve = true
	local upgradeable = inst:AddComponent("upgradeable")
	upgradeable.upgradetype = UPGRADETYPES.CHEST
	upgradeable:SetOnUpgradeFn(OnUpgrade)

	local workable = inst.components.workable
	local onwork, onfinish = workable.onwork, workable.onfinish
	workable:SetOnWorkCallback(function(owner, worker, ...)
		if upgradeable.numupgrades > 0 then
			owner.components.inventoryitemholder:TakeItem()
		end
		if onwork then
			onwork(owner, worker, ...)
		end
	end)
	workable:SetOnFinishCallback(function(owner, worker)
		if upgradeable.numupgrades > 0 then
			Destroy(owner, false)
		elseif onfinish then
			onfinish(owner, worker)
		end
	end)
	inst:ListenForEvent("ondeconstructstructure", function(owner)
		if upgradeable.numupgrades > 0 then
			-- Staff already called our bounded TakeItem: no global staff patch is needed.
			Destroy(owner, true)
		end
	end)

	local onload = inst.OnLoad
	inst.OnLoad = function(owner, data, newents)
		if onload then
			onload(owner, data, newents)
		end
		if upgradeable.numupgrades > 0 then
			OnUpgrade(owner)
		end
		if data and data.icker_wasperishing ~= nil then
			owner._wasperishing = data.icker_wasperishing
		end
	end
	local onsave = inst.OnSave
	inst.OnSave = function(owner, data)
		data.icker_wasperishing = owner._wasperishing
		return onsave and onsave(owner, data)
	end

	local holder = inst.components.inventoryitemholder
	local take = holder.TakeItem
	holder.TakeItem = function(self, taker, wholestack)
		if upgradeable.numupgrades > 0 then
			return TakeItem(self, taker, wholestack)
		end
		return take(self, taker, wholestack)
	end
	local given = holder.onitemgivenfn
	holder:SetOnItemGivenFn(function(owner, item, giver)
		if given then
			given(owner, item, giver)
		end
		if upgradeable.numupgrades > 0 then
			Refresh(owner)
		end
	end)
end

function M.RestoreRetained(inst, data)
	if inst._ickerpreserve then
		return -- Enabled-module SpawnSaveRecord already restored the upgrade after component loading.
	end
	M.Install(inst)
	local upgradeable = inst.components.upgradeable
	if data and data.upgradeable then
		upgradeable:OnLoad(data.upgradeable)
	else
		upgradeable.numupgrades = 1
	end
	if data and data.icker_wasperishing ~= nil then
		inst._wasperishing = data.icker_wasperishing
	end
	OnUpgrade(inst)
end

return M
