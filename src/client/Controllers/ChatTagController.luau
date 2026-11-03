--[[
	ChatTagController — тег [VIP] перед именем в чате.
	Сервер ставит атрибут VIP = true владельцам пасса; клиент дописывает префикс.
	Работает с TextChatService (стандартный чат новых игр).
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTagController = {}

local VIP_PREFIX = '<font color="#FFD86E">[VIP]</font> '

function ChatTagController.Start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local sender = Players:GetPlayerByUserId(source.UserId)
			if sender and sender:GetAttribute("VIP") then
				properties.PrefixText = VIP_PREFIX .. message.PrefixText
			end
		end
		return properties
	end
end

return ChatTagController
