GLOBAL.setfenv(1, GLOBAL)
local UpvalueUtil = require("upvalueutil")

-- Vanilla components/weapon.lua:Weapon:LaunchProjectile (763928): throws the projectile with the weapon as its owner
-- Vanilla components/projectile.lua:Projectile:Hit (763928): uses the weapon's direct holder as attacker, a container if the weapon moved into one mid-flight
-- Vanilla components/projectile.lua:Projectile:Miss (763928): takes the weapon's direct holder as the attacker
local Projectile = require("components/projectile")
local StopTrackingDelayOwner = UpvalueUtil.GetUpvalue(Projectile.Hit, "StopTrackingDelayOwner")

local function get_wielder(weapon)
	local holder = weapon.components.inventoryitem.owner
	while holder ~= nil and holder.components.combat == nil and holder.components.inventoryitem ~= nil and holder.components.inventoryitem.owner ~= nil do
		holder = holder.components.inventoryitem.owner
	end
	return holder
end

-- Vanilla components/projectile.lua:Projectile:Hit (763928): copied, taking the holder of the container the weapon is in as the attacker
function Projectile:Hit(target)
	local attacker = self.owner
	local weapon = self.inst
	StopTrackingDelayOwner(self)
	self:Stop()
	self.inst.Physics:Stop()

	if attacker.components.combat == nil and attacker.components.weapon ~= nil and attacker.components.inventoryitem ~= nil then
		weapon = (self.has_damage_set and weapon.components.weapon ~= nil) and weapon or attacker
		attacker = get_wielder(attacker)
	end

	if self.onprehit ~= nil then
		self.onprehit(self.inst, attacker, target)
	end
	if attacker ~= nil and attacker.components.combat ~= nil then
		if attacker.components.combat.ignorehitrange then
			attacker.components.combat:DoAttack(target, weapon, self.inst, self.stimuli)
		else
			attacker.components.combat.ignorehitrange = true
			attacker.components.combat:DoAttack(target, weapon, self.inst, self.stimuli)
			attacker.components.combat.ignorehitrange = false
		end
		if not self.inst:IsValid() then
			return
		end
	end
	if self.onhit ~= nil then
		self.onhit(self.inst, attacker, target)
	end
end

-- Vanilla components/projectile.lua:Projectile:Miss (763928): copied, taking the holder of the container the weapon is in as the attacker
function Projectile:Miss(target)
	local attacker = self.owner
	if attacker ~= nil and attacker.components.combat == nil and attacker.components.weapon ~= nil and attacker.components.inventoryitem ~= nil then
		attacker = get_wielder(attacker)
	end
	StopTrackingDelayOwner(self)
	self:Stop()
	if self.onmiss ~= nil then
		self.onmiss(self.inst, attacker, target)
	end
end
