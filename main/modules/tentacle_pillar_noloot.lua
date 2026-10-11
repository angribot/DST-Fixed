local AddSimPostInit = AddSimPostInit
GLOBAL.setfenv(1, GLOBAL)

AddSimPostInit(function()
	SetSharedLootTable("tentacle_pillar", {})
end)
