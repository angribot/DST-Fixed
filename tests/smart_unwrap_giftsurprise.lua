-- Regression harness for Winter's Feast fake gifts.
-- Run from the mod root with: luajit tests/smart_unwrap_giftsurprise.lua

GLOBAL = _G

local prefab_postinits = {}
function AddPrefabPostInit(prefab, fn)
	prefab_postinits[prefab] = fn
end

local Unwrappable = {}
package.preload["components/unwrappable"] = function()
	return Unwrappable
end

function FindWalkableOffset()
	return nil
end

DEGREES = math.pi / 180
TheWorld = {
	Map = { IsPointNearHole = function() return false end },
	meta = { session_identifier = "test-session" },
}

local function point(x, y, z)
	return {
		x = x,
		y = y,
		z = z,
		Get = function(self) return self.x, self.y, self.z end,
	}
end

local inventory_items = {}
local inventory = {
	GiveItem = function(_, item)
		table.insert(inventory_items, item)
		return true
	end,
}

local doer = {
	components = { inventory = inventory },
	Transform = { GetRotation = function() return 0 end },
	GetPosition = function() return point(0, 0, 0) end,
	IsValid = function() return true end,
}

local spawned_hounds = 0
function SpawnPrefab(prefab)
	if prefab == "hound" then
		spawned_hounds = spawned_hounds + 1
		return { prefab = prefab }
	end

	assert(prefab == "giftsurprise", "unexpected prefab: " .. tostring(prefab))
	local item = {
		prefab = prefab,
		valid = true,
		Physics = { Teleport = function() end },
		components = {
			inventoryitem = {
				canbepickedup = false,
				OnDropped = function() end,
			},
		},
	}
	function item:IsValid() return self.valid end
	function item:SetPersistData(data) self.creature = data.creature end
	function item:PushEvent(event)
		if event == "unwrappeditem" then
			SpawnPrefab(self.creature)
			self.valid = false
		end
	end
	return item
end

local bundle_unwrapped_events = 0
local bundle = {
	valid = true,
	components = {},
	GetPosition = function() return point(0, 0, 0) end,
	IsValid = function(self) return self.valid end,
	PushEvent = function(_, event)
		if event == "unwrapped" then
			bundle_unwrapped_events = bundle_unwrapped_events + 1
		end
	end,
}
bundle.components.inventoryitem = {
	GetGrandOwner = function() return doer end,
	GetContainer = function() return inventory end,
	RemoveFromOwner = function() return bundle end,
}

assert(loadfile(os.getenv("SMART_UNWRAP_MODULE") or "main/modules/smart_unwrap.lua"))()

local unwrappable = setmetatable({
	inst = bundle,
	itemdata = {
		{ prefab = "giftsurprise", data = { creature = "hound" } },
	},
	onunwrappedfn = function(inst) inst.valid = false end,
}, { __index = Unwrappable })

unwrappable:Unwrap(doer)

local fake_gifts_in_inventory = 0
for _, item in ipairs(inventory_items) do
	if item.prefab == "giftsurprise" then
		fake_gifts_in_inventory = fake_gifts_in_inventory + 1
	end
end

print(string.format("probe: spawned_hounds=%d fake_gifts_in_inventory=%d",
	spawned_hounds, fake_gifts_in_inventory))
assert(spawned_hounds == 1,
	"fake gift stayed as a question-mark inventory item instead of spawning its hound")
assert(fake_gifts_in_inventory == 0,
	"non-pickable giftsurprise was inserted into the player's inventory")
assert(bundle_unwrapped_events == 1,
	"the gift did not publish its vanilla unwrapped event")

print("PASS: giftsurprise unwraps into a hound and never enters inventory")
