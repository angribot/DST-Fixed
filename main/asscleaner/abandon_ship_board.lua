local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Vanilla stategraphs/SGwilson.lua:abandon_ship_pre (763928): has no onexit, so an interruption such as armor breaking leaves the plank mounted and unusable
AddStategraphPostInit("wilson", function(self)
	local onexit = self.states["abandon_ship_pre"].onexit
	self.states["abandon_ship_pre"].onexit = function(inst, ...)
		local user = inst.components.walkingplankuser
		local plank = user ~= nil and user.current_plank or nil
		local walkingplank = plank ~= nil and plank:IsValid() and plank.components.walkingplank or nil

		-- Vanilla components/walkingplank.lua:WalkingPlank:AbandonShip (763928): dismounts on the normal path, clearing doer
		if walkingplank ~= nil and walkingplank.doer == inst then
			user:Dismount()
		end
		if onexit then
			return onexit(inst, ...)
		end
	end
end)
