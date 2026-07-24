script_name("SETOR Updater")
script_author("Respected")
require "lib.moonloader"

local requests = require "requests"
local API_BASE = "https://api.github.com/repos/YagoBMF/setor-advanced/contents/SETOR/PC/"
local VERSAO_URL = API_BASE .. "versao.txt?ref=main"
local SCRIPT_URL = API_BASE .. "SETOR_SEG.lua?ref=main"
local VERSAO_RAW_URL = "https://raw.githubusercontent.com/YagoBMF/setor-advanced/main/SETOR/PC/versao.txt"
local SCRIPT_RAW_URL = "https://raw.githubusercontent.com/YagoBMF/setor-advanced/main/SETOR/PC/SETOR_SEG.lua"
local GITHUB_OPTIONS = {headers = {
    ["Accept"] = "application/vnd.github.raw+json",
    ["User-Agent"] = "Setor-PC-Updater",
    ["X-GitHub-Api-Version"] = "2022-11-28"
}}
local SCRIPT_PATH = getWorkingDirectory() .. "\\SETOR_SEG.lua"
local BACKUP_PATH = SCRIPT_PATH .. ".bak"
local TEMP_PATH = SCRIPT_PATH .. ".download"
local consultando = false

local function chat(texto, cor)
    if isSampAvailable() then sampAddChatMessage(texto, cor or -1) end
end

local function ler(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function escrever(path, data)
    local f = io.open(path, "wb")
    if not f then return false end
    local ok = f:write(data)
    f:flush()
    f:close()
    return ok ~= nil and ler(path) == data
end

local function corpo(res)
    if type(res) ~= "table" then return nil end
    return res.text or res.body or res.data
end

local function urlNova(url)
    local sep = url:find("?", 1, true) and "&" or "?"
    return url .. sep .. "setor_cache=" .. tostring(os.time()) .. tostring(math.random(1000, 9999))
end

local function baixar(urlApi, urlRaw)
    local fontes = {{urlApi, GITHUB_OPTIONS}, {urlRaw, nil}}
    for _, fonte in ipairs(fontes) do
        if type(fonte[1]) == "string" and fonte[1] ~= "" then
            for tentativa = 1, 3 do
                local ok, res
                if fonte[2] then
                    ok, res = pcall(requests.get, urlNova(fonte[1]), fonte[2])
                else
                    ok, res = pcall(requests.get, urlNova(fonte[1]))
                end
                local data = ok and corpo(res) or nil
                if type(data) == "string" and data ~= "" then return data end
                wait(700 * tentativa)
            end
        end
    end
    return nil
end

local function versaoDoCodigo(codigo)
    return tostring(codigo or ""):match('versao%s*=%s*"([%d%.]+)"')
end

local function comparar(a, b)
    local va, vb = {}, {}
    for n in tostring(a or ""):gmatch("%d+") do va[#va + 1] = tonumber(n) or 0 end
    for n in tostring(b or ""):gmatch("%d+") do vb[#vb + 1] = tonumber(n) or 0 end
    for i = 1, math.max(#va, #vb) do
        if (va[i] or 0) > (vb[i] or 0) then return 1 end
        if (va[i] or 0) < (vb[i] or 0) then return -1 end
    end
    return 0
end

local function validar(codigo, versaoEsperada)
    if type(codigo) ~= "string" or #codigo < 50000 then return false, "arquivo incompleto" end
    if codigo:find("<html", 1, true) or codigo:find("404: Not Found", 1, true) then
        return false, "resposta do GitHub invalida"
    end
    if not codigo:find("SETOR", 1, true) or not codigo:find("HZUpdaterPC", 1, true) then
        return false, "assinatura do projeto ausente"
    end
    local versaoCodigo = versaoDoCodigo(codigo)
    if not versaoCodigo or tostring(versaoCodigo) ~= tostring(versaoEsperada) then
        return false, "versao.txt e SETOR_SEG.lua nao correspondem"
    end
    local compilado, erro = loadstring(codigo, "@SETOR_SEG.download")
    if not compilado then return false, "erro de sintaxe: " .. tostring(erro) end
    return true
end

local function versaoInstalada()
    return versaoDoCodigo(ler(SCRIPT_PATH)) or "0.0"
end

local function restaurarBackup()
    local backup = ler(BACKUP_PATH)
    if not backup or #backup < 50000 then
        chat("{FF5555}[SETOR UPDATE]: Backup valido nao encontrado.")
        return false
    end
    if escrever(SCRIPT_PATH, backup) then
        chat("{00FF7F}[SETOR UPDATE]: Backup restaurado. Reinicie o GTA.")
        return true
    end
    chat("{FF5555}[SETOR UPDATE]: Nao foi possivel restaurar o backup.")
    return false
end

local function instalar(silencioso, forcar)
    if consultando then return chat("{FFFF00}[SETOR UPDATE]: Atualizacao ja em andamento.") end
    consultando = true
    lua_thread.create(function()
        if not silencioso then chat("{48C6FF}[SETOR UPDATE]: Consultando GitHub...") end
        local versaoTexto = baixar(VERSAO_URL, VERSAO_RAW_URL)
        local remota = versaoTexto and versaoTexto:match("([%d%.]+)") or nil
        local instalada = versaoInstalada()
        if not remota then
            consultando = false
            return chat("{FF5555}[SETOR UPDATE]: Falha ao consultar versao apos 3 tentativas.")
        end
        if not forcar and comparar(remota, instalada) <= 0 then
            consultando = false
            if not silencioso then chat("{00FF7F}[SETOR UPDATE]: Versao " .. instalada .. " ja esta atualizada.") end
            return
        end

        local novo = baixar(SCRIPT_URL, SCRIPT_RAW_URL)
        local valido, motivo = validar(novo, remota)
        if not valido then
            consultando = false
            return chat("{FF5555}[SETOR UPDATE]: Instalacao cancelada: " .. tostring(motivo) .. ".")
        end
        if not escrever(TEMP_PATH, novo) then
            consultando = false
            return chat("{FF5555}[SETOR UPDATE]: Falha ao validar arquivo temporario.")
        end

        local atual = ler(SCRIPT_PATH)
        if atual and #atual >= 50000 and not escrever(BACKUP_PATH, atual) then
            os.remove(TEMP_PATH)
            consultando = false
            return chat("{FF5555}[SETOR UPDATE]: Backup falhou; arquivo atual foi preservado.")
        end
        if not escrever(SCRIPT_PATH, novo) then
            if atual then escrever(SCRIPT_PATH, atual) end
            os.remove(TEMP_PATH)
            consultando = false
            return chat("{FF5555}[SETOR UPDATE]: Substituicao falhou; versao anterior restaurada.")
        end

        os.remove(TEMP_PATH)
        consultando = false
        chat("{00FF7F}[SETOR UPDATE]: Versao " .. remota .. " instalada e verificada. Reinicie o GTA.")
    end)
end

function main()
    while not isSampAvailable() do wait(200) end
    sampRegisterChatCommand("setorversao", function()
        chat("{48C6FF}[SETOR UPDATE]: Versao instalada: " .. versaoInstalada())
        instalar(false, false)
    end)
    sampRegisterChatCommand("setoratualizar", function() instalar(false, true) end)
    sampRegisterChatCommand("setorrollback", restaurarBackup)
    wait(7000)
    instalar(true, false)
    while true do wait(1000) end
end
