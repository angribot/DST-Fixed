local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

local preserve = require("ickerpreserve")
AddPrefabPostInit("gelblob_storage", function(inst)
	if TheWorld.ismastersim then
		preserve.Install(inst)
	end
end)
