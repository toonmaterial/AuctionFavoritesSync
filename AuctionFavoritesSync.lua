local addonName = ...

local gdb, cdb

local function serializeValues(t)
	local keys, values = {}, {}
	for k in pairs(t) do table.insert(keys, k) end
	table.sort(keys)
	for _, k in ipairs(keys) do table.insert(values, t[k]) end
	return table.concat(values, "-")
end

local function sync(itemKey)
	local key = serializeValues(itemKey)

	if not gdb.favorites[key] == not cdb.favorites[key] then
		return false
	end

	C_AuctionHouse.SetFavoriteItem(itemKey, gdb.favorites[key] ~= nil)
	return true
end

local function setFavorite(itemKey, favorite)
	local key = serializeValues(itemKey)

	gdb.favorites[key] = favorite and itemKey or nil
	cdb.favorites[key] = favorite and itemKey or nil
end

hooksecurefunc(C_AuctionHouse, "SetFavoriteItem", setFavorite)

local f = CreateFrame("Frame")

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:RegisterEvent("AUCTION_HOUSE_CLOSED")

f:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == addonName then
		f:UnregisterEvent("ADDON_LOADED")

		AuctionFavoritesSyncGDB = AuctionFavoritesSyncGDB or {}
		gdb = AuctionFavoritesSyncGDB
		gdb.favorites = gdb.favorites or {}

		AuctionFavoritesSyncCDB = AuctionFavoritesSyncCDB or {}
		cdb = AuctionFavoritesSyncCDB
		cdb.favorites = cdb.favorites or {}

		if not cdb.sync then
			f:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
			f:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
			f:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
			f:RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED")
			f:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
			f:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
		end
	end

	if event == "AUCTION_HOUSE_SHOW" then
		local needRefresh = false

		if cdb.sync then
			for _, favorites in ipairs { gdb.favorites, cdb.favorites } do
				for _, itemKey in pairs(favorites) do
					needRefresh = sync(itemKey) or needRefresh
				end
			end
		else
			for _, itemKey in pairs(gdb.favorites) do
				C_AuctionHouse.SetFavoriteItem(itemKey, true)
				needRefresh = true
			end
		end

		if needRefresh then
			C_AuctionHouse.SearchForFavorites({})
		end
	end

	if event == "AUCTION_HOUSE_CLOSED" then
		cdb.sync = true
		f:UnregisterAllEvents()
	end

	local function processItemKey(itemKey)
		setFavorite(itemKey, C_AuctionHouse.IsFavoriteItem(itemKey))
	end

	if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
		for _, result in ipairs(C_AuctionHouse.GetBrowseResults()) do
			processItemKey(result.itemKey)
		end
	end

	if event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
		for _, result in ipairs(...) do
			processItemKey(result.itemKey)
		end
	end

	if event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
		processItemKey(C_AuctionHouse.MakeItemKey(...))
	end

	if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
		processItemKey(...)
	end
end)
