script_name('HZ IA Updater')
script_author('Respected')
script_version('1.0.1')
require 'lib.moonloader'

local requests = require 'requests'
local ROOT = 'https://raw.githubusercontent.com/YagoBMF/setor-advanced/main/I.A%20ATENDIMENTO/HZ_IA/PC/'
local VERSION_URL = ROOT .. 'versao.txt'
local SCRIPT_URL = ROOT .. 'HZ_ATENDIMENTO_IA.lua'
local SCRIPT_PATH = getWorkingDirectory() .. '\\HZ_ATENDIMENTO_IA.lua'
local CONFIG_PATH = getWorkingDirectory() .. '\\config\\hz_ai_config.lua'
local BACKUP_PATH = SCRIPT_PATH .. '.bak'
local TEMP_PATH = SCRIPT_PATH .. '.download'
local busy = false

local function chat(text)
    if isSampAvailable() then sampAddChatMessage(text, -1) end
end

local function read_file(path)
    local file = io.open(path, 'rb')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, 'wb')
    if not file then return false end
    local ok = file:write(content)
    file:flush()
    file:close()
    return ok ~= nil and read_file(path) == content
end

local function body(response)
    return type(response) == 'table' and (response.text or response.body or response.data) or nil
end

local function download(url)
    for attempt = 1, 3 do
        local separator = url:find('?', 1, true) and '&' or '?'
        local target = url .. separator .. 'hzai_cache=' .. os.time() .. math.random(1000, 9999)
        local ok, response = pcall(requests.get, target)
        local content = ok and body(response) or nil
        if type(content) == 'string' and content ~= '' then return content end
        wait(700 * attempt)
    end
end

local function code_version(content)
    return tostring(content or ''):match("script_version%s*%(%s*['\"]([%d%.]+)['\"]%s*%)")
end

local function file_version(content)
    return tostring(content or ''):match('^%s*([%d%.]+)%s*$')
end

local function compare(a, b)
    local left, right = {}, {}
    for n in tostring(a):gmatch('%d+') do left[#left + 1] = tonumber(n) end
    for n in tostring(b):gmatch('%d+') do right[#right + 1] = tonumber(n) end
    for i = 1, math.max(#left, #right) do
        if (left[i] or 0) > (right[i] or 0) then return 1 end
        if (left[i] or 0) < (right[i] or 0) then return -1 end
    end
    return 0
end

local function validate(content, expected)
    if type(content) ~= 'string' or #content < 15000 then return false, 'arquivo incompleto' end
    if content:find('<html', 1, true) or content:find('404: Not Found', 1, true) then return false, 'resposta invalida' end
    if not content:find("script_name('HZ Atendimento IA')", 1, true) then return false, 'assinatura ausente' end
    if code_version(content) ~= expected then return false, 'versoes nao correspondem' end
    local compiled, error_text = loadstring(content, '@HZ_ATENDIMENTO_IA.download')
    if not compiled then return false, 'erro de sintaxe: ' .. tostring(error_text) end
    return true
end

local function migrate_key(current)
    if read_file(CONFIG_PATH) then return true end
    local key = tostring(current or ''):match("local%s+STAFF_KEY%s*=%s*['\"]([^'\"]+)['\"]")
    if not key or key == '' or key:find('COLE_AQUI', 1, true) then
        chat('{FFFF00}[HZ IA UPDATE] Crie config/hz_ai_config.lua antes de usar a IA.')
        return false
    end
    local config = "return {\r\n    staff_key = '" .. key .. "'\r\n}\r\n"
    if write_file(CONFIG_PATH, config) then
        chat('{62E6A7}[HZ IA UPDATE] Chave privada migrada para a pasta config.')
        return true
    end
    chat('{FF5555}[HZ IA UPDATE] Nao foi possivel salvar a configuracao privada.')
    return false
end

local function installed_version()
    return code_version(read_file(SCRIPT_PATH)) or '0.0.0'
end

local function install(silent, force)
    if busy then return chat('{FFFF00}[HZ IA UPDATE] Atualizacao ja em andamento.') end
    busy = true
    lua_thread.create(function()
        if not silent then chat('{48C6FF}[HZ IA UPDATE] Consultando GitHub...') end
        local remote = file_version(download(VERSION_URL))
        local installed = installed_version()
        if not remote then busy=false return chat('{FF5555}[HZ IA UPDATE] Nao foi possivel consultar a versao.') end
        if not force and compare(remote, installed) <= 0 then
            busy=false
            if not silent then chat('{62E6A7}[HZ IA UPDATE] Versao '..installed..' ja esta atualizada.') end
            return
        end
        local new_code = download(SCRIPT_URL)
        local valid, reason = validate(new_code, remote)
        if not valid then busy=false return chat('{FF5555}[HZ IA UPDATE] Cancelada: '..tostring(reason)..'.') end
        local current = read_file(SCRIPT_PATH)
        if not migrate_key(current) then busy=false return end
        if not write_file(TEMP_PATH, new_code) then busy=false return chat('{FF5555}[HZ IA UPDATE] Falha no arquivo temporario.') end
        if current and not write_file(BACKUP_PATH, current) then os.remove(TEMP_PATH);busy=false;return chat('{FF5555}[HZ IA UPDATE] Backup falhou; original preservado.') end
        if not write_file(SCRIPT_PATH, new_code) then
            if current then write_file(SCRIPT_PATH, current) end
            os.remove(TEMP_PATH);busy=false
            return chat('{FF5555}[HZ IA UPDATE] Falha; versao anterior restaurada.')
        end
        os.remove(TEMP_PATH);busy=false
        chat('{62E6A7}[HZ IA UPDATE] Versao '..remote..' instalada. Reinicie o GTA.')
    end)
end

local function rollback()
    local backup = read_file(BACKUP_PATH)
    if not backup or #backup < 15000 then return chat('{FF5555}[HZ IA UPDATE] Backup valido nao encontrado.') end
    if write_file(SCRIPT_PATH, backup) then chat('{62E6A7}[HZ IA UPDATE] Backup restaurado. Reinicie o GTA.') end
end

function main()
    repeat wait(200) until isSampAvailable()
    sampRegisterChatCommand('hzaiversao', function() chat('{48C6FF}[HZ IA UPDATE] Versao instalada: '..installed_version());install(false,false) end)
    sampRegisterChatCommand('hzaiatualizar', function() install(false,true) end)
    sampRegisterChatCommand('hzairollback', rollback)
    wait(10000)
    install(true,false)
    while true do wait(1000) end
end
