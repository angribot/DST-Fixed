local AddAction = AddAction
local AddComponentAction = AddComponentAction
local AddPrefabPostInit = AddPrefabPostInit
local AddStategraphState = AddStategraphState
local AddStategraphActionHandler = AddStategraphActionHandler
GLOBAL.setfenv(1, GLOBAL)

local UpvalueUtil = require("upvalueutil")
local writeables = require("writeables")
local kinds = UpvalueUtil.GetUpvalue(writeables.makescreen, "kinds")
if not kinds then
	print("Warning! Nameable CAN NOT gets kinds from writeables!")
	return
end

local SUPPORTED_WATCHES = {
	["pocketwatch_portal"] = true,
	["pocketwatch_recall"] = true,
}

local data = {
	prompt = "",
	animbank = "ui_board_5x3",
	animbuild = "ui_board_5x3",
	menuoffset = Vector3(6, -70, 0),

	cancelbtn = {
		text = STRINGS.BEEFALONAMING.MENU.CANCEL,
		cb = nil,
		control = CONTROL_CANCEL,
	},

	acceptbtn = {
		text = STRINGS.BEEFALONAMING.MENU.ACCEPT,
		cb = nil,
		control = CONTROL_ACCEPT,
	},
}

for k in pairs(SUPPORTED_WATCHES) do
	kinds[k] = data
end

local RecallMark = require("components/recallmark")

local Copy = RecallMark.Copy
function RecallMark:Copy(rhs, ...)
	if rhs and SUPPORTED_WATCHES[self.inst.prefab] and SUPPORTED_WATCHES[rhs.prefab] and self.inst.watch_record_name and rhs.watch_record_name then
		self.inst.watch_record_name:set(rhs.watch_record_name:value())
	end
	return Copy(self, rhs, ...)
end

local RENAME_WATCH = Action({ mount_valid = true })

RENAME_WATCH.id = "RENAME_WATCH"

RENAME_WATCH.str = STRINGS.ACTIONS.WRITE

RENAME_WATCH.fn = function(act)
	if act.doer and act.doer.sg and act.target.components.writeable then
		if act.invobject.components.stackable then
			act.invobject.components.stackable:Get():Remove()
		else
			act.invobject:Remove()
		end

		act.target.components.writeable:BeginWriting(act.doer)
		act.doer.sg.statemem.tool_prefab = act.invobject.prefab
		act.doer.sg.statemem.target = act.target
		return true
	end
end

AddAction(RENAME_WATCH)

AddComponentAction("USEITEM", "drawingtool", function(inst, doer, target, actions, right)
	if SUPPORTED_WATCHES[target.prefab] and target.watch_record_name then
		table.insert(actions, ACTIONS.RENAME_WATCH)
	end
end)

local actionhandlers = {
	ActionHandler(RENAME_WATCH, "rename_watch"),
}

local states = {
	State({
		name = "rename_watch",
		tags = { "doing", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("action_uniqueitem_pre")
			inst.AnimState:PushAnimation("reading_in", false)
			inst.AnimState:PushAnimation("reading_loop", true)
			local buffaction = inst:GetBufferedAction()
			local target = buffaction and buffaction.target
			inst.AnimState:OverrideSymbol("book_cook", target and target.AnimState:GetBuild() or "pocketwatch_recall", "watchprop")
		end,

		timeline = {
			TimeEvent(7 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
			TimeEvent(8 * FRAMES, function(inst)
				inst:PerformBufferedAction()
			end),
		},

		events = {
			EventHandler("end_rename_watch", function(inst, data)
				inst.sg.statemem.chain_end = true
				inst.sg:GoToState("rename_watch_pst", data)
			end),
		},

		onupdate = function(inst)
			if inst.sg.statemem.target and not CanEntitySeeTarget(inst, inst.sg.statemem.target) then
				inst.sg:GoToState("idle", true)
			end
		end,

		onexit = function(inst)
			inst.AnimState:ClearOverrideSymbol("book_cook")
			if not inst.sg.statemem.chain_end then
				inst.AnimState:PlayAnimation("reading_pst")
				if inst.sg.statemem.tool_prefab then
					inst.components.inventory:GiveItem(SpawnPrefab(inst.sg.statemem.tool_prefab), nil, inst:GetPosition())
				end
				local target = inst.sg.statemem.target
				if target and target:IsValid() and target.components.writeable then
					target.components.writeable:EndWriting()
				end
			end
		end,
	}),

	State({
		name = "rename_watch_pst",
		tags = { "doing", "busy", "nodangle" },

		onenter = function(inst, data)
			inst.sg.statemem.cb = data.cb
			inst.sg.statemem.params = data.params
			inst.sg.statemem.writeable = data.writeable
			inst.components.locomotor:Stop()
			inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
			inst.AnimState:PlayAnimation("build_pre")
			inst.AnimState:PushAnimation("build_loop", true)
			inst.sg:SetTimeout(15 * FRAMES)
		end,

		ontimeout = function(inst)
			inst.sg:RemoveStateTag("busy")
			inst.SoundEmitter:KillSound("make")
			inst.AnimState:PlayAnimation("build_pst")
			inst.sg.statemem.cb(unpack(inst.sg.statemem.params))
		end,

		events = {
			EventHandler("animqueueover", function(inst)
				if inst.AnimState:AnimDone() then
					inst.sg:GoToState("idle")
				end
			end),
		},

		onexit = function(inst)
			inst.SoundEmitter:KillSound("make")
			local writeable = inst.sg.statemem.writeable
			if writeable and writeable:IsBeingWritten() then
				writeable:EndWriting()
			end
		end,
	}),
}

local states_client = {
	State({
		name = "rename_watch",
		tags = { "doing", "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make_preview")
			inst.AnimState:PlayAnimation("build_pre")
			inst.AnimState:PushAnimation("build_loop", true)

			inst:PerformPreviewBufferedAction()
		end,

		timeline = {
			TimeEvent(7 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("busy")
			end),
		},

		onexit = function(inst)
			inst.SoundEmitter:KillSound("make_preview")
		end,
	}),
}

for _, actionhandler in pairs(actionhandlers) do
	AddStategraphActionHandler("wilson", actionhandler)
	AddStategraphActionHandler("wilson_client", actionhandler)
end

for _, state in pairs(states) do
	AddStategraphState("wilson", state)
end
for _, state in pairs(states_client) do
	AddStategraphState("wilson_client", state)
end

local function OnWritten(inst, text)
	inst.watch_record_name:set(text and text ~= "" and text or "")
	inst.SoundEmitter:PlaySound("dontstarve/common/together/draw")
end

local function WatchPostInit(inst)
	inst.watch_record_name = net_string(inst.GUID, "watch_record_name")

	local displaynamefn = inst.displaynamefn
	inst.displaynamefn = function(inst, ...)
		local name = inst.watch_record_name:value()
		if name ~= "" then
			return table.concat({ STRINGS.NAMES[string.upper(inst.prefab)], " (", name, ")" })
		end
		if displaynamefn then
			return displaynamefn(inst, ...)
		else
			return STRINGS.NAMES[string.upper(inst.prefab)]
		end
	end

	if not TheWorld.ismastersim then
		return
	end

	if not inst.components.writeable then
		inst:AddComponent("writeable")
	end
	inst.components.writeable:SetDefaultWriteable(false)
	inst.components.writeable:SetAutomaticDescriptionEnabled(false)
	local Write = inst.components.writeable.Write
	inst.components.writeable.Write = function(self, doer, text, ...)
		if self.writer == doer and doer and doer.sg and doer.sg.currentstate.name == "rename_watch" and (text == nil or text:utf8len() <= MAX_WRITEABLE_LENGTH) then
			if text == nil then
				doer.sg:GoToState("idle", true)
			else
				doer:PushEvent("end_rename_watch", {
					writeable = self,
					cb = Write,
					params = { self, doer, text, ... },
				})
			end
		else
			return Write(self, doer, text, ...)
		end
	end
	inst.components.writeable:SetOnWrittenFn(OnWritten)

	local on_save = inst.OnSave
	inst.OnSave = function(inst, data, ...)
		local watch_record_name = inst.watch_record_name:value()
		data.watch_record_name = watch_record_name ~= "" and watch_record_name or nil
		if on_save then
			return on_save(inst, data, ...)
		end
	end

	local on_load = inst.OnLoad
	inst.OnLoad = function(inst, data, ...)
		if data and data.watch_record_name then
			inst.watch_record_name:set(data.watch_record_name)
		end
		if on_load then
			return on_load(inst, data, ...)
		end
	end

	inst:DoTaskInTime(0, function(inst)
		inst.drawnameoverride = rawget(_G, "EncodeStrCode") and EncodeStrCode({ content = "NAMES." .. string.upper(inst.prefab) })
	end)
end

for k in pairs(SUPPORTED_WATCHES) do
	AddPrefabPostInit(k, WatchPostInit)
end
