require("prefabutil")

local assets = {
	Asset("MINIMAP_IMAGE", "townportalactive"),
}

local fx_assets = {
	Asset("ANIM", "anim/teleport_sand_fx.zip"),
	Asset("ANIM", "anim/sand_splash_fx.zip"),
}

local prefabs = {
	"collapse_small",
	"globalmapicon",
	"townportalsandcoffin_fx",
}

-- Vanilla prefabs/townportal.lua:OnStartChanneling (763928): copy without the animation and sound
local function OnStartChanneling(inst, channeler)
	TheWorld:PushEvent("townportalactivated", inst)

	inst.MiniMapEntity:SetIcon("townportalactive.png")
	inst.MiniMapEntity:SetPriority(20)

	if inst.icon then
		inst.icon.MiniMapEntity:SetIcon("townportalactive.png")
		inst.icon.MiniMapEntity:SetPriority(20)
		inst.icon.MiniMapEntity:SetDrawOverFogOfWar(true)
	end

	inst.channeler = channeler.components.sanity and channeler or nil
	if inst.channeler then
		inst.channeler.components.sanity:DoDelta(-TUNING.SANITY_MED)
		inst.channeler.components.sanity.externalmodifiers:SetModifier(inst, -TUNING.DAPPERNESS_SUPERHUGE)
	end
end

-- Vanilla prefabs/townportal.lua:OnStopChanneling (763928): copy that also removes the portal 10 seconds later
local function OnStopChanneling(inst, aborted)
	TheWorld:PushEvent("townportaldeactivated", inst)

	inst.MiniMapEntity:SetIcon("townportal.png")
	inst.MiniMapEntity:SetPriority(0)

	if inst.icon then
		inst.icon.MiniMapEntity:SetIcon("townportal.png")
		inst.icon.MiniMapEntity:SetPriority(0)
	end

	if inst.channeler and inst.channeler:IsValid() and inst.channeler.components.sanity then
		inst.channeler.components.sanity.externalmodifiers:RemoveModifier(inst)
	end

	inst:DoTaskInTime(10, function(inst)
		inst:Remove()
	end)
end

-- Vanilla prefabs/townportal.lua:OnLinkTownPortals (763928): copy without the animation and sound
local function OnLinkTownPortals(inst, other)
	inst.components.teleporter:Target(other)
	if inst.components.channelable:IsChanneling() then
		inst.components.channelable:StopChanneling(true)
	else
		inst.components.channelable:SetEnabled(other == nil)
	end
end

-- Vanilla prefabs/townportal.lua:OnStartTeleporting (763928): copy
local function OnStartTeleporting(inst, doer)
	if doer:HasTag("player") then
		if doer.components.talker then
			doer.components.talker:ShutUp()
		end
		if doer.components.sanity then
			doer.components.sanity:DoDelta(-TUNING.SANITY_HUGE)
		end
	end
end

-- Vanilla prefabs/townportal.lua:OnExitingTeleporter (763928): copy
local function OnExitingTeleporter(inst, obj)
	if obj and obj:HasTag("player") then
		obj:DoTaskInTime(1, obj.PushEvent, "townportalteleport")
	end
end

-- Vanilla prefabs/townportal.lua:init (763928): copy
local function init(inst)
	if inst.icon == nil then
		inst.icon = SpawnPrefab("globalmapicon")
		inst.icon:TrackEntity(inst)
	end
end

-- Vanilla prefabs/townportal.lua:GetStatus (763928): copy
local function GetStatus(inst)
	return (inst.components.channelable:IsChanneling() or inst.components.teleporter:IsActive()) and "ACTIVE" or nil
end

-- Vanilla prefabs/townportal.lua:fn (763928): copy that no player can click or see, removed unless channeled within 1 second
local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	inst.MiniMapEntity:SetIcon("townportal.png")
	inst.MiniMapEntity:SetCanUseCache(false)
	inst.MiniMapEntity:SetDrawOverFogOfWar(true)

	inst:AddTag("NOCLICK")
	inst:AddTag("townportal")
	MakeSnowCoveredPristine(inst)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("channelable")
	inst.components.channelable:SetChannelingFn(OnStartChanneling, OnStopChanneling)
	inst.components.channelable:SetEnabled(true)

	inst:AddComponent("teleporter")
	inst.components.teleporter.onActivate = OnStartTeleporting
	inst.components.teleporter.offset = 2
	inst.components.teleporter.saveenabled = false
	inst.components.teleporter.travelcameratime = 2.9
	inst.components.teleporter.travelarrivetime = 2.8

	inst:ListenForEvent("doneteleporting", OnExitingTeleporter)

	inst:ListenForEvent("linktownportals", OnLinkTownPortals)

	TheWorld:PushEvent("ms_registertownportal", inst)

	inst:DoTaskInTime(0, init)

	inst:DoTaskInTime(1, function(inst)
		if GetStatus(inst) ~= "ACTIVE" then
			inst:Remove()
		end
	end)

	return inst
end

return Prefab("townportal_invisible", fn, assets, prefabs)
