local AddStategraphPostInit = AddStategraphPostInit
GLOBAL.setfenv(1, GLOBAL)

-- Confirmed in DST build 761239: interrupting abandon_ship_pre (e.g. armor
-- breaking) can leave the plank mounted and non-interactable. After a game
-- update, recheck the interrupted path in scripts/stategraphs/SGwilson.lua.
-- Remove this module and its modmain entry once vanilla releases that occupancy.
AddStategraphPostInit("wilson", function(self)
	local onexit = self.states["abandon_ship_pre"].onexit
	self.states["abandon_ship_pre"].onexit = function(inst, ...)
		local user = inst.components.walkingplankuser
		local plank = user ~= nil and user.current_plank or nil
		local walkingplank = plank ~= nil and plank:IsValid() and plank.components.walkingplank or nil

		-- Normal abandonment already dismounts. Only release our own leftover
		-- occupancy; never replay a completed or cancelled buffered action.
		if walkingplank ~= nil and walkingplank.doer == inst then
			user:Dismount()
		end
		if onexit then
			return onexit(inst, ...)
		end
	end
end)
