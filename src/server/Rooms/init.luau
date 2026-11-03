--[[
	Rooms — порядок комнат главы 1.
	Чтобы добавить комнату: создай модуль рядом (по образцу Room01) и впиши его в список.
]]

return {
	list = {
		require(script.Room01_TwoSides),
		require(script.Room02_BoxBridge),
		require(script.Room03_Cipher),
	},
}
