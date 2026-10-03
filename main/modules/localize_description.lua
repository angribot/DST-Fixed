local CUSTOMFAILSTR = GetModConfigData("CUSTOMFAILSTR")

local AddPlayerPostInit = AddPlayerPostInit
local AddPrefabPostInit = AddPrefabPostInit
-- local AddPrefabPostInitAny = AddPrefabPostInitAny
local AddClassPostConstruct = AddClassPostConstruct
local modimport = modimport
GLOBAL.setfenv(1, GLOBAL)

STRCODE_HEADER = "/strcode "
STRCODE_SUBFMT = {}
STRCODE_ANNOUNCE = {}
STRCODE_TALKER = {}
STRCODE_POSSIBLENAMES = {}

function EncodeDrawNameCode(ent)
	ent:DoTaskInTime(0, function(inst)
		inst.drawnameoverride = EncodeStrCode({ content = "NAMES." .. string.upper(inst.prefab) })
	end)
end

function IsStrCode(value)
	return type(value) == "string" and value:find("^" .. STRCODE_HEADER)
end

function SubStrCode(str)
	return str:sub(#STRCODE_HEADER + 1, -1)
end

function EncodeStrCode(tbl)
	return STRCODE_HEADER .. json.encode(tbl)
end

local function getmodifiedstring(base_str, topic_tab, modifier)
	if type(modifier) == "table" then
		local tab = topic_tab
		for _, v in ipairs(modifier) do
			if tab == nil then
				return nil
			end
			tab = tab[v]
			base_str = base_str .. "." .. v
		end
		return base_str
	elseif modifier ~= nil then
		local tab = topic_tab[modifier]
		local postfix = (type(tab) == "table" and #tab > 0 and modifier .. "." .. tostring(math.random(#tab)))
			or (tab and modifier)
			or (topic_tab.GENERIC and "GENERIC")
			or (#topic_tab > 0 and tostring(math.random(#topic_tab)))
		if postfix then
			return base_str .. "." .. postfix
		end
	else
		local postfix = (topic_tab.GENERIC and "GENERIC") or (#topic_tab > 0 and tostring(math.random(#topic_tab)))
		if postfix then
			return base_str .. "." .. postfix
		end
	end
end

local function getcharacterstring(base_str, tab, item, modifier)
	if tab then
		local topic_tab = tab[item]
		if type(topic_tab) == "string" then
			return base_str .. "." .. item
		elseif type(topic_tab) == "table" then
			base_str = base_str .. "." .. item
			return getmodifiedstring(base_str, topic_tab, modifier)
		end
	end
end

local function GetSpeechCharacter(inst)
	local character = type(inst) == "string" and inst or (inst ~= nil and inst.prefab or nil)
	local talker = type(inst) == "table" and inst.components and inst.components.talker
	if talker and talker.speechproxy then
		character = talker.speechproxy
	end
	return character ~= nil and string.upper(character) or nil
end

function GetStringCode(inst, stringtype, modifier, stringformat, params)
	local character = GetSpeechCharacter(inst)

	local specialcharacter = type(inst) == "table" and ((inst:HasTag("mime") and "mime") or (inst:HasTag("playerghost") and "ghost")) or character

	if GetSpecialCharacterString(specialcharacter) then
		return
	end

	if stringtype then
		stringtype = string.upper(stringtype)
	end
	if modifier then
		if type(modifier) == "table" then
			for i, v in ipairs(modifier) do
				modifier[i] = string.upper(v)
			end
		else
			modifier = string.upper(modifier)
		end
	end

	local str = character and getcharacterstring("CHARACTERS." .. character, STRINGS.CHARACTERS[character], stringtype, modifier)
		or getcharacterstring("CHARACTERS.GENERIC", STRINGS.CHARACTERS.GENERIC, stringtype, modifier)
	if str then
		local ret = {
			strtype = stringformat,
			content = str,
			params = params,
		}
		return EncodeStrCode(ret)
	end
end
local get_string = GetString
function GetString(inst, stringtype, modifier, ...)
	return GetStringCode(inst, stringtype, modifier) or get_string(inst, stringtype, modifier, ...)
end

local function GetDescriptionCodes(character, inst, item, itemname, modifier)
	local speech = character and STRINGS.CHARACTERS[character]
	local content = {}
	if not speech then
		return content
	end

	local base = "CHARACTERS." .. character
	local description = getcharacterstring(base .. ".DESCRIBE", speech.DESCRIBE, itemname, modifier)
	if description then
		table.insert(content, description)
	end

	local function AddAnnouncement(name)
		local str = getcharacterstring(base, speech, name, modifier)
		if str then
			table.insert(content, str)
		end
	end

	-- Keep the conditions and ordering in sync with GetDescription_AddSpecialCases.
	if type(inst) == "table" then
		if item.components.shadowlevel ~= nil and inst:HasTag("shadowmagic") then
			AddAnnouncement("ANNOUNCE_SHADOWLEVEL_ITEM")
		end
		if inst.components.foodmemory ~= nil and inst.components.foodmemory:GetMemoryCount(item.prefab) > 0 then
			AddAnnouncement("ANNOUNCE_FOODMEMORY")
		end
	end
	if item.components.repairable and not item.components.repairable.noannounce and item.components.repairable:NeedsRepairs() then
		AddAnnouncement("ANNOUNCE_CANFIX")
	end

	return content
end

function GetDescriptionCode(inst, item, modifier, strtype, params)
	local character = GetSpeechCharacter(inst)
	local itemname = item.nameoverride or item.components.inspectable.nameoverride or item.prefab or nil
	itemname = itemname ~= nil and string.upper(itemname) or nil
	if modifier then
		if type(modifier) == "table" then
			for i, v in ipairs(modifier) do
				modifier[i] = string.upper(v)
			end
		else
			modifier = string.upper(modifier)
		end
	end

	local specialcharacter = type(inst) == "table" and ((inst:HasTag("mime") and "mime") or (inst:HasTag("playerghost") and "ghost")) or character

	if GetSpecialCharacterString(specialcharacter) then
		return
	end

	local content = GetDescriptionCodes(character, inst, item, itemname, modifier)
	if #content == 0 then
		content = GetDescriptionCodes("GENERIC", inst, item, itemname, modifier)
	end

	return #content > 0 and EncodeStrCode({
		strtype = strtype,
		content = content,
		params = params,
	}) or nil
end
local get_description = GetDescription
function GetDescription(inst, item, modifier, ...)
	return GetDescriptionCode(inst, item, modifier) or get_description(inst, item, modifier, ...)
end

function GetActionFailStringCode(inst, action, reason, strtype, params)
	local character = type(inst) == "string" and inst or (inst ~= nil and inst.prefab or nil)

	character = character ~= nil and string.upper(character) or nil

	local specialcharacter = type(inst) == "table" and ((inst:HasTag("mime") and "mime") or (inst:HasTag("playerghost") and "ghost")) or character

	if GetSpecialCharacterString(specialcharacter) then
		return
	end

	if action then
		action = string.upper(action)
	end
	if reason then
		if type(reason) == "table" then
			for i, v in ipairs(reason) do
				reason[i] = string.upper(v)
			end
		else
			reason = string.upper(reason)
		end
	end
	local character_speech = character and STRINGS.CHARACTERS[character]
	local str = character_speech and getcharacterstring("CHARACTERS." .. character .. ".ACTIONFAIL", character_speech.ACTIONFAIL, action, reason)
		or getcharacterstring("CHARACTERS.GENERIC.ACTIONFAIL", STRINGS.CHARACTERS.GENERIC.ACTIONFAIL, action, reason)
		or (CUSTOMFAILSTR and character_speech and "CHARACTERS." .. character .. ".ACTIONFAIL_GENERIC" or "CHARACTERS.GENERIC.ACTIONFAIL_GENERIC")

	local ret = {
		strtype = strtype,
		content = str,
		params = params,
	}
	return EncodeStrCode(ret)
end
local get_action_fail_string = GetActionFailString
GetActionFailString = function(inst, action, reason, ...)
	return GetActionFailStringCode(inst, action, reason) or get_action_fail_string(inst, action, reason, ...)
end

local function vanilla_subfmt(s, tab)
	return (s:gsub("(%b{})", function(w)
		return tab[w:sub(2, -2)] or w
	end))
end

function subfmt(s, tab)
	local str = STRCODE_SUBFMT[s]
	if str then
		local ret = {
			strtype = "subfmt",
			content = str,
			params = tab,
		}
		return EncodeStrCode(ret)
	end
	return vanilla_subfmt(s, tab)
end

local function get_string_from_field(str)
	local val = STRINGS
	for v in str:gmatch("[^%.]+") do
		local modifier = tonumber(v) or v
		val = val[modifier]
		if val == nil then
			return
		end
	end
	return val
end

function ResolveStrCode(message)
	if type(message) ~= "string" then
		return
	end
	local data = json.decode(message)
	if not data then
		return
	end

	local res = ""
	if type(data.content) == "table" then
		for _, str in ipairs(data.content) do
			if str:find("^%$") then
				res = res .. str:sub(2, -1)
			else
				local val = get_string_from_field(str)
				if val then
					res = res .. val
				end
			end
		end
	else
		res = get_string_from_field(data.content)
	end

	if data.params then
		for k, v in pairs(data.params) do
			if IsStrCode(v) then
				data.params[k] = get_string_from_field(SubStrCode(v))
			end
		end
	else
		data.params = {}
	end

	if data.strtype == "format" then
		res = string.format(res, unpack(data.params))
	elseif data.strtype == "subfmt" then
		res = vanilla_subfmt(res, data.params)
	end
	return res
end

-- Components Talker --
local Talker = require("components/talker")

local enable_say_parse = true
local TalkerSay = Talker.Say
function Talker:Say(script, time, noanim, ...)
	if enable_say_parse then
		if IsStrCode(script) then
			self:SpeakStrCode(SubStrCode(script), time, noanim)
			return
		elseif TheWorld.ismastersim then
			local strcode = STRCODE_TALKER[script]
			if strcode then
				self:SpeakStrCode(json.encode({ content = strcode }), time, noanim)
				return
			end
		end
	end
	return TalkerSay(self, script, time, noanim, ...)
end

local function OnSpeakerDirty(inst)
	local self = inst.components.talker

	local strcode = self.str_code_speaker.strcode:value()
	if #strcode > 0 then
		local str = ResolveStrCode(strcode)

		if str ~= nil then
			local time = self.str_code_speaker.strtime:value()
			local forcetext = self.str_code_speaker.forcetext:value()
			enable_say_parse = false
			self:Say(str, time > 0 and time or nil, forcetext, forcetext, true)
			enable_say_parse = true
			return
		end
	end

	self:ShutUp()
end

function Talker:MakeStringCodeSpeaker()
	if self.str_code_speaker == nil then
		self.str_code_speaker = {
			strcode = net_string(self.inst.GUID, "talker.str_code_speaker.strcode", "speakerdirty"),
			strtime = net_tinybyte(self.inst.GUID, "talker.str_code_speaker.strtime"),
			forcetext = net_bool(self.inst.GUID, "talker.str_code_speaker.forcetext"),
		}
		if not TheWorld.ismastersim then
			self.inst:ListenForEvent("speakerdirty", OnSpeakerDirty)
		end
	end
end

local function OnCancelSpeaker(inst, self)
	self.str_code_speaker.task = nil
	self.str_code_speaker.strcode:set_local("")
end

-- TODO: Make a net event for repeat speech
--NOTE: forcetext translates to noanim + force say
function Talker:SpeakStrCode(strcode, time, forcetext)
	-- print("SpeakStrCode", strcode)
	if self.str_code_speaker ~= nil and TheWorld.ismastersim then
		self.str_code_speaker.strcode:set(strcode)
		self.str_code_speaker.strtime:set(time or 0)
		self.str_code_speaker.forcetext:set(forcetext == true)
		if self.str_code_speaker.task ~= nil then
			self.str_code_speaker.task:Cancel()
		end
		self.str_code_speaker.task = self.inst:DoTaskInTime(1, OnCancelSpeaker, self)
		OnSpeakerDirty(self.inst)
	end
end

local OnRemoveFromEntity = Talker.OnRemoveFromEntity
function Talker:OnRemoveFromEntity(...)
	self.inst:RemoveEventCallback("speakerdirty", OnSpeakerDirty)
	return OnRemoveFromEntity(self, ...)
end

AddPlayerPostInit(function(inst)
	local talker = inst.components.talker
	if talker then
		talker:MakeStringCodeSpeaker()
	end
end)

local ChatHistoryOnSay = ChatHistory.OnSay
function ChatHistory:OnSay(guid, userid, netid, name, prefab, message, ...)
	if IsStrCode(message) then
		message = ResolveStrCode(SubStrCode(message))
	end
	return ChatHistoryOnSay(self, guid, userid, netid, name, prefab, message, ...)
end

local networking_announcement = Networking_Announcement
function Networking_Announcement(message, ...)
	if IsStrCode(message) then
		message = ResolveStrCode(SubStrCode(message))
	end
	return networking_announcement(message, ...)
end

local announce = NetworkProxy.Announce
function NetworkProxy:Announce(message, ...)
	local strcode = STRCODE_ANNOUNCE[message]
	if strcode then
		message = EncodeStrCode({ content = strcode })
	end
	return announce(self, message, ...)
end

AddClassPostConstruct("components/named_replica", function(self, inst)
	local function OnNameDirty(inst)
		local name = inst.replica.named._name:value()
		inst.name = name ~= "" and (IsStrCode(name) and ResolveStrCode(SubStrCode(name)) or name) or STRINGS.NAMES[string.upper(inst.prefab)]
	end

	if not TheWorld.ismastersim then
		inst:ListenForEvent("namedirty", OnNameDirty)
	end
end)

local Named = require("components/named")
local named_set_name = Named.SetName
function Named:SetName(name, ...)
	named_set_name(self, name, ...)
	if IsStrCode(name) then
		self.inst.name = ResolveStrCode(SubStrCode(name))
	end
end

function Named:PickNewName()
	if self.possiblenames ~= nil and #self.possiblenames > 0 then
		local num = math.random(#self.possiblenames)
		local name = self.possiblenames[num]
		local ret
		if STRCODE_POSSIBLENAMES[self.inst.prefab] then
			local message = STRCODE_POSSIBLENAMES[self.inst.prefab][name]
			message = type(message) == "table" and message[math.random(#message)] or "NAMES.NONE"
			ret = {
				content = {
					message,
				},
			}
		end
		self.name = self.possiblenames[num]
		self.inst.name = self.nameformat ~= nil and string.format(self.nameformat, self.name) or self.name
		self.inst.name_author_netid = self.name_author_netid
		self.inst.replica.named:SetName(ret and EncodeStrCode(ret) or self.name, self.inst.name_author_netid or "")
	end
end

-- fix strings code for specified prefabs
modimport("main/asscleaner/special_description_code")
