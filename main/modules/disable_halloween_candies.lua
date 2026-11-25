local UpvalueUtil = require("upvalueutil")
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local CANDIES = {}
for i = 1, NUM_HALLOWEENCANDY do
	CANDIES["halloweencandy_" .. i] = true
end

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

-- Vanilla prefabs/pigman.lua:MakeFrankenPig (763928): adds candies as chance loot
-- Vanilla prefabs/bunnyman.lua:MakeVampireBunny (763928): adds candies as chance loot
-- Vanilla prefabs/merm.lua:MakeMummyMerm (763928): adds candies as chance loot
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

-- Vanilla stategraphs/SGmermking.lua:trade (763928): calls inst:TradeItem() for regular and Hallowed Nights trades alike
wrap_instance_method("mermking", "TradeItem", without_spawned_candies)
-- Vanilla prefabs/leafpile.lua:DropLootFor (763928): turns every rolled drop into Ash when burnt
wrap_instance_method("leafpile", "DropLootFor", without_spawned_candies)
wrap_instance_method("pigman", "MakeFrankenPig", without_candy_chance_loot)
wrap_instance_method("bunnyman", "MakeVampireBunny", without_candy_chance_loot)
wrap_instance_method("merm", "MakeMummyMerm", without_candy_chance_loot)
