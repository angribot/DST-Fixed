local RecipeUtil = require("utils/recipe2util")
local AddRecipe = RecipeUtil.AddRecipe
local SortAfter = RecipeUtil.SortAfter
GLOBAL.setfenv(1, GLOBAL)

AddRecipe("book_gardening", { Ingredient("papyrus", 2), Ingredient("seeds", 5), Ingredient("poop", 5) }, TECH.SCIENCE_THREE, { nomods = true, builder_tag = "bookbuilder" })
SortAfter("book_gardening", "book_birds")
