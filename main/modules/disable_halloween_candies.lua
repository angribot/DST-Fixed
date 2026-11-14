local UpvalueUtil = require("upvalueutil")
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local CANDIES = {}
for i = 1, NUM_HALLOWEENCANDY do
	CANDIES["halloweencandy_" .. i] = true
end

-- Keep the original implementation and its other rewards, then remove only the
-- Halloween candies it spawned. Pumpkin bombs, carvers, ornaments, trinkets, gold
-- and modded rewards stay.
local function without_spawned_candies(fn)
	return function(...)
		local candies = {}
		local previous_spawn_prefab = SpawnPrefab
		SpawnPrefab = function(prefab, ...)
			local ent = previous_spawn_prefab(prefab, ...)
			if ent ~= nil and CANDIES[prefab] then
				candies[#candies + 1] = ent
			end
			return ent
		end

		fn(...)

		SpawnPrefab = previous_spawn_prefab
		for i = 1, #candies do
			candies[i]:Remove()
		end
	end
end

-- Frankenswine, Vamphares and Mermummies add their candies as chance loot when they
-- transform. Skip only those candies; their pumpkin bombs and ornaments still go through.
local function without_candy_chance_loot(fn)
	return function(inst, ...)
		local lootdropper = inst.components.lootdropper
		local own_add_chance_loot = rawget(lootdropper, "AddChanceLoot")
		local add_chance_loot = lootdropper.AddChanceLoot
		lootdropper.AddChanceLoot = function(self, prefab, ...)
			if not CANDIES[prefab] then
				return add_chance_loot(self, prefab, ...)
			end
		end

		fn(inst, ...)

		lootdropper.AddChanceLoot = own_add_chance_loot
	end
end

local function wrap_instance_method(prefab, name, wrapper)
	AddPrefabPostInit(prefab, function(inst)
		if TheWorld.ismastersim and inst[name] ~= nil then
			inst[name] = wrapper(inst[name])
		end
	end)
end

AddPrefabPostInit("pigking", function(inst)
	if not TheWorld.ismastersim then
		return
	end
	local ontradeforgold = UpvalueUtil.GetUpvalue(inst.components.trader.onaccept, "ontradeforgold")
	UpvalueUtil.SetUpvalue(inst.components.trader.onaccept, "ontradeforgold", without_spawned_candies(ontradeforgold))
end)

-- SGmermking calls inst:TradeItem() for both regular and Hallowed Nights trades.
wrap_instance_method("mermking", "TradeItem", without_spawned_candies)
-- Burnt Leaf Piles turn every rolled drop into Ash, so filtering spawns instead of
-- rolled drops keeps that Ash.
wrap_instance_method("leafpile", "DropLootFor", without_spawned_candies)
wrap_instance_method("pigman", "MakeFrankenPig", without_candy_chance_loot)
wrap_instance_method("bunnyman", "MakeVampireBunny", without_candy_chance_loot)
wrap_instance_method("merm", "MakeMummyMerm", without_candy_chance_loot)
