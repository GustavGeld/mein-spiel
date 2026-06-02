--!strict
-- TradeController — verwaltet eingehende Trade-Invites und merkt sich
-- die aktuelle Session, damit TradePanel den State direkt rendern kann.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.remotes.Net)
local Locale = require(Shared.locale.Locale)
local Signal = require(Shared.utils.Signal)

local TradeController = {}

-- State, das Panels lesen können
TradeController.session = nil :: any
TradeController.invite = nil :: any
TradeController.holdProgress = { mine = 0, theirs = 0 }

TradeController.SessionChanged = Signal.new()
TradeController.InviteChanged = Signal.new()
TradeController.HoldChanged = Signal.new()
TradeController.Toast = Signal.new() -- (message: string, color: Color3?)

-- ─── Server → Client Updates ──────────────────────────────────────────────────
local function onTradeUpdate(payload)
	if not payload then return end
	if payload.type == "invite" then
		TradeController.invite = payload
		TradeController.InviteChanged:Fire(payload)
	elseif payload.type == "invite_declined" then
		TradeController.Toast:Fire(
			string.format("%s declined your trade request.", payload.byName or "?")
		)
	elseif payload.type == "session" then
		TradeController.session = payload
		TradeController.invite = nil
		TradeController.SessionChanged:Fire(payload)
	elseif payload.type == "hold" then
		TradeController.holdProgress.mine = payload.myHold or 0
		TradeController.holdProgress.theirs = payload.theirHold or 0
		TradeController.HoldChanged:Fire(TradeController.holdProgress)
	elseif payload.type == "end" then
		local state = payload.state
		TradeController.session = nil
		TradeController.holdProgress.mine = 0
		TradeController.holdProgress.theirs = 0
		TradeController.SessionChanged:Fire(nil)
		if state == "completed" then
			TradeController.Toast:Fire(Locale.t("trade.completedBanner"))
		else
			TradeController.Toast:Fire(Locale.t("trade.cancelledBanner"))
		end
	end
end

function TradeController.start()
	Net:Event("OnTradeUpdate").OnClientEvent:Connect(onTradeUpdate)
end

-- ─── Convenience Wrapper ──────────────────────────────────────────────────────
function TradeController.sendInvite(userId: number)
	return Net:Function("SendTradeRequest"):InvokeServer(userId)
end
function TradeController.respond(accept: boolean)
	TradeController.invite = nil
	TradeController.InviteChanged:Fire(nil)
	return Net:Function("RespondTrade"):InvokeServer(accept)
end
function TradeController.offer(uid: string)
	return Net:Function("OfferItem"):InvokeServer(uid)
end
function TradeController.removeOffer(uid: string)
	return Net:Function("RemoveOffer"):InvokeServer(uid)
end
function TradeController.setHolding(holding: boolean)
	return Net:Function("HoldAccept"):InvokeServer(holding)
end
function TradeController.cancel()
	return Net:Function("RespondTrade"):InvokeServer(false)
end

function TradeController.otherPlayers(): { Player }
	local out = {}
	local me = Players.LocalPlayer
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= me then table.insert(out, p) end
	end
	return out
end

return TradeController
