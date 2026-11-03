--[[
	EconomyConfig — награды, товары и гейм-пассы.

	ID товаров и пассов появляются после публикации игры:
	Creator Dashboard → игра → Monetization → Developer Products / Passes → создать → скопировать ID.
	Пока id = 0, в Studio покупка СИМУЛИРУЕТСЯ (бесплатно, для теста),
	а в опубликованной игре кнопка пишет «товар ещё не настроен».
	Цены (price) здесь только для отображения — настоящая цена задаётся на сайте.
]]

return {
	Rewards = {
		RoomComplete = 20,
		ChapterComplete = 300,
		NewPartnerBonus = 0.25, -- +25% к наградам, если играешь с этим напарником впервые
		RecentPartnersLimit = 100,
	},

	-- Разовые покупки (Developer Products)
	Products = {
		SkipRoom = {
			id = 0,
			price = 29,
			title = "Пропуск комнаты",
			description = "Пропустить комнату для вас обоих",
		},
		Shards1000 = { id = 0, price = 49, shards = 1000, title = "1 000 осколков" },
		Shards5500 = { id = 0, price = 199, shards = 5500, title = "5 500 осколков", bonus = "+10%" },
		Shards15000 = { id = 0, price = 449, shards = 15000, title = "15 000 осколков", bonus = "+25%" },
		Shards40000 = { id = 0, price = 999, shards = 40000, title = "40 000 осколков", bonus = "+50%" },
	},

	-- Порядок наборов осколков в магазине
	ShardPackOrder = { "Shards1000", "Shards5500", "Shards15000", "Shards40000" },

	-- Гейм-пассы (покупаются один раз)
	GamePasses = {
		DoubleShards = {
			id = 0,
			price = 199,
			title = "x2 Осколки",
			description = "Двойная награда за комнаты навсегда",
		},
		VIP = {
			id = 0,
			price = 299,
			title = "VIP",
			description = "Тег [VIP] в чате и +1 бесплатное яйцо в день",
		},
	},

	GamePassOrder = { "DoubleShards", "VIP" },
}
