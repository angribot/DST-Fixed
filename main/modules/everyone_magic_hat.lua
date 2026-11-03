local AddPlayerPostInit = AddPlayerPostInit
GLOBAL.setfenv(1, GLOBAL)

local USEMAGICTOOL_fn = ACTIONS.USEMAGICTOOL.fn
ACTIONS.USEMAGICTOOL.fn = function(act)
	if USEMAGICTOOL_fn(act) then
		if
			act.doer
			and act.doer.components.sanity
			and act.doer.prefab ~= "waxwell"
			and not act.doer:HasTag("mio_boosted_task")
		then
			act.doer.components.sanity:DoDelta(-15)
		end
		-- The sanity cost can stop the tool, e.g. by killing a character whose
		-- sanity loss is redirected to health.
		return act.doer.components.magician.item ~= nil
	end
end

AddPlayerPostInit(function(inst)
	if not TheWorld.ismastersim then
		return
	end

	if not inst.components.magician then
		inst:AddComponent("magician")
	end
end)
