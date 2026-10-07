local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local TakeItemString = ACTIONS.TAKEITEM.stroverridefn
ACTIONS.TAKEITEM.stroverridefn = function(act)
	local target = act.target
	if target ~= nil and target.prefab == "gelblob_storage" and target.takeitem ~= nil then
		local item = target.takeitem:value()
		local stackable = item ~= nil and item.replica.stackable or nil
		if stackable ~= nil and stackable:StackSize() > stackable:OriginalMaxSize() then
			local name = item:GetBasicDisplayName()
			if name ~= nil then
				return subfmt(STRINGS.ACTIONS.TAKEITEM.ITEM, {
					item = name .. " x" .. tostring(stackable:OriginalMaxSize()),
				})
			end
		end
	end
	return TakeItemString(act)
end

local preserve = require("dst_fixed/ickerpreserve")
AddPrefabPostInit("gelblob_storage", function(inst)
	if TheWorld.ismastersim then
		preserve.Install(inst)
	end
end)
