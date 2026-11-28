table.insert(PrefabFiles, "winter_light_builder")

local RecipeUtil = require("utils/recipe2util")
local AddRecipe = RecipeUtil.AddRecipe
local SortBefore = RecipeUtil.SortBefore
GLOBAL.setfenv(1, GLOBAL)

STRINGS.NAMES.WINTER_LIGHT_BUILDER = STRINGS.NAMES.WINTER_ORNAMENTLIGHT
STRINGS.RECIPE_DESC.WINTER_LIGHT_BUILDER = STRINGS.CHARACTERS.GENERIC.DESCRIBE.WINTER_ORNAMENTLIGHT

local image = table.concat({ "winter_ornament_light", math.random(1, 8), ".tex" })
local atlas = GetInventoryItemAtlas(image)
AddRecipe("winter_light_builder", { Ingredient("fireflies", 3) }, TECH.SCIENCE_TWO, { nomods = true, atlas = atlas, image = image }, { "LIGHT", "REFINE" })
SortBefore("winter_light_builder", "mushroom_light", "LIGHT")
