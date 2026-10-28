local UpvalueUtil = require("upvalueutil")
local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local CANDY_PREFIX = "halloweencandy_"

-- Keep the current trade implementation and its custom rewards, then remove only the
-- Halloween candies it spawned. Pumpkin bombs, carvers, tradefor items and gold stay.
local function wrap_ontradeforgold(ontradeforgold)
	return function(inst, item, giver, ...)
		local candies = {}
		local previous_spawn_prefab = SpawnPrefab
		SpawnPrefab = function(prefab, ...)
			local ent = previous_spawn_prefab(prefab, ...)
			if prefab:sub(1, #CANDY_PREFIX) == CANDY_PREFIX then
				candies[#candies + 1] = ent
			end
			return ent
		end

		ontradeforgold(inst, item, giver, ...)

		SpawnPrefab = previous_spawn_prefab
		for i = 1, #candies do
			candies[i]:Remove()
		end
	end
end

AddPrefabPostInit("pigking", function(inst)
	if not TheWorld.ismastersim then
		return
	end
	local ontradeforgold = UpvalueUtil.GetUpvalue(inst.components.trader.onaccept, "ontradeforgold")
	UpvalueUtil.SetUpvalue(inst.components.trader.onaccept, "ontradeforgold", wrap_ontradeforgold(ontradeforgold))
end)
