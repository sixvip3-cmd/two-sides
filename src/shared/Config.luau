--[[
	Config — числа, которые можно крутить при балансировке.
]]

return {
	-- Где строятся комнаты сессий: далеко от лобби, каждая сессия в своём «слоте».
	SESSION_BASE = Vector3.new(0, 150, 4000),
	SESSION_SPACING = 400,

	-- Лобби
	MATCH_COUNTDOWN = 3, -- секунд от момента, когда на площадке двое
	PAD_COOLDOWN = 1,

	-- Комнаты
	ZONE_TICK = 0.1, -- как часто сервер проверяет плиты/зоны (сек)
	FALL_LIMIT = 40, -- на сколько ниже пола игрок считается упавшим
	RESPAWN_NOTIFY_COOLDOWN = 3,

	-- Кодовые панели
	KEYPAD_MAX_DISTANCE = 14,
	CODE_SUBMIT_COOLDOWN = 0.75,
	CODE_MAX_LENGTH = 8,
}
