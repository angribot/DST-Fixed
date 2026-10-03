GLOBAL.setfenv(1, GLOBAL)

local FREE_CHARACTERS = {
	"wilson",
	"willow",
	"wolfgang",
	"wendy",
	"wx78",
	"wickerbottom",
	"woodie",
	"wes",
	"waxwell",
	"wathgrithr",
	"webber",
	"winona",
	"warly",
	--DLC chars:
	-- "wortox",
	-- "wormwood",
	-- "wurt",
	-- "wanda",
	"walter",
	"wonkey",
}

if TheNet:GetIsServer() then
	local check_client_ownership = InventoryProxy.CheckClientOwnership
	function InventoryProxy:CheckClientOwnership(...)
		local args = { ... }
		for _, character in ipairs(FREE_CHARACTERS) do
			if args[2] == character .. "_none" then
				return true
			end
		end
		return check_client_ownership(self, ...)
	end

	local validate_spawn_prefab_request = ValidateSpawnPrefabRequest
	function ValidateSpawnPrefabRequest(...)
		local REAL_PREFAB_SKINS = deepcopy(PREFAB_SKINS)
		local characterlist = GetActiveCharacterList()
		for _, character in ipairs(characterlist) do
			if PREFAB_SKINS[character] then
				for _, _character in ipairs(characterlist) do
					if REAL_PREFAB_SKINS[_character] then
						for _, skin in ipairs(REAL_PREFAB_SKINS[_character]) do
							table.insert(PREFAB_SKINS[character], skin)
						end
					end
				end
			end
		end
		local ret = { validate_spawn_prefab_request(...) }
		PREFAB_SKINS = REAL_PREFAB_SKINS
		return unpack(ret)
	end

	local Wardrobe = require("components/wardrobe")

	local activate_changing = Wardrobe.ActivateChanging
	function Wardrobe:ActivateChanging(doer, skins, ...)
		local get_character_skin_bases = GetCharacterSkinBases
		GetCharacterSkinBases = function()
			local skins = {}
			for _, character in ipairs(GetActiveCharacterList()) do
				shallowcopy(get_character_skin_bases(character), skins)
			end
			return skins
		end
		local ret = { activate_changing(self, doer, skins, ...) }
		GetCharacterSkinBases = get_character_skin_bases
		return unpack(ret)
	end

	local Skinner = require("components/skinner")

	function Skinner:SetSkinMode(skintype, default_build)
		skintype = skintype or self.skintype
		local base_skin = ""

		self.skintype = skintype

		if self.skin_data == nil then
			--fix for legacy saved games with already spawned players that don't have a skin_name set
			self:SetSkinName(self.inst.prefab .. "_none", nil, true)
		end

		if skintype == "ghost_skin" then
			--DST characters should all be using self.skin_data, ghostbuild is legacy for mod characters
			base_skin = self.skin_data[skintype] or self.skin_data["normal_skin"] or self.inst.ghostbuild or default_build or "ghost_" .. self.inst.prefab .. "_build" -- Changed Part
		else
			base_skin = self.skin_data[skintype] or self.skin_data["normal_skin"] or default_build or self.inst.prefab -- Changed Part
		end

		SetSkinsOnAnim(self.inst.AnimState, self.inst.prefab, base_skin, self.clothing, self.monkey_curse, skintype, default_build)

		if self.base_change_cb ~= nil then
			self.base_change_cb()
		end

		self.inst.Network:SetPlayerSkin(self.skin_name or "", self.clothing["body"] or "", self.clothing["hand"] or "", self.clothing["legs"] or "", self.clothing["feet"] or "")
	end
end

-- if TheNet:GetIsClient() then
if not TheNet:IsDedicated() then
	local check_ownership = InventoryProxy.CheckOwnership
	function InventoryProxy:CheckOwnership(skin_name, ...)
		for _, character in ipairs(FREE_CHARACTERS) do
			if skin_name == character .. "_none" then
				return true
			end
		end
		return check_ownership(self, skin_name, ...)
	end

	local ClothingExplorerPanel = require("widgets/redux/clothingexplorerpanel")

	local constructor = ClothingExplorerPanel._ctor
	function ClothingExplorerPanel:_ctor(...)
		constructor(self, ...)
		self.filter_bar:ShowFilter("heroFilter")
	end

	local build_item_explorer = ClothingExplorerPanel._BuildItemExplorer
	function ClothingExplorerPanel:_BuildItemExplorer(...)
		local get_character_skin_bases = GetCharacterSkinBases
		GetCharacterSkinBases = function()
			local skins = {}
			for _, character in ipairs(GetActiveCharacterList()) do
				shallowcopy(get_character_skin_bases(character), skins)
			end
			return skins
		end
		local ret = { build_item_explorer(self, ...) }
		GetCharacterSkinBases = get_character_skin_bases
		return unpack(ret)
	end

	local get_affinity_filter_for_hero = GetAffinityFilterForHero
	function GetAffinityFilterForHero(herocharacter, ...)
		local AffinityFilter = get_affinity_filter_for_hero(herocharacter, ...)
		return function(item_key, ...)
			if string.sub(item_key, -5) == "_none" and string.sub(item_key, 1, -6) ~= herocharacter then
				return false
			end
			return AffinityFilter(item_key, ...)
		end
	end
end
