-- SETOR SEGURANCA - ATUALIZADOR MOBILE INDEPENDENTE
local requests = require 'requests'

local API_BASE = 'https://api.github.com/repos/YagoBMF/setor-advanced/contents/SETOR/MOBILE/'
local VERSION_URL = API_BASE .. 'versao.txt?ref=main'
local SCRIPT_URL = API_BASE .. 'SETOR_SEGURANCA_MOBILE_COMPLETO.lua?ref=main'
local SCRIPT_NAME = 'SETOR_SEGURANCA_MOBILE_COMPLETO.lua'
local atualizando = false
local GITHUB_OPTIONS = {headers = {
    ['Accept'] = 'application/vnd.github.raw+json',
    ['User-Agent'] = 'Setor-Mobile-Updater',
    ['X-GitHub-Api-Version'] = '2022-11-28'
}}

local function chat(cor, texto)
    if isSampAvailable() then sampAddChatMessage(cor .. '[SETOR UPDATE]: {FFFFFF}' .. tostring(texto), -1) end
end

local function body(res)
    return type(res) == 'table' and (res.text or res.body or res.data) or nil
end

local function get(url)
    for tentativa = 1, 3 do
        local separador = url:find('?', 1, true) and '&' or '?'
        local ok, res = pcall(requests.get, url .. separador .. 't=' .. tostring(os.time()) .. tostring(tentativa), GITHUB_OPTIONS)
        local conteudo = ok and body(res) or nil
        if conteudo and #conteudo > 0 then return tostring(conteudo) end
        wait(600)
    end
end

local function versaoDoScript(conteudo)
    return tostring(conteudo or ''):match("local%s+VERSION%s*=%s*['\"]([%d%.]+)['\"]")
end

local function maior(a, b)
    local aa, bb = {}, {}
    for n in tostring(a or ''):gmatch('%d+') do aa[#aa + 1] = tonumber(n) end
    for n in tostring(b or ''):gmatch('%d+') do bb[#bb + 1] = tonumber(n) end
    for i = 1, math.max(#aa, #bb) do
        if (aa[i] or 0) > (bb[i] or 0) then return true end
        if (aa[i] or 0) < (bb[i] or 0) then return false end
    end
    return false
end

local function scriptPath()
    local base = type(getWorkingDirectory) == 'function' and getWorkingDirectory() or '.'
    return base .. '/' .. SCRIPT_NAME
end

local function ler(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local c = f:read('*a'); f:close(); return c
end

local function gravar(path, conteudo)
    local f = io.open(path, 'w')
    if not f then return false end
    f:write(conteudo); f:close()
    return ler(path) == conteudo
end

local function instalar(forcar, silencioso)
    if atualizando then return chat('{FFFF00}', 'Atualizacao ja esta em andamento.') end
    atualizando = true
    lua_thread.create(function()
        local remoto = get(VERSION_URL)
        remoto = remoto and remoto:match('([%d%.]+)')
        local path, atual = scriptPath(), ler(scriptPath())
        local localVersion = versaoDoScript(atual)
        if not remoto then
            atualizando = false
            if not silencioso then chat('{FF5555}', 'Nao foi possivel consultar a versao.') end
            return
        end
        if not forcar and localVersion and not maior(remoto, localVersion) then
            atualizando = false
            if not silencioso then chat('{3EDC81}', 'Versao ' .. localVersion .. ' ja esta atualizada.') end
            return
        end
        local novo = get(SCRIPT_URL)
        if not novo or #novo < 10000 or versaoDoScript(novo) ~= remoto or not novo:find('SETOR SEGURANCA %- MOBILE') then
            atualizando = false return chat('{FF5555}', 'Download inconsistente. O arquivo atual foi preservado.')
        end
        local compilado = type(loadstring) ~= 'function' or loadstring(novo, '@SETOR_MOBILE.download')
        if not compilado then atualizando = false return chat('{FF5555}', 'A nova versao possui erro de sintaxe. Atualizacao cancelada.') end
        if atual and not gravar(path .. '.bak', atual) then
            atualizando = false return chat('{FF5555}', 'Nao foi possivel criar o backup.')
        end
        if not gravar(path .. '.download', novo) or not gravar(path, novo) then
            if atual then gravar(path, atual) end
            atualizando = false return chat('{FF5555}', 'Falha ao instalar; backup restaurado.')
        end
        atualizando = false
        chat('{3EDC81}', 'Atualizado para ' .. remoto .. '. Reinicie o jogo.')
    end)
end

local function mostrarVersoes()
    if atualizando then return chat('{FFFF00}', 'Atualizacao ja esta em andamento.') end
    atualizando = true
    lua_thread.create(function()
        local instalada = versaoDoScript(ler(scriptPath())) or 'desconhecida'
        chat('{48C6FF}', 'Versao mobile instalada: ' .. instalada)

        local remota = get(VERSION_URL)
        remota = remota and remota:match('([%d%.]+)') or nil
        atualizando = false

        if not remota then
            return chat('{FF5555}', 'Nao foi possivel consultar a versao publicada.')
        end

        chat('{48C6FF}', 'Versao disponivel no GitHub: ' .. remota)
        if instalada == 'desconhecida' or maior(remota, instalada) then
            chat('{FFFF00}', 'Nova versao disponivel. Use /setoratualizar.')
        else
            chat('{3EDC81}', 'Seu SETOR Mobile esta atualizado.')
        end
    end)
end

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand('setorversao', mostrarVersoes)
    sampRegisterChatCommand('setoratualizar', function() instalar(true) end)
    sampRegisterChatCommand('setorrollback', function()
        local path, backup = scriptPath(), ler(scriptPath() .. '.bak')
        if backup and gravar(path, backup) then chat('{3EDC81}', 'Backup restaurado. Reinicie o jogo.')
        else chat('{FF5555}', 'Backup valido nao encontrado.') end
    end)
    -- Verifica automaticamente ao iniciar. Se ja estiver atualizado, nao
    -- mostra mensagem; /setoratualizar continua disponivel para forcar.
    wait(5000)
    instalar(false, true)
    wait(-1)
end
