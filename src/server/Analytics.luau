--[[
	Analytics — события для Creator Dashboard → Analytics.

	* onboarding(player, step, name) — воронка новичка (вход → площадка → комната 1 → …)
	* funnel(player, funnel, sessionId, step, name) — прохождение главы по комнатам
	* economy(player, source/sink, amount, balance, transactionType, sku) — поток осколков
	* custom(player, name, value) — прочее (покупка пропуска, рекорд пары…)

	Все вызовы в pcall: ошибка аналитики никогда не ломает игру.
]]

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local CURRENCY = "Shards"

local function safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Analytics]", err)
	end
end

function Analytics.onboarding(player: Player, step: number, name: string)
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.funnel(player: Player, funnelName: string, sessionId: string, step: number, stepName: string)
	safe(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId, step, stepName)
	end)
end

-- flow: "Source" (получил) или "Sink" (потратил)
-- transactionType: "Gameplay" | "IAP" | "Shop" | "TimedReward" | "ContextualPurchase" | "Onboarding"
function Analytics.economy(
	player: Player,
	flow: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	sku: string?
)
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player,
			(Enum.AnalyticsEconomyFlowType :: any)[flow],
			CURRENCY,
			amount,
			endingBalance,
			(Enum.AnalyticsEconomyTransactionType :: any)[transactionType].Name,
			sku
		)
	end)
end

function Analytics.custom(player: Player, eventName: string, value: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, eventName, value or 1)
	end)
end

return Analytics
