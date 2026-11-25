local AddPrefabPostInit = AddPrefabPostInit
GLOBAL.setfenv(1, GLOBAL)
local UpvalueUtil = require("upvalueutil")

-- Vanilla components/weapon.lua:Weapon:OnAttack (763928): spends durability on hit, so the staff can break while its last projectile is in flight
-- Vanilla prefabs/staff_lunarplant.lua:DisableComponents (763928): removes the weapon on break, though that projectile still passes the staff to Combat:DoAttack as its weapon

local function disable_components(inst)
	inst:RemoveComponent("equippable")
end

local function on_projectile_launched(inst, attacker, target, proj)
	if proj then
		inst:DoTaskInTime(4 * FRAMES, function(inst)
			inst.components.finiteuses:Use(1)
		end)
	end
end

local function SetOnProjectileLaunched(inst)
	inst.components.weapon:SetOnProjectileLaunched(on_projectile_launched)
end

AddPrefabPostInit("staff_lunarplant", function(inst)
	if not TheWorld.ismastersim then
		return
	end
	UpvalueUtil.SetUpvalue(inst.components.finiteuses.onfinished, "onbroken.DisableComponents", disable_components)

	inst:DoTaskInTime(0, SetOnProjectileLaunched)
	inst:ListenForEvent("percentusedchange", function(src, data)
		if data and data.percent == 1 then
			inst:DoTaskInTime(0, SetOnProjectileLaunched)
		end
	end)
	inst.components.finiteuses:SetIgnoreCombatDurabilityLoss(true)
end)

-- Vanilla components/finiteuses.lua:FiniteUses:SetUses (763928): pushes percentusedchange with a negative value before clamping it to 0
local FiniteUses = require("components/finiteuses")
local set_uses = FiniteUses.SetUses
function FiniteUses:SetUses(val)
	val = type(val) == "number" and math.max(val, 0) or val
	set_uses(self, val)
end
