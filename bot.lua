-- Непосредственно сам бот telegram
-- Работает на полставки демоном

local tablex         = require( "pl.tablex" )
local stringx        = require( "pl.stringx" )
local inspect        = require( "inspect" )
local JSON           = require( "JSON" )
local cfg            = require( "config" )
local bot, extension = require( "lua-bot-api" ).configure( cfg.token )
local m              = require( "luasql.sqlite3" )
local db             = assert( m.sqlite3() )
local dbc            = assert( db:connect("easteries.db") )

math.randomseed(os.time())

-- перемешать массив
function shuffle( array )
    local n, random, j = table.getn( array ), math.random
    for i = 1, n do
        j, k = random( n ), random( n )
        array[ j ], array[ k ] = array[ k ], array[ j ]
    end
    return array
end

local num = 13 -- сколько вариантов
local easteries = {} -- заведения
local vote_messages = {} -- ID сообщений голосований (для учёта ответа на них)
local easteries_shuffled = {} -- ID перемешанных заведений
local votes = {} -- голоса
local default = "Столовка по-умолчанию"

-- загружает заведения из БД
function load_easteries()
	easteries = {}
	local cursor = assert( dbc:execute ( "SELECT * FROM easteries" ) )
	local row = cursor:fetch ( {}, "a" )
	while row do
		easteries[ tonumber( row.id ) ] = {
			name        = row.name,
			description = row.description,
			lan         = row.lan,
			lng         = row.lng,
			address     = row.address,
			url         = row.url,
			phone       = row.phone,
		}
		row = cursor:fetch ( row, "a" )
	end
	cursor:close()
end

-- загружает перемешанные заведения из БД
function load_shuffled()
	local cursor = assert( dbc:execute ( "SELECT count(*) cnt FROM shuffled" ) )
	local row = cursor:fetch ( {}, "a" )
	if tonumber( row.cnt ) > 0 then
		easteries_shuffled = {}
		cursor = assert( dbc:execute ( "SELECT * FROM shuffled" ) )
		row = cursor:fetch ( {}, "a" )
		while row do
			table.insert( easteries_shuffled, tonumber( row.eastery_id ) )
			row = cursor:fetch ( row, "a" )
		end
		cursor:close()
	else
		shuffle_easteries()
	end
end

-- загружает голоса и ID сообщений о голосовании из БД
function load_votes()
	vote_messages = {}
	cursor = assert( dbc:execute ( "SELECT * FROM vote_messages" ) )
	row = cursor:fetch ( {}, "a" )
	while row do
		table.insert( vote_messages, tonumber( row.message_id ) )
		row = cursor:fetch ( row, "a" )
	end
	cursor:close()

	votes = {}
	cursor = assert( dbc:execute ( "SELECT * FROM votes" ) )
	row = cursor:fetch ( {}, "a" )
	while row do
		votes[ row.username ] = row.eastery -- @TODO переписать соответствия на ID
		row = cursor:fetch ( row, "a" )
	end
	cursor:close()
end

-- перемешивает варианты
function shuffle_easteries()
	easteries_shuffled = shuffle( tablex.keys( easteries ) )
	save_shuffled()
	num = tablex.size( easteries_shuffled )
end

-- сохраняет перемешанные заведения в БД
function save_shuffled()
	dbc:execute( "TRUNCATE TABLE shuffled" )
print(inspect(easteries_shuffled))
	for _, id in pairs( easteries_shuffled ) do
		dbc:execute( "INSERT INTO shuffled (eastery_id)  VALUES (" .. tostring( id ) .. ");" )
	end
end

-- обнуляет список сообщений о голосовании
function clean_vote_messages()
	for n, m in pairs( vote_messages ) do
		bot.editMessageText( cfg.chat_id, m, nil, "Голосование завершено." )
	end
	vote_messages = {}
	dbc:execute ( "TRUNCATE TABLE vote_messages" )
	votes = {}
	dbc:execute ( "TRUNCATE TABLE votes" )
end

-- сохраняет голоса в БД
function save_votes()
	dbc:execute ( "TRUNCATE TABLE votes" )
	for who, what in pairs( votes ) do
		dbc:execute ( "INSERT INTO votes (username, eastery)  VALUES ('" .. tostring( who ) .. "', '" .. tostring( what ) .. "');" )
	end
end


-- загружаем заведения из БД
load_easteries()
load_shuffled()
load_votes()

function generatePoolButtons()
	local variants = {}
	local all_variants = {}
	local i = 1
	-- @TODO - переписать по-нормальному генерацию кнопок
	for n = 0, num / 2 do
		variants = {}
		for m = 1, 2 do
			if easteries_shuffled[ i ] and easteries [ easteries_shuffled[ i ] ] then
				local cnt = 0
				for who, what in pairs( votes ) do
					if what == easteries [ easteries_shuffled[ i ] ].name then
						cnt = cnt + 1
					end
				end
				table.insert( variants, {
					text = easteries [ easteries_shuffled[ i ] ].name .. " [ " .. tostring( cnt ) .. " ]",
					callback_data = 'vote:' .. tostring( easteries_shuffled[ i ] ),
				})
			else
				table.insert( variants, {
					text = 'Не пойду',
					callback_data = 'vote:0',
				})
			end
			i = i + 1
		end
		table.insert(all_variants, variants )
	end

	return JSON:encode({inline_keyboard = all_variants})
end

-- Обработчик сообщений
extension.onTextReceive = function (msg)
	-- обрезаем команды, чтобы работали личные обращения
	msg.text = string.gsub( msg.text, "@" .. cfg.name , "")

	-- /start
	if ( msg.text == "/start" ) then
		bot.sendMessage( msg.chat.id, "Привет!\nЯ робот - ценитель еды. Зовут меня " .. bot.first_name .. "\n\n"
			.. "Команды:\n"
			.. "/reset - начать голосование заново\n"
			.. "/vote - выбор вариантов (можно переголосовать)\n"
			.. "/results - огласить результаты последнего голосования\n"
		)

	-- /reset
	elseif ( msg.text == "/reset" ) then
		shuffle_easteries()
		clean_vote_messages()
		local answer = "Предлагаю сходить (первые ".. tostring( num ) .." в случайном порядке):\n"
		for n = 1, num do
			answer = answer .. easteries [ easteries_shuffled[ n ] ].name .. '\n'
		end

		bot.sendMessage( msg.chat.id, answer )

	-- /vote buttons
	elseif ( msg.text == "/vote" ) then
		local answer = "Голосуем!\n\n"
		local result = bot.sendMessage( msg.chat.id, answer, nil, nil, nil, nil, generatePoolButtons() )
		if result.result and result.result.message_id then
			table.insert( vote_messages, result.result.message_id )
			dbc:execute ( "INSERT INTO vote_messages (message_id)  VALUES (" .. tostring( result.result.message_id ) .. ");" )
		end

	-- /vote results
	elseif ( msg.text == "/results" ) then
		local top = {}
		local voices = 0

		for who, what in pairs( votes ) do
			if top[ what ] == nil then
				top[ what ] = 0
			end
			top[ what ] = top[ what ] + 1
			voices = voices + 1
		end

		local answer = "Результаты:\n\n"

		if voices > 0 then
			answer = answer .. "Всего проголосовало: " .. tostring( voices ) .. "\n\n"
			local n = 1
			for k, v in tablex.sortv( top, function(x,y) return (x > y) end )  do
				answer = answer .. tostring( n ) .. ') ' ..  tostring( k ) .. ': ' .. tostring( v ) .. "\n"
				n = n + 1
			end
		else
			answer = "Никто не проголосовал."
		end

		bot.sendMessage( msg.chat.id, answer )

	-- Все остальные команды
	else
	end
end

extension.onCallbackQueryReceive = function( q )
	print( inspect(q) )
	local vote = q.data:gsub( "vote:" , "" )
	print(inspect(vote))
	vote = tonumber(vote)
	if vote == nil then vote = 0 end
	if vote > 0 then
		votes[ q.from.first_name ] = easteries [ vote ].name
	else
		votes[ q.from.first_name ] = "Не пойду"
	end
	bot.answerCallbackQuery( q.id, "Твой голос - \"" .. votes[ q.from.first_name ] .. "\", учтён!".. q.from.first_name, true)
	bot.editMessageReplyMarkup( q.message.chat.id, q.message.message_id, nil, generatePoolButtons() )
	save_votes()
end

extension.run()

dbc:close()
db:close()
