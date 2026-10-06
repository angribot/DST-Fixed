table.insert(PrefabFiles, "moonglass_blow_proj")

local AddPrefabPostInit = AddPrefabPostInit
local AddComponentAction = AddComponentAction
GLOBAL.setfenv(1, GLOBAL)

local params = require("containers").params
params.houndstooth_blowpipe.widget.slotbg = nil

AddComponentAction("INVENTORY", "reloaditem", function(inst, doer, actions)
	local inventory = doer.replica.inventory
	local equipped = inventory and inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	local container = equipped and equipped.replica.container
	if equipped and equipped.prefab == "houndstooth_blowpipe"
		and container and container:IsInfiniteStackSize()
		and not container:IsHolding(inst) then
		for i = #actions, 1, -1 do
			if actions[i] == ACTIONS.CHANGE_TACKLE then
				table.remove(actions, i)
			end
		end
	end
end)

AddPrefabPostInit("moonglass", function(inst)
	inst:AddTag("blowpipeammo")
	inst:AddTag("reloaditem_ammo") -- Action string.
end)

local function auto_refill(inst, prev_item_prefab)
	if not inst.components.container:IsEmpty() then
		return
	end
	local owner = inst.components.inventoryitem.owner
	local inv = owner.components.inventory
	local container = inst.components.container
	local hat = inv and inv:GetEquippedItem(EQUIPSLOTS.HEAD)
	-- local hat_container = hat and hat.prefab == "alterguardianhat" and hat.components.container
	local item_fn = function(item)
		return item.prefab == prev_item_prefab
	end
	local new_item = inv and inv:FindItem(item_fn)
	if new_item then
		inv:RemoveItem(new_item, true)
		container:GiveItem(new_item)
		-- elseif hat_container then
		--     local new_hat_item = hat_container:FindItem(item_fn)
		--     if new_hat_item then
		--         hat_container:RemoveItem(new_hat_item, true)
		--         container:GiveItem(new_hat_item)
		--     end
	end
end

-- [[ Upgradeable]] --
local function on_upgrade(inst, doer, upgraded_from_item)
	local numupgrades = inst.components.upgradeable.numupgrades
	if numupgrades == 1 then
		if inst.components.container then
			inst.components.container:EnableInfiniteStackSize(true)
		end
		if upgraded_from_item then
			local x, y, z = inst.Transform:GetWorldPosition()
			local fx = SpawnPrefab("chestupgrade_stacksize_fx")
			fx.Transform:SetPosition(x, y, z)
		end
	end
	inst:AddComponent("lootdropper")
	inst.components.lootdropper:SetLoot({ "alterguardianhatshard" })

	inst.components.upgradeable.upgradetype = nil
end

local function ondeconstructstructure(inst, caster)
	if inst.components.upgradeable ~= nil and inst.components.upgradeable.numupgrades > 0 then
		if inst.components.lootdropper ~= nil then
			inst.components.lootdropper:SpawnLootPrefab("alterguardianhatshard")
		end
	end
	inst.components.container:DropEverything()
end

local function on_load(inst, data)
	if inst.components.upgradeable ~= nil and inst.components.upgradeable.numupgrades > 0 then
		on_upgrade(inst)
	end
end

local function set_upgradeable(inst)
	local upgradeable = inst:AddComponent("upgradeable")
	upgradeable.upgradetype = UPGRADETYPES.CHEST
	upgradeable:SetOnUpgradeFn(on_upgrade)

	inst:ListenForEvent("ondeconstructstructure", ondeconstructstructure)
	inst.OnLoad = on_load
end

local function displaynamefn(inst)
	return inst:HasTag("chest_upgradeable") and STRINGS.NAMES.HOUNDSTOOTH_BLOWPIPE
		or (STRINGS.NAMES.HOUNDSTOOTH_BLOWPIPE .. " +")
end

----------------------
AddPrefabPostInit("houndstooth_blowpipe", function(inst)
	inst.displaynamefn = displaynamefn

	if not TheWorld.ismastersim then
		return
	end

	inst:RemoveEventCallback("itemget", inst.OnAmmoLoaded)
	local OnAmmoLoaded = inst.OnAmmoLoaded
	inst.OnAmmoLoaded = function(inst, data)
		OnAmmoLoaded(inst, data)
		local weapon = inst.components.weapon
		if weapon and data and data.item and data.item.prefab == "moonglass" then
			weapon:SetProjectile("moonglass_blow_proj")
		end
	end
	inst:ListenForEvent("itemget", inst.OnAmmoLoaded)

	local OnProjectileLaunched = inst.components.weapon.onprojectilelaunched
	inst.components.weapon:SetOnProjectileLaunched(function(_inst, attacker, target)
		if _inst.components.container ~= nil then
			local ammo_stack = _inst.components.container:GetItemInSlot(1)
			local item_prefab = ammo_stack and ammo_stack.prefab

			OnProjectileLaunched(_inst, attacker, target)

			if _inst.components.container:IsEmpty() and item_prefab ~= nil then
				auto_refill(_inst, item_prefab)
			end
		end
	end)

	set_upgradeable(inst)
end)

AddPrefabPostInit("houndstooth_proj", function(inst)
	if not TheWorld.ismastersim then
		return
	end

	if inst.components.projectile then
		inst.components.projectile:SetHoming(true)
	end
end)
