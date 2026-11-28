for _, kit in ipairs({ "lunarplant_kit", "voidcloth_kit", "wagpunkbits_kit" }) do
	AddPrefabPostInit(kit, function(inst)
		if not GLOBAL.TheWorld.ismastersim then
			return
		end

		inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
	end)
end
