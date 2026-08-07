local _, Folio = ...

-- §12 step 9: virtualized list spike, no categories yet (those land in
-- step 12). Blizzard's WowScrollBoxList + MinimalScrollBar per §6.1 —
-- a 400-row list only instantiates the handful of rows actually visible.

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
	local provider = CreateDataProvider()
	if #items > 0 then
		provider:InsertTable(items)
	end
	view:SetDataProvider(provider)
end

return ListView
