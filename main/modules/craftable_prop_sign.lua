local RecipeUtil = require("utils/recipe2util")
local AddRecipe = RecipeUtil.AddRecipe
GLOBAL.setfenv(1, GLOBAL)

AddRecipe("propsign", { Ingredient("log", 2) }, TECH.MAGIC_THREE, { nomods = true, no_deconstruction = true }, { "TOOLS", "MAGIC" })
STRINGS.NAMES.PROPSIGN = "Prop Sign"
STRINGS.RECIPE_DESC.PROPSIGN = STRINGS.CHARACTERS.GENERIC.DESCRIBE.HOMESIGN.GENERIC
