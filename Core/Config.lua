local _, Folio = ...

local Config = {}
Folio.Config = Config

local defaults = {
	frame = {
		width = 320,
		height = 500,
		point = "RIGHT",
		relativePoint = "RIGHT",
		x = -40,
		y = 0,
	},
	pinnedCurrencies = {},
	seededCurrencies = false,
	-- F8: "Default on; must degrade gracefully when off."
	bagReplacementEnabled = true,
	-- Bag-space readout next to the Show Bags button (UI/Frame.lua) --
	-- "12/20" by default, "60%" when this is on.
	showBagSpaceAsPercent = false,
	-- R2: manual category assignment, keyed by itemID. A sticky override
	-- no rule can move -- checked before rule resolution in
	-- Data/Assign.lua.
	itemOverrides = {},
	-- Manual drag-to-reorder positions within a category, keyed
	-- itemOrder[categoryID][storage] -> ordered array of itemIDs
	-- (Logic/Sort.lua applies this on top of the natural scan order).
	itemOrder = {},
	-- Pinned items (UI/Row.lua's star toggle) -- ordered array of itemIDs,
	-- shown as a flat section above every category (Logic/Render.lua)
	-- regardless of which category they're actually filed under.
	pinnedItemIDs = {},
	-- Q53: per-window/section collapse state -- collapsedByStorage[storage]
	-- (storage = "bags"/"bank") -> categoryID -> bool, only for
	-- categories explicitly toggled in that specific window; anything
	-- absent falls back to the category's own default (Logic/Tree.lua's
	-- node.collapsed) in Logic/Render.lua. Expanding a category in the
	-- bank drawer no longer expands it in the main bags window too.
	collapsedByStorage = {},
	-- Counter for user-created category ids ("custom1", "custom2", ...).
	-- A persisted counter rather than a timestamp keeps ids short and
	-- collision-free without pulling time() into this init path.
	nextCategoryID = 1,
}

function Config.Init()
	FOLIO_DB = FOLIO_DB or {}
	FOLIO_DB.frame = FOLIO_DB.frame or CopyTable(defaults.frame)
	FOLIO_DB.pinnedCurrencies = FOLIO_DB.pinnedCurrencies or CopyTable(defaults.pinnedCurrencies)
	if FOLIO_DB.seededCurrencies == nil then
		FOLIO_DB.seededCurrencies = defaults.seededCurrencies
	end
	if FOLIO_DB.bagReplacementEnabled == nil then
		FOLIO_DB.bagReplacementEnabled = defaults.bagReplacementEnabled
	end
	if FOLIO_DB.showBagSpaceAsPercent == nil then
		FOLIO_DB.showBagSpaceAsPercent = defaults.showBagSpaceAsPercent
	end
	FOLIO_DB.itemOverrides = FOLIO_DB.itemOverrides or CopyTable(defaults.itemOverrides)
	FOLIO_DB.itemOrder = FOLIO_DB.itemOrder or CopyTable(defaults.itemOrder)
	FOLIO_DB.pinnedItemIDs = FOLIO_DB.pinnedItemIDs or CopyTable(defaults.pinnedItemIDs)
	FOLIO_DB.collapsedByStorage = FOLIO_DB.collapsedByStorage or CopyTable(defaults.collapsedByStorage)
	FOLIO_DB.nextCategoryID = FOLIO_DB.nextCategoryID or defaults.nextCategoryID
	-- F11: seed once. Folio.Seed is pure (no WoW API calls), safe to run
	-- here at ADDON_LOADED time rather than waiting for PLAYER_LOGIN. Once
	-- FOLIO_DB.categories exists (even as an emptied-out tree, if the user
	-- deletes everything later) this never re-seeds.
	--
	-- WoW: Forever beta build 1.60.1.69893 had a client-side bug
	-- (ClassicWoWCommunity/forever-bugs#34) where SavedVariables weren't
	-- always read back before ADDON_LOADED, making this branch re-seed
	-- over real data. Fixed client-side as of later beta builds.
	if not FOLIO_DB.categories then
		FOLIO_DB.categories = Folio.Seed.BuildDefaultTree()
	end
	Config.db = FOLIO_DB
end

return Config
