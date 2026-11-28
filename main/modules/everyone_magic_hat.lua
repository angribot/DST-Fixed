local AddPlayerPostInit = AddPlayerPostInit
GLOBAL.setfenv(1, GLOBAL)

local function IsStillUsingTool(doer)
	return doer.components.magician.item ~= nil
end

local USEMAGICTOOL_fn = ACTIONS.USEMAGICTOOL.fn
ACTIONS.USEMAGICTOOL.fn = function(act)
	if USEMAGICTOOL_fn(act) then
		if act.doer and act.doer.components.sanity and act.doer.prefab ~= "waxwell" and not act.doer:HasTag("mio_boosted_task") then
			act.doer.components.sanity:DoDelta(-15)
		end
		return IsStillUsingTool(act.doer)
	end
end

AddPlayerPostInit(function(inst)
	if not TheWorld.ismastersim then
		return
	end

	if not inst.components.magician then
		inst:AddComponent("magician")
	end

	local onload = inst.OnLoad
	inst.OnLoad = function(inst, ...)
		if onload ~= nil then
			onload(inst, ...)
		end
		inst.components.magician:StopUsing()
	end
end)
