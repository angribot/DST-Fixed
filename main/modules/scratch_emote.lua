GLOBAL.setfenv(1, GLOBAL)

-- Vanilla emotes.lua:CreateEmoteCommand (763928): copy
local function CreateEmoteCommand(emotedef)
	return {
		aliases = emotedef.aliases,
		prettyname = function(command)
			return string.format(STRINGS.UI.BUILTINCOMMANDS.EMOTES.PRETTYNAMEFMT, FirstToUpper(command.name))
		end,
		desc = function()
			return STRINGS.UI.BUILTINCOMMANDS.EMOTES.DESC
		end,
		permission = COMMAND_PERMISSION.USER,
		params = {},
		emote = true,
		slash = true,
		usermenu = false,
		servermenu = false,
		vote = false,
		serverfn = function(params, caller)
			local player = UserToPlayer(caller.userid)
			if player ~= nil then
				player:PushEvent("emote", emotedef.data)
			end
		end,
		displayname = emotedef.displayname,
	}
end

AddUserCommand(
	"scratch",
	CreateEmoteCommand({
		data = {
			anim = "idle_inaction",
			loop = true,
		},
	})
)
