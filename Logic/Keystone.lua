-- Q42: one-off cosmetic feature -- appends "(<dungeon abbreviation>
-- +<level>)" to the Mythic Keystone item's name, matching how players
-- actually refer to their current key ("I've got a +10 Pit of Saron")
-- rather than the bare "Mythic Keystone" every key shares. Pure Lua (T1)
-- -- the actual dungeon/level lookup is a real API call
-- (Core/API.lua's GetOwnedKeystoneInfo), this just formats what it
-- returns.

local Keystone = {}

-- Blizzard's one evolving item -- itemID unchanged since Legion,
-- confirmed still 180653 in Midnight (Wowhead).
Keystone.ITEM_ID = 180653

-- No firmly established community shorthand turned up for Midnight's
-- brand-new dungeon pool (searched -- these dungeons are only ~5 months
-- old) -- these are Folio's own best-guess abbreviations. Easy to change
-- here (and in Tests/spec/keystone_spec.lua) if the community settles on
-- something different.
local ABBREVIATIONS = {
	-- Season 1 (started 2026-03-17)
	["Magister's Terrace"] = "MT",
	["Maisara Caverns"] = "MC",
	["Nexus-Point Xenas"] = "NPX",
	["Windrunner Spire"] = "WS",
	["Algeth'ar Academy"] = "AA",
	["Seat of the Triumvirate"] = "SotT",
	["Skyreach"] = "SR",
	["Pit of Saron"] = "PoS",
	-- Season 2 (starts 2026-08-18/19)
	["Altar of Fangs"] = "AF",
	["Murder Row"] = "MR",
	["Den of Nalorakk"] = "DoN",
	["The Blinding Vale"] = "BV",
	["Voidscar Arena"] = "VA",
	["Ruby Life Pools"] = "RLP",
	["Kings' Rest"] = "KR",
	["Temple of Sethraliss"] = "ToS",
}

-- dungeonName/level: whatever Core/API.lua's GetOwnedKeystoneInfo
-- returned (nil/nil if the player doesn't currently own a keystone, or
-- the query hasn't resolved yet) -- returns name unchanged in that case.
-- Falls back to the full dungeon name if it isn't in ABBREVIATIONS yet (a
-- future season's dungeon) rather than silently dropping the suffix.
function Keystone.AppendSuffix(name, dungeonName, level)
	if not name or not dungeonName or not level then
		return name
	end
	local abbr = ABBREVIATIONS[dungeonName] or dungeonName
	return name .. " (" .. abbr .. " +" .. level .. ")"
end

local _, Folio = ...
if type(Folio) == "table" then
	Folio.Keystone = Keystone
end

return Keystone
