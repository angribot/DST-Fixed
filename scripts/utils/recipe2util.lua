-- Vanilla modutil.lua:getfenvminfield (763928): copy
local function getfenvminfield(level, fieldname)
	level = level + 1
	while
		debug.getinfo(level) ~= nil and (debug.getinfo(level).func == nil or rawget(getfenv(level), fieldname) == nil)
	do
		level = level + 1
	end
	assert(
		debug.getinfo(level) ~= nil,
		"Field " .. tostring(fieldname) .. " not found in callstack's functions' environments"
	)
	return getfenv(level)[fieldname]
end

-- Vanilla modutil.lua:initprint (763928): copy
local function initprint(...)
	if KnownModIndex:IsModInitPrintEnabled() then
		local modname = getfenvminfield(3, "modname")
		print(ModInfoname(modname), ...)
	end
end

local function RecipeNoSearch(recipe)
	local CraftingMenuWidget = require("widgets/redux/craftingmenu_widget")
	local is_recipe_valid_for_search = CraftingMenuWidget.IsRecipeValidForSearch
	function CraftingMenuWidget:IsRecipeValidForSearch(name)
		local ret = { is_recipe_valid_for_search(self, name) }
		if name == recipe then
			return
		end
		return unpack(ret)
	end
end

local function AddRecipeToFilter(recipe_name, filter_name)
	initprint("AddRecipeToFilter", recipe_name, filter_name)
	local filter = CRAFTING_FILTERS[filter_name]
	if filter ~= nil and filter.default_sort_values[recipe_name] == nil then
		table.insert(filter.recipes, recipe_name)
		filter.default_sort_values[recipe_name] = #filter.recipes
	end
end

---@param name string
---@param ingredients table
---@param tech table
---@param config table? AddRecipe2's config; hidden = true also keeps the recipe out of search and the Everything filter
---@param filters string[]? filters to add the recipe to besides the defaults AddRecipe2 picks from config
local function AddRecipe(name, ingredients, tech, config, filters)
	initprint("AddRecipe2", name)
	require("recipe")
	mod_protect_Recipe = false
	local rec = Recipe2(name, ingredients, tech, config)

	if not rec.is_deconstruction_recipe then
		if config and config.nounlock then
			AddRecipeToFilter(name, CRAFTING_FILTERS.CRAFTING_STATION.name)
		end

		if config and config.builder_tag and config.nochar == nil then
			AddRecipeToFilter(name, CRAFTING_FILTERS.CHARACTER.name)
		end

		if config and config.nomods == nil then
			AddRecipeToFilter(name, CRAFTING_FILTERS.MODS.name)
		end

		if config and config.hidden then
			RecipeNoSearch(name)
		end

		if filters then
			for _, filter_name in ipairs(filters) do
				AddRecipeToFilter(name, filter_name)
			end
		end
	end

	mod_protect_Recipe = true
	rec:SetModRPCID()
	return rec
end
local function get_index(t, v)
	for index, value in pairs(t) do
		if value == v then
			return index
		end
	end
end

local function do_sorting(a, b, filter_name, offset, force_sort)
	local filter = CRAFTING_FILTERS[filter_name]
	if filter and filter.recipes and type(filter.recipes) == "table" then
		local target_position
		local recipes = filter.recipes
		if get_index(recipes, a) then
			if force_sort or table.contains(recipes, b) then
				table.remove(recipes, get_index(recipes, a))
				target_position = #recipes + 1
			end
		end

		if get_index(recipes, b) then
			target_position = get_index(recipes, b) + offset
		end

		if type(target_position) == "number" then
			table.insert(recipes, target_position, a)
			filter.default_sort_values[a] = filter.default_sort_values[a] or #recipes
		end
	end
end

local function try_sorting(a, b, filter_type, offset)
	if filter_type then
		do_sorting(a, b, filter_type, offset, true)
	elseif b then
		for filter, data in pairs(CRAFTING_FILTERS) do
			do_sorting(a, b, filter, offset)
		end
	end
end

---@param a string recipe to move
---@param b string? recipe to place a next to; without filter_type, in every filter holding b
---@param filter_type string? the only filter to sort; a already in it goes last when b is not, and b may then be nil
local function SortBefore(a, b, filter_type)
	try_sorting(a, b, filter_type, 0)
end

---@param a string recipe to move
---@param b string? recipe to place a next to; without filter_type, in every filter holding b
---@param filter_type string? the only filter to sort; a already in it goes last when b is not, and b may then be nil
local function SortAfter(a, b, filter_type)
	try_sorting(a, b, filter_type, 1)
end

return {
	AddRecipe = AddRecipe,
	SortBefore = SortBefore,
	SortAfter = SortAfter,
}
