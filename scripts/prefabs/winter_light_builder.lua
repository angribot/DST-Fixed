local prefab = {
	"winter_ornament_light1",
	"winter_ornament_light2",
	"winter_ornament_light3",
	"winter_ornament_light4",
	"winter_ornament_light5",
	"winter_ornament_light6",
	"winter_ornament_light7",
	"winter_ornament_light8",
}

local function onbuilt(inst, builder)
	local num = math.random(1, 8)
	local item = SpawnPrefab("winter_ornament_light" .. num)
	item.Transform:SetPosition(builder.Transform:GetWorldPosition())
	builder.components.inventory:GiveItem(item, nil, item:GetPosition())
	inst:Remove()
end

-- Vanilla prefabs/critters.lua:MakeBuilder (763928): copy without the pet type
local function MakeBuilder(prefab)
	local function fn()
		local inst = CreateEntity()

		inst.entity:AddTransform()

		inst:AddTag("CLASSIFIED")

		inst.persists = false

		inst:DoTaskInTime(0, inst.Remove)

		if not TheWorld.ismastersim then
			return inst
		end

		inst.OnBuiltFn = onbuilt

		return inst
	end

	return Prefab(prefab .. "_builder", fn)
end

return MakeBuilder("winter_light")
