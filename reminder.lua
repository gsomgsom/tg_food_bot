-- Напоминалка про обеды
-- Работает на полставки демоном
local tablex         = require( "pl.tablex" )
local stringx        = require( "pl.stringx" )
local inspect        = require( "inspect" )
local cfg            = require( "config" )
local bot, extension = require( "lua-bot-api" ).configure( cfg.token )
socket = require("socket")
while( 1 ) do
	socket.sleep( 1 )
	local w = tonumber( os.date( "%w", os.time() ) )
	local dt = os.date( "%H:%M:%S", os.time() )
	if dt == '13:00:00' then
		if w > 0 and w < 6 then
			bot.sendMessage( cfg.chat_id, "Кушать пора!\n" )
		end
		socket.sleep( 60 )
	end
end

