local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla prefabs/dummytarget.lua:MakeDummy (763928): gives the dummy 1000 max health and no minimum, so a big enough hit kills it
-- Vanilla prefabs/dummytarget.lua:OnHealthDelta (763928): shows only the latest hit, so hits in one frame replace each other
local function count_dps(t)
	local dps = 0
	local time = GetTime() - 1

	local j = 1
	for i = 1, #t do
		local val = t[i]
		if val.time < time then
			t[i] = nil
		else
			dps = dps + val.amount
			if i ~= j then
				t[j] = val
				t[i] = nil
			end
			j = j + 1
		end
	end

	return dps
end

local function record_dps(t, amount)
	t[#t + 1] = { amount = amount, time = GetTime() }
end

local function do_digits(inst)
	inst.Label:SetText("Hit:" .. inst.last_hit .. "\nFrame:" .. inst._digits_num .. "\nDPS: " .. count_dps(inst.dps_history))
	inst.Label:SetUIOffset(math.random() * 20 - 10, math.random() * 20 + 90, 0)
	inst.AnimState:PlayAnimation("hit")
	inst.AnimState:PushAnimation("idle")

	inst._digits_task = nil
	inst._digits_num = nil
end

local function pre_digits(inst, number)
	inst.last_hit = number
	inst._digits_num = inst._digits_num and (inst._digits_num + number) or number
	record_dps(inst.dps_history, number)

	if inst._digits_task ~= nil then
		inst._digits_task:Cancel()
		inst._digits_task = nil
	end
	inst._digits_task = inst:DoTaskInTime(0, do_digits)
end

local function OnHealthDelta(inst, data)
	if data.amount <= 0 then
		pre_digits(inst, math.abs(data.amount))
	end
end

local function dummytarget_fix(inst)
	if not TheWorld.ismastersim then
		return
	end

	inst.dps_history = {}

	inst.event_listening["healthdelta"][inst] = nil
	inst.event_listeners["healthdelta"][inst] = nil

	local health = inst.components.health
	health:SetMaxHealth(9999 + 10)
	health:SetMinHealth(1)
	health:StartRegen(9999 + 10, 0.1)

	if inst.components.health then
		inst:ListenForEvent("healthdelta", OnHealthDelta)
	end
end

local DUMMYTARGETS = {
	"dummytarget",
	"dummytarget_lunar",
	"dummytarget_shadow",
}
for _, prefab in ipairs(DUMMYTARGETS) do
	AddPrefabPostInit(prefab, dummytarget_fix)
end

-- Vanilla prefabs/dummytarget.lua:MakeDummy (763928): registers the dummies without STRINGS.NAMES entries
local CHS_CODES = {
	["zh"] = true,
	["zht"] = true,
	["chs"] = true,
}

STRINGS.NAMES.DUMMYTARGET = CHS_CODES[LanguageTranslator.defaultlang] and "伤害测试木桩" or "Dummy Target"
STRINGS.NAMES.DUMMYTARGET_LUNAR = CHS_CODES[LanguageTranslator.defaultlang] and "伤害测试木桩（月亮）" or "Lunar Dummy Target"
STRINGS.NAMES.DUMMYTARGET_SHADOW = CHS_CODES[LanguageTranslator.defaultlang] and "伤害测试木桩（暗影）" or "Shadow Dummy Target"
