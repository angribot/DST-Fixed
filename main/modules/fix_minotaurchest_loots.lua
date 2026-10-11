local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local UpvalueUtil = require("upvalueutil")

local chest_loot = {
	{ item = { "armorruins", "ruinshat" }, count = 1 }, -- {item = {"armorruins", "ruinshat", "ruins_bat"}, count = 1},
	{ item = { "orangestaff" }, count = 1 }, -- {item = {"orangestaff", "yellowstaff"}, count = 1},
	-- {item = {"orangeamulet", "yellowamulet"}, count = 1},
	{ item = { "yellowgem" }, count = { 2, 4 } },
	{ item = { "orangegem" }, count = { 2, 4 } },
	{ item = { "greengem" }, count = { 2, 3 } },
	{ item = { "thulecite" }, count = { 8, 14 } },
	{ item = { "thulecite_pieces" }, count = { 12, 36 } },
	-- {item = {"gears"}, count = {3, 6}},
}

local function dospawnchest(inst, loading)
	local chest = SpawnPrefab("minotaurchest")
	local x, y, z = inst.Transform:GetWorldPosition()
	chest.Transform:SetPosition(x, 0, z)

	--Set up chest loot
	if not WORLDSTATETAGS.GetTagEnabled("ATRIUM_KEY_FOUND") then
		chest.components.container:GiveItem(SpawnPrefab("atrium_key"))
	end

	local loot_keys = {}
	for i, _ in ipairs(chest_loot) do
		table.insert(loot_keys, i)
	end
	-- local max_loots = math.min(#chest_loot, chest.components.container.numslots - 1)
	-- loot_keys = PickSome(math.random(max_loots - 2, max_loots), loot_keys)

	for _, i in ipairs(loot_keys) do
		local loot = chest_loot[i]
		local item = SpawnPrefab(loot.item[math.random(#loot.item)])
		if item ~= nil then
			if type(loot.count) == "table" and item.components.stackable ~= nil then
				item.components.stackable:SetStackSize(math.random(loot.count[1], loot.count[2]))
			end
			chest.components.container:GiveItem(item)
		end
	end
	--

	if not chest:IsAsleep() then
		chest.SoundEmitter:PlaySound("dontstarve/common/ghost_spawn")

		local fx = SpawnPrefab("statue_transition_2")
		if fx ~= nil then
			fx.Transform:SetPosition(x, y, z)
			fx.Transform:SetScale(1, 2, 1)
		end

		fx = SpawnPrefab("statue_transition")
		if fx ~= nil then
			fx.Transform:SetPosition(x, y, z)
			fx.Transform:SetScale(1, 1.5, 1)
		end
	end

	if inst.minotaur ~= nil and inst.minotaur:IsValid() and inst.minotaur.sg:HasStateTag("death") then
		inst.minotaur.MiniMapEntity:SetEnabled(false)
		inst.minotaur:RemoveComponent("maprevealable")
	end

	if not loading then
		inst:Remove()
	end
end

AddPrefabPostInit("minotaurchestspawner", function(inst)
	if inst.task ~= nil then
		inst.task:Cancel()
		inst.task = inst:DoTaskInTime(3, dospawnchest)
	end
	local _dospawnchest = UpvalueUtil.GetUpvalue(inst.OnLoad, "dospawnchest")
	if _dospawnchest then
		UpvalueUtil.SetUpvalue(inst.OnLoad, "dospawnchest", dospawnchest)
	end
end)
