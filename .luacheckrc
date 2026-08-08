std = "lua51"
max_line_length = false

-- T1/T2: Logic/ and Data/ must never touch a WoW global directly.
-- Logic/ because it has to run under plain Lua (T1); Data/ because WoW
-- access is supposed to flow through the `api` parameter injected into
-- every function (T2), never reached for directly. "min" is the
-- portable intersection of Lua 5.1/5.2/5.3/LuaJIT stdlib globals --
-- nothing WoW-specific sneaks in. luacheck enforces this far more
-- thoroughly than the CI grep-based check (kept alongside this as a
-- fast, dependency-free first line of defense).
files["Logic/**/*.lua"] = { std = "min" }
files["Data/**/*.lua"] = { std = "min" }

-- Core/ and UI/ are the only files allowed to touch WoW's global
-- namespace directly. Harvested from an actual luacheck run against
-- the codebase rather than guessed, so it's exactly what's used, no
-- more -- if a new WoW API call gets added, luacheck will flag it as
-- undefined until it's deliberately added here.
local wowGlobals = {
	-- Widgets & frame construction
	"CreateFrame", "UIParent", "UISpecialFrames", "GameTooltip",
	"CreateScrollBoxListLinearView", "ScrollUtil", "CreateDataProvider",
	-- Item/container/bank/currency APIs
	"C_Container", "C_Item", "C_CurrencyInfo", "C_Bank", "Enum", "ItemLocation",
	-- Misc game state
	"GetMoney", "GetMoneyString", "GetCursorInfo", "GetCursorPosition",
	"GetMouseFoci", "GetScreenHeight", "ITEM_QUALITY_COLORS", "CopyTable", "time",
}

files["Core/**/*.lua"] = {
	read_globals = wowGlobals,
	-- Folio's own globals: FOLIO_DB is the declared SavedVariable;
	-- SLASH_FOLIO1/SlashCmdList are how WoW's slash command system works.
	globals = { "FOLIO_DB", "SLASH_FOLIO1", "SlashCmdList" },
}
files["UI/**/*.lua"] = { read_globals = wowGlobals }

-- Tests/ use busted's DSL (describe/it/assert/before_each/...).
files["Tests/spec/**/*.lua"] = { std = "lua51+busted" }
