local Keystone = require("Logic.Keystone")

describe("Logic.Keystone", function()
	describe("AppendSuffix", function()
		it("appends the abbreviation and level to the name", function()
			local result = Keystone.AppendSuffix("Mythic Keystone", "Pit of Saron", 10)
			assert.are.equal("Mythic Keystone (PoS +10)", result)
		end)

		it("falls back to the full dungeon name when no abbreviation is known", function()
			local result = Keystone.AppendSuffix("Mythic Keystone", "Some Future Dungeon", 5)
			assert.are.equal("Mythic Keystone (Some Future Dungeon +5)", result)
		end)

		it("returns name unchanged when dungeonName is nil (no owned keystone)", function()
			assert.are.equal("Mythic Keystone", Keystone.AppendSuffix("Mythic Keystone", nil, nil))
		end)

		it("returns name unchanged when level is nil", function()
			assert.are.equal("Mythic Keystone", Keystone.AppendSuffix("Mythic Keystone", "Skyreach", nil))
		end)

		it("returns nil unchanged when name itself is nil (item not cached yet)", function()
			assert.is_nil(Keystone.AppendSuffix(nil, "Skyreach", 5))
		end)
	end)

	it("exposes the stable Mythic Keystone itemID", function()
		assert.are.equal(180653, Keystone.ITEM_ID)
	end)
end)
