local function onsewn(inst, target, doer)
	if target.prefab == "nightsword" and inst.prefab == "nightmarefuel" and doer.SoundEmitter then
		doer.SoundEmitter:PlaySound("dontstarve/common/nightmareAddFuel")
	else
		doer:PushEvent("repair")
	end
end

local Sewingnew = Class(function(self, inst)
	self.inst = inst
	self.repair_maps = {}
	self.onsewn = onsewn
	self.quick = {}
end)

function Sewingnew:AddRepairMap(addmap)
	table.insert(self.repair_maps, addmap)
	self.inst:AddTag("sewingnew")
end

function Sewingnew:SetRepairMap(addmap)
	self.repair_maps = addmap
end

function Sewingnew:AddQuickTarget(prefab)
	table.insert(self.quick, prefab)
end

function Sewingnew:GetValue(targetname)
	for k, v in pairs(self.repair_maps) do
		if type(v) == "table" then
			if v[1] == targetname then
				return v[2]
			end
		end
	end
	return 0
end

function Sewingnew:DoSewing(target, doer)
	local repair_value = self:GetValue(target.prefab)
	local needconsume = true
	if target.components.perishable then
		if self.inst.prefab == target.prefab then
			local freshrate = self.inst.components.perishable:GetPercent()
			target.components.perishable:ReducePercent(-1 * freshrate)
			self.inst:Remove()
			needconsume = false
		elseif self.inst.components.perishable and self.inst.components.perishable:IsFresh() then
			target.components.perishable:ReducePercent(-1 * repair_value)
		elseif self.inst.components.perishable and self.inst.components.perishable:IsStale() then
			target.components.perishable:ReducePercent(-2 / 3 * repair_value)
		elseif self.inst.components.perishable and self.inst.components.perishable:IsSpoiled() then
			target.components.perishable:ReducePercent(-1 / 3 * repair_value)
		else
			target.components.perishable:ReducePercent(-1 * repair_value)
		end
		if needconsume then
			if self.inst.components.finiteuses then
				self.inst.components.finiteuses:Use(1)
			elseif self.inst.components.stackable then
				self.inst.components.stackable:Get(1):Remove()
			else
				self.inst:Remove()
			end
		end

		if self.onsewn then
			self.onsewn(self.inst, target, doer)
		end
		return true
	end
	if target.components.finiteuses then
		if self.inst.prefab == target.prefab then
			local getuses = self.inst.components.finiteuses:GetUses()
			target.components.finiteuses:Use(-1 * getuses)
			if self.inst.components.container then
				self.inst.components.container:DropEverything()
			end

			self.inst:Remove()
			needconsume = false
		elseif self.inst.prefab == "nightmarefuel" then
			local wetmult = self.inst:GetIsWet() and TUNING.WET_FUEL_PENALTY or 1
			target.components.finiteuses:Use(-1 * repair_value * wetmult)
		else
			target.components.finiteuses:Use(-1 * repair_value)
		end
		if target.components.finiteuses:GetPercent() > 1 then
			target.components.finiteuses:SetPercent(1)
		end
		if needconsume then
			if self.inst.components.finiteuses then
				self.inst.components.finiteuses:Use(1)
			elseif self.inst.components.stackable then
				self.inst.components.stackable:Get(1):Remove()
			end
		end

		if self.onsewn then
			self.onsewn(self.inst, target, doer)
		end
		return true
	end
	if target.components.fueled then
		if self.inst.prefab == target.prefab then
			target.components.fueled:DoDelta(self.inst.components.fueled.currentfuel)
			self.inst:Remove()
			needconsume = false
		elseif self.inst.prefab == "lightbulb" or self.inst.prefab == "nightmarefuel" then
			local wetmult = self.inst:GetIsWet() and TUNING.WET_FUEL_PENALTY or 1
			target.components.fueled:DoDelta(repair_value * wetmult)
		else
			target.components.fueled:DoDelta(repair_value)
		end
		if needconsume then
			if self.inst.components.finiteuses then
				self.inst.components.finiteuses:Use(1)
			elseif self.inst.components.stackable then
				self.inst.components.stackable:Get(1):Remove()
			end
		end

		if self.onsewn then
			self.onsewn(self.inst, target, doer)
		end
		return true
	end
	if target.components.armor then
		if self.inst.prefab == target.prefab then
			local armorrate = self.inst.components.armor:GetPercent()
			target.components.armor:SetPercent(math.min(1, (target.components.armor:GetPercent() + armorrate)))
			self.inst:Remove()
			needconsume = false
		else
			local targetamor = target.components.armor:GetPercent()
			target.components.armor:SetPercent(math.min(1, targetamor + repair_value))
		end
		if needconsume then
			if self.inst.components.finiteuses then
				self.inst.components.finiteuses:Use(1)
			elseif self.inst.components.stackable then
				self.inst.components.stackable:Get(1):Remove()
			end
		end

		if self.onsewn then
			self.onsewn(self.inst, target, doer)
		end
		return true
	end
end

return Sewingnew
