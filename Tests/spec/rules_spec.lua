local Rules = require("Logic.Rules")

describe("Logic.Rules", function()
	describe("Matches", function()
		it("returns false for a nil rule list (manual-only category)", function()
			assert.is_false(Rules.Matches({ itemClass = 0 }, nil))
		end)

		it("returns false for an empty rule list", function()
			assert.is_false(Rules.Matches({ itemClass = 0 }, {}))
		end)

		it("eq matches equal values", function()
			local rules = { { field = "itemClass", op = "eq", value = 0 } }
			assert.is_true(Rules.Matches({ itemClass = 0 }, rules))
			assert.is_false(Rules.Matches({ itemClass = 1 }, rules))
		end)

		it("neq matches unequal values", function()
			local rules = { { field = "quality", op = "neq", value = 0 } }
			assert.is_true(Rules.Matches({ quality = 3 }, rules))
			assert.is_false(Rules.Matches({ quality = 0 }, rules))
		end)

		it("gte matches values at or above the threshold", function()
			local rules = { { field = "quality", op = "gte", value = 4 } }
			assert.is_true(Rules.Matches({ quality = 4 }, rules))
			assert.is_true(Rules.Matches({ quality = 5 }, rules))
			assert.is_false(Rules.Matches({ quality = 3 }, rules))
		end)

		it("lte matches values at or below the threshold", function()
			local rules = { { field = "stackSize", op = "lte", value = 5 } }
			assert.is_true(Rules.Matches({ stackSize = 5 }, rules))
			assert.is_false(Rules.Matches({ stackSize = 6 }, rules))
		end)

		it("between matches an inclusive range", function()
			local rules = { { field = "ilvl", op = "between", value = { 600, 650 } } }
			assert.is_true(Rules.Matches({ ilvl = 600 }, rules))
			assert.is_true(Rules.Matches({ ilvl = 625 }, rules))
			assert.is_true(Rules.Matches({ ilvl = 650 }, rules))
			assert.is_false(Rules.Matches({ ilvl = 599 }, rules))
			assert.is_false(Rules.Matches({ ilvl = 651 }, rules))
		end)

		it("in matches membership in a list", function()
			local rules = { { field = "equipSlot", op = "in", value = { "HEAD", "CHEST", "LEGS" } } }
			assert.is_true(Rules.Matches({ equipSlot = "CHEST" }, rules))
			assert.is_false(Rules.Matches({ equipSlot = "FEET" }, rules))
		end)

		it("treats a missing field as never matching gte/lte/between/in", function()
			assert.is_false(Rules.Matches({}, { { field = "ilvl", op = "gte", value = 1 } }))
			assert.is_false(Rules.Matches({}, { { field = "ilvl", op = "between", value = { 1, 10 } } }))
			assert.is_false(Rules.Matches({}, { { field = "equipSlot", op = "in", value = { "HEAD" } } }))
		end)

		it("requires every non-exclude predicate to match (AND)", function()
			local rules = {
				{ field = "itemClass", op = "eq", value = 0 },
				{ field = "quality", op = "gte", value = 2 },
			}
			assert.is_true(Rules.Matches({ itemClass = 0, quality = 3 }, rules))
			assert.is_false(Rules.Matches({ itemClass = 0, quality = 1 }, rules))
			assert.is_false(Rules.Matches({ itemClass = 1, quality = 3 }, rules))
		end)

		it("rejects the item if any exclude predicate matches (R3)", function()
			-- "Consumables, but not Junk"
			local rules = {
				{ field = "itemClass", op = "eq", value = "Consumable" },
				{ field = "quality", op = "eq", value = 0, exclude = true }, -- Poor/Junk
			}
			assert.is_true(Rules.Matches({ itemClass = "Consumable", quality = 1 }, rules))
			assert.is_false(Rules.Matches({ itemClass = "Consumable", quality = 0 }, rules))
			assert.is_false(Rules.Matches({ itemClass = "Weapon", quality = 1 }, rules))
		end)

		it("errors on an unknown operator", function()
			assert.has_error(function()
				Rules.Matches({ x = 1 }, { { field = "x", op = "bogus", value = 1 } })
			end)
		end)
	end)

	describe("Resolve", function()
		it("returns the first matching candidate's id (R1)", function()
			local candidates = {
				{ id = "a", rules = { { field = "quality", op = "eq", value = 5 } } },
				{ id = "b", rules = { { field = "quality", op = "gte", value = 0 } } },
			}
			assert.are.equal("a", Rules.Resolve({ quality = 5 }, candidates))
		end)

		it("falls through to a later candidate when an earlier one doesn't match", function()
			local candidates = {
				{ id = "a", rules = { { field = "quality", op = "eq", value = 5 } } },
				{ id = "b", rules = { { field = "quality", op = "gte", value = 0 } } },
			}
			assert.are.equal("b", Rules.Resolve({ quality = 1 }, candidates))
		end)

		it("returns nil when nothing matches", function()
			local candidates = {
				{ id = "a", rules = { { field = "quality", op = "eq", value = 5 } } },
			}
			assert.is_nil(Rules.Resolve({ quality = 1 }, candidates))
		end)

		it("returns nil for an empty candidate list", function()
			assert.is_nil(Rules.Resolve({ quality = 1 }, {}))
		end)

		it("supports R5 nesting scope when the caller pre-merges ancestor rules", function()
			-- "Consumables > Food": item must match Consumables' rules AND
			-- Food's own rules. The caller builds this merged list (e.g. via
			-- Tree.GetPath); Resolve just evaluates it.
			local consumablesRule = { field = "itemClass", op = "eq", value = "Consumable" }
			local foodRule = { field = "subClass", op = "eq", value = "Food" }

			local candidates = {
				{ id = "food", rules = { consumablesRule, foodRule } },
				{ id = "consumables", rules = { consumablesRule } },
			}

			assert.are.equal("food", Rules.Resolve({ itemClass = "Consumable", subClass = "Food" }, candidates))
			assert.are.equal(
				"consumables",
				Rules.Resolve({ itemClass = "Consumable", subClass = "Potion" }, candidates)
			)
			assert.is_nil(Rules.Resolve({ itemClass = "Weapon" }, candidates))
		end)
	end)
end)
