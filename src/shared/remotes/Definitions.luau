--!strict
-- Whitelist aller Remote-Namen. Server validiert pro Call.

return {
	Functions = {
		BuyPack = true,
		OpenPack = true,
		PlaceGod = true,
		RemoveGod = true,
		Fuse = true,
		RebirthConfirm = true,
		ClaimQuest = true,
		BuyUpgrade = true,
		ListAuction = true,
		BidAuction = true,
		CancelListing = true,
		SendTradeRequest = true,
		RespondTrade = true,
		OfferItem = true,
		RemoveOffer = true,
		HoldAccept = true,
		ChangeSetting = true,
		SwitchLanguage = true,
		RequestProfile = true,
	} :: { [string]: boolean },

	Events = {
		OnPullResult = true,
		OnInventoryUpdate = true,
		OnEconomyUpdate = true,
		OnBroadcast = true,
		OnTempleUpdate = true,
		OnQuestUpdate = true,
		OnLeaderboardUpdate = true,
		OnLocaleUpdate = true,
		OnTradeUpdate = true,
		OnAuctionUpdate = true,
	} :: { [string]: boolean },
}
