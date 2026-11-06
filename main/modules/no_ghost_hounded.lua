local AddComponentPostInit = AddComponentPostInit
GLOBAL.setfenv(1, GLOBAL)

AddComponentPostInit("hounded", function(self, inst)
	local result_fns = {}
	local needed_fns = {
		OnPlayerJoined = "ms_playerjoined",
		OnPlayerLeft = "ms_playerleft",
	}

	for name, event_name in pairs(needed_fns) do
		local listeners = inst.event_listeners[event_name]
		if listeners then
			for listener, fns in pairs(listeners) do
				for _, fn in ipairs(fns) do
					if string.find(debug.getinfo(fn, "S").source, "hounded") then
						result_fns[name] = fn
						break
					end
				end
			end
		end
	end

	for fn_name, event_name in pairs(needed_fns) do
		if not result_fns[fn_name] then
			print("Can't find " .. fn_name .. " from " .. event_name .. " listeners")
			return
		end
	end

	local function OnPlayerJoined(player)
		result_fns.OnPlayerJoined(player, player)
	end

	local function OnPlayerLeft(player)
		result_fns.OnPlayerLeft(player, player)
	end

	inst:ListenForEvent("ms_playerjoined", function(src, player)
		inst:ListenForEvent("ms_becameghost", OnPlayerLeft, player)
		inst:ListenForEvent("ms_respawnedfromghost", OnPlayerJoined, player)
	end)

	inst:ListenForEvent("ms_playerleft", function(src, player)
		inst:RemoveEventCallback("ms_becameghost", OnPlayerLeft, player)
		inst:RemoveEventCallback("ms_respawnedfromghost", OnPlayerJoined, player)
	end)
end)
