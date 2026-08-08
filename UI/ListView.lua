local _, Folio = ...

-- Blizzard's WowScrollBoxList + MinimalScrollBar per §6.1 — a 400-row
-- list only instantiates the handful of rows actually visible. Renders
-- whatever flattened row list Logic/Render.lua produces (category
-- headers, sub-group headers, and items alike) via one shared row
-- template — see UI/Row.lua.

local ListView = {}
Folio.UI = Folio.UI or {}
Folio.UI.ListView = ListView

local scrollBox, scrollBar, view

function ListView.Create(parent)
	if scrollBox then return scrollBox, scrollBar end

	scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")

	view = CreateScrollBoxListLinearView()
	view:SetElementExtent(Folio.UI.Row.HEIGHT)
	view:SetElementInitializer("BackdropTemplate", function(row, item)
		Folio.UI.Row.Initialize(row, item)
	end)

	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	return scrollBox, scrollBar
end

function ListView.SetItems(items)
	-- BAG_UPDATE_DELAYED can in principle fire before PLAYER_LOGIN has run
	-- Frame.Create() (and so Create() below) -- same latent bug class as
	-- CurrencyBar.SetEntries; nothing to update yet.
	if not view then return end
	local provider = CreateDataProvider()
	if #items > 0 then
		provider:InsertTable(items)
	end
	view:SetDataProvider(provider)
end

return ListView
