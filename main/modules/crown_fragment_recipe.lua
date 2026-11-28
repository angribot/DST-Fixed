local RecipeUtil = require("utils/recipe2util")
local AddRecipe = RecipeUtil.AddRecipe
local AddDeconstructRecipe = AddDeconstructRecipe
GLOBAL.setfenv(1, GLOBAL)

AddRecipe("alterguardianhatshard", { Ingredient("moonglass", 160) }, TECH.LOST, { nomods = true, no_deconstruction = true }, { "REFINE" })
STRINGS.RECIPE_DESC.ALTERGUARDIANHATSHARD = STRINGS.CHARACTERS.GENERIC.DESCRIBE.ALTERGUARDIANHATSHARD

AddDeconstructRecipe("alterguardianhat", { Ingredient("alterguardianhatshard", 5), Ingredient("alterguardianhatshard_blueprint", 1) })
