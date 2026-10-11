local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local sisturn_itemtestfn = require("containers").params.sisturn.itemtestfn
local function sisturn_test_fn(container, item, slot)
	return item:HasTag("sisturnbattery") or sisturn_itemtestfn(container, item, slot)
end

AddPrefabPostInit("sisturn", function(inst)
	if not TheWorld.ismastersim then
		inst.OnEntityReplicated = function(inst)
			if inst.replica.container then
				inst.replica.container.itemtestfn = sisturn_test_fn
			end
		end
		return
	end

	local container = inst.components.container
	removesetter(container, "itemtestfn")
	container.itemtestfn = sisturn_test_fn
	if inst.replica.container then
		inst.replica.container.itemtestfn = sisturn_test_fn
	end
	makereadonly(container, "itemtestfn")
end)

local function battery_postinit(inst)
	inst:AddTag("sisturnbattery")
end

local battery_list = {
	"petals",
	"boneshard",
	"ghostflower",
}

for _, v in ipairs(battery_list) do
	AddPrefabPostInit(v, battery_postinit)
end
