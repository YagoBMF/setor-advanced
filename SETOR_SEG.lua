
-- CORRECAO CRASH SPAWN: captura Nome/RG movida para fila segura fora do callback de rede.
-- ============================================================
-- PAINEL TV INTEGRADO (arquivo original: PainelTV(2).lua)
-- ============================================================
do
-- integrado: script_name removido
-- integrado: script_author removido
require "lib.moonloader"
local imgui = require "imgui"
-- O /mods usa mimgui quando a biblioteca estiver instalada. O pcall mantem
-- o restante do mod funcionando normalmente em PCs que ainda nao a possuem.
_G.HZMimguiOk, _G.HZMimgui = pcall(require, "mimgui")
local encoding = require "encoding"
encoding.default = "CP1252"
u8 = encoding.UTF8
local sampev = require "lib.samp.events"

-- >>> (Ícone ⚙) <<<
local ffi = require "ffi"
local ICON_GEAR = "\226\154\153" -- ⚙ em UTF-8 (evita bug de encoding)

-- >>> (Hotkeys) <<<
local vkeys = require "vkeys"

-- >>> Persistencia da posicao do Painel TV <<<
local json_paineltv = require "dkjson"
local PAINELTV_CONFIG_PATH = getWorkingDirectory() .. "\\config\\hz_setor_config.json"
local painelTvX, painelTvY = nil, nil
local painelTvPosCarregada = false
local ultimoSalvamentoPainelTv = 0

local function carregarPosPainelTv()
    local f = io.open(PAINELTV_CONFIG_PATH, "r")
    if not f then return end

    local content = f:read("*a")
    f:close()

    local data = json_paineltv.decode(content)
    if type(data) == "table" then
        painelTvX = tonumber(data.painelTvX)
        painelTvY = tonumber(data.painelTvY)
    end
end

local function salvarPosPainelTv(forcar)
    if painelTvX == nil or painelTvY == nil then return end
    if not forcar and os.clock and os.clock() - ultimoSalvamentoPainelTv < 0.5 then
        return
    end

    ultimoSalvamentoPainelTv = os.clock and os.clock() or 0

    local data = {}
    local f = io.open(PAINELTV_CONFIG_PATH, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local decoded = json_paineltv.decode(content)
        if type(decoded) == "table" then data = decoded end
    end

    data.painelTvX = math.floor(tonumber(painelTvX) or 0)
    data.painelTvY = math.floor(tonumber(painelTvY) or 0)

    f = io.open(PAINELTV_CONFIG_PATH, "w+")
    if f then
        f:write(json_paineltv.encode(data, { indent = true }))
        f:close()
    end
end

-- Ponte segura para o sistema principal salvar/carregar a posicao do Painel TV.
-- Necessario porque painelTvX/Y sao locais deste modulo.
_G.PainelTVGetSavedPos = function()
    if painelTvX == nil or painelTvY == nil then return nil, nil end
    return math.floor(tonumber(painelTvX) or 20), math.floor(tonumber(painelTvY) or 220)
end

_G.PainelTVSetSavedPos = function(x, y)
    if tonumber(x) ~= nil and tonumber(y) ~= nil then
        painelTvX = math.floor(tonumber(x))
        painelTvY = math.floor(tonumber(y))
        painelTvPosCarregada = false
    end
end

-- ======================
-- ESTADO E VARIAVEIS
-- ======================
local janela = imgui.ImBool(false)
local menuAtual = "principal"
local menuAnterior = "principal"

-- PADRÃO: painel já vem configurado no modo 2 automaticamente
local modoPainel = 2
local modoConfigurado = true

local idTelado, rgTelado, nickTelado, levelTelado = "---", "---", "---", "---"
local ultimoIdTelado = "---"

-- Avisos /AC isolados em estado global para evitar exceder limites locais do Lua 5.1.
_G.HZAvisosAC = _G.HZAvisosAC or {
    aguardandoReport = false,
    prazoReport = 0,
    solicitouLista = false,
    prazoLista = 0,
    dialogReportId = -1,
    ultimaChave = "",
    ultimoTempo = 0
}

function _G.HZAvisosAC.enviar(mensagem, atraso)
    mensagem = tostring(mensagem or "")
    if mensagem == "" then return end
    lua_thread.create(function()
        wait(tonumber(atraso) or 400)
        sampSendChat("/ac " .. mensagem)
    end)
end

function _G.HZAvisosAC.marcarReport()
    -- Abrir /reports nao significa que um report foi selecionado.
    -- A autorizacao do /ac so acontece na resposta real do dialogo.
    _G.HZAvisosAC.aguardandoReport = false
    _G.HZAvisosAC.prazoReport = 0
    _G.HZAvisosAC.solicitouLista = true
    _G.HZAvisosAC.prazoLista = (os.clock and os.clock() or 0) + 8
    _G.HZAvisosAC.dialogReportId = -1
end

function _G.HZAvisosAC.cancelarReport()
    _G.HZAvisosAC.aguardandoReport = false
    _G.HZAvisosAC.prazoReport = 0
    _G.HZAvisosAC.solicitouLista = false
    _G.HZAvisosAC.prazoLista = 0
    _G.HZAvisosAC.dialogReportId = -1
end

function _G.HZAvisosAC.registrarDialogo(id, titulo, texto)
    if not _G.HZAvisosAC.solicitouLista then return end
    local agora = os.clock and os.clock() or 0
    if agora > (_G.HZAvisosAC.prazoLista or 0) then
        _G.HZAvisosAC.cancelarReport()
        return
    end
    local conteudo = (tostring(titulo or "") .. " " .. tostring(texto or "")):lower()
    if conteudo:find("report", 1, true) then
        _G.HZAvisosAC.dialogReportId = tonumber(id) or -1
    end
end

function _G.HZAvisosAC.responderDialogo(id, botao)
    if tonumber(id) ~= tonumber(_G.HZAvisosAC.dialogReportId) then return end
    local selecionou = tonumber(botao) == 1
    _G.HZAvisosAC.solicitouLista = false
    _G.HZAvisosAC.prazoLista = 0
    _G.HZAvisosAC.dialogReportId = -1
    if selecionou then
        _G.HZAvisosAC.aguardandoReport = true
        -- Tempo apenas para o servidor iniciar a telagem selecionada.
        _G.HZAvisosAC.prazoReport = (os.clock and os.clock() or 0) + 8
    else
        _G.HZAvisosAC.cancelarReport()
    end
end

function _G.HZAvisosAC.confirmarReport(nick, id)
    if not _G.HZAvisosAC.aguardandoReport then return end
    local agora = os.clock and os.clock() or 0
    if agora > (_G.HZAvisosAC.prazoReport or 0) then
        _G.HZAvisosAC.aguardandoReport = false
        return
    end
    nick = tostring(nick or "")
    if nick == "" or nick == "---" then return end
    local chave = nick:lower() .. "|" .. tostring(id or "")
    if chave == _G.HZAvisosAC.ultimaChave and agora - (_G.HZAvisosAC.ultimoTempo or 0) < 6 then
        _G.HZAvisosAC.aguardandoReport = false
        return
    end
    _G.HZAvisosAC.ultimaChave = chave
    _G.HZAvisosAC.ultimoTempo = agora
    _G.HZAvisosAC.aguardandoReport = false
    _G.HZAvisosAC.enviar("Estou telando o Player " .. nick, 450)
end

local valorStatus = imgui.ImInt(100)
local tempoPunicao = imgui.ImInt(0)
local pesquisa = imgui.ImBuffer(15)
local motivoSel = ""
local comandoBase = ""
local labelPunicao = ""
local bufMotivoManual = imgui.ImBuffer(50)
local alturaJanela = 100

-- Relogio do servidor (capturado do TextDraw do Horizonte)
local relogioServidor = ""
local ultimoRelogioServidor = 0

local function paineltv_limpar_textdraw(text)
    return tostring(text or "")
        :gsub("{%x%x%x%x%x%x}", "")
        :gsub("~.-~", "")
        :gsub("_", " ")
        :gsub("%s+", " ")
        :match("^%s*(.-)%s*$")
end

local function paineltv_tentar_capturar_relogio(text)
    local clean = paineltv_limpar_textdraw(text)
    if clean == "" then return end

    -- Formato do HZ: Sabado, 4 Jul 2026, 18:41:50
    if clean:match("%d%d?:%d%d:%d%d") and clean:find(",") and clean:match("%d%d%d%d") then
        local lower = clean:lower()
        local temMes = lower:match("jan") or lower:match("fev") or lower:match("mar") or lower:match("abr") or lower:match("mai") or lower:match("jun") or lower:match("jul") or lower:match("ago") or lower:match("set") or lower:match("out") or lower:match("nov") or lower:match("dez")
        if temMes then
            relogioServidor = clean
            ultimoRelogioServidor = os.clock and os.clock() or 0
        end
    end
end

-- Auto abrir painel quando começar a telar alguém
local painelAutoAbrir = true
local painelAbertoPorAuto = false

-- Controle de cursor (configuração)
local cursorAtivo = false
local function setCursor(state)
    cursorAtivo = state and true or false
    imgui.ShowCursor = cursorAtivo
end

-- ======================
-- CONFIGURAÇÕES (NOVAS)
-- ======================

-- Preferencias úteis do Painel TV (persistidas em hz_setor_config.json)
local fecharPainelSempreTvoff = true
-- Comportamentos internos fixos: não precisam aparecer na configuração.
local voltarPrincipalAoTrocarTelado = true
local limparMotivoTempoAoTrocarTelado = true
local confirmarBanPermanente2x = true
local aguardandoConfirmBanPerm = false
local bloquearAcoesSemIdTelado = true

-- Recursos antigos removidos da configuração e mantidos desligados.
local hotkeyF6Painel = false
local hotkeyF7TvOff  = false
local hotkeyF8Cursor = false
local hotkeyAvisarStaffAtiva = false
local hotkeyAvisarStaffIndice = 9
local hotkeysAvisarStaff = {
    { nome = "F1",  vk = vkeys.VK_F1  },
    { nome = "F2",  vk = vkeys.VK_F2  },
    { nome = "F3",  vk = vkeys.VK_F3  },
    { nome = "F4",  vk = vkeys.VK_F4  },
    { nome = "F5",  vk = vkeys.VK_F5  },
    { nome = "F6",  vk = vkeys.VK_F6  },
    { nome = "F7",  vk = vkeys.VK_F7  },
    { nome = "F8",  vk = vkeys.VK_F8  },
    { nome = "F9",  vk = vkeys.VK_F9  },
    { nome = "F10", vk = vkeys.VK_F10 },
    { nome = "F11", vk = vkeys.VK_F11 },
    { nome = "F12", vk = vkeys.VK_F12 }
}

local function normalizarIndiceHotkeyAviso(indice)
    indice = math.floor(tonumber(indice) or 9)
    if indice < 1 then indice = #hotkeysAvisarStaff end
    if indice > #hotkeysAvisarStaff then indice = 1 end
    return indice
end

-- Mantido internamente para preservar dimensões já validadas.
local modoCompacto = false

local function carregarPreferenciasPainelTv()
    local f = io.open(PAINELTV_CONFIG_PATH, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()
    local data = json_paineltv.decode(content)
    if type(data) ~= "table" then return end

    if data.painelTvAutoAbrir ~= nil then painelAutoAbrir = data.painelTvAutoAbrir == true end
    if data.painelTvFecharTvoff ~= nil then fecharPainelSempreTvoff = data.painelTvFecharTvoff == true end
    if data.painelTvConfirmarBan2x ~= nil then confirmarBanPermanente2x = data.painelTvConfirmarBan2x == true end
    if data.painelTvBloquearOffline ~= nil then bloquearAcoesSemIdTelado = data.painelTvBloquearOffline == true end

    if data.painelTvAvisarStaffAtivo ~= nil then hotkeyAvisarStaffAtiva = data.painelTvAvisarStaffAtivo == true end
    hotkeyAvisarStaffIndice = normalizarIndiceHotkeyAviso(data.painelTvAvisarStaffTecla)

    voltarPrincipalAoTrocarTelado = true
    limparMotivoTempoAoTrocarTelado = true
    hotkeyF6Painel = false
    hotkeyF7TvOff = false
    hotkeyF8Cursor = false
    if tonumber(data.painelTvModoPunicao) == 1 or tonumber(data.painelTvModoPunicao) == 2 then
        modoPainel = tonumber(data.painelTvModoPunicao)
    end
end

local function salvarPreferenciasPainelTv()
    local data = {}
    local f = io.open(PAINELTV_CONFIG_PATH, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local decoded = json_paineltv.decode(content)
        if type(decoded) == "table" then data = decoded end
    end

    data.painelTvAutoAbrir = painelAutoAbrir == true
    data.painelTvFecharTvoff = fecharPainelSempreTvoff == true
    data.painelTvConfirmarBan2x = confirmarBanPermanente2x == true
    data.painelTvBloquearOffline = bloquearAcoesSemIdTelado == true
    data.painelTvModoPunicao = modoPainel

    -- Limpa opções antigas que não existem mais na interface.
    data.painelTvVoltarPrincipal = nil
    data.painelTvLimparCampos = nil
    data.painelTvHotkeyF6 = nil
    data.painelTvHotkeyF7 = nil
    data.painelTvHotkeyF8 = nil
    data.painelTvAvisarStaffAtivo = hotkeyAvisarStaffAtiva == true
    data.painelTvAvisarStaffTecla = normalizarIndiceHotkeyAviso(hotkeyAvisarStaffIndice)

    if painelTvX ~= nil and painelTvY ~= nil then
        data.painelTvX = math.floor(tonumber(painelTvX) or 20)
        data.painelTvY = math.floor(tonumber(painelTvY) or 220)
    end

    f = io.open(PAINELTV_CONFIG_PATH, "w+")
    if f then
        f:write(json_paineltv.encode(data, { indent = true }))
        f:close()
    end
end

local function idValido()
    local id = tonumber(idTelado)
    if not id then return false end

    if type(sampIsPlayerConnected) == "function" and not sampIsPlayerConnected(id) then
        return false
    end

    -- Evita mostrar ON caso o ID tenha sido reutilizado por outro jogador.
    if type(sampGetPlayerNickname) == "function" and nickTelado and nickTelado ~= "---" then
        local nickAtual = sampGetPlayerNickname(id)
        if nickAtual and tostring(nickAtual):lower() ~= tostring(nickTelado):lower() then
            return false
        end
    end

    return true
end

local function podeExecutarAcao()
    if not bloquearAcoesSemIdTelado then return true end
    if idValido() then return true end
    sampAddChatMessage("{FF0000}[Setor] O jogador telado nao esta mais online.", -1)
    return false
end

local function hotkeyPermitido()
    if type(sampIsChatInputActive) == "function" and sampIsChatInputActive() then return false end
    if type(sampIsDialogActive) == "function" and sampIsDialogActive() then return false end
    if type(sampIsScoreboardOpen) == "function" and sampIsScoreboardOpen() then return false end
    return true
end

local function avisarStaffJogadorTelado()
    if not idValido() or not nickTelado or nickTelado == "" or nickTelado == "---" then
        sampAddChatMessage("{FF0000}[Setor] Nenhum jogador valido esta sendo telado.", -1)
        return
    end

    -- Excecao autorizada: somente a tecla configuravel do Painel TV pode
    -- avisar manualmente no /ac sem ter vindo de uma selecao do /reports.
    local agora = os.clock and os.clock() or 0
    local chave = tostring(nickTelado):lower() .. "|" .. tostring(idTelado)
    if chave == tostring(_G.HZAvisosAC.ultimaChave or "")
        and agora - tonumber(_G.HZAvisosAC.ultimoTempo or 0) < 3 then
        sampAddChatMessage("{FFFF00}[Setor] Aviso /ac enviado recentemente.", -1)
        return
    end

    _G.HZAvisosAC.ultimaChave = chave
    _G.HZAvisosAC.ultimoTempo = agora
    _G.HZAvisosAC.cancelarReport()
    _G.HZAvisosAC.enviar("Estou telando o Player " .. tostring(nickTelado), 150)
end

-- Tabela de referência para o Modo 2 (Auto-preencher tempo ao digitar)
local tabelaTempos = {
    ["ANTI RP"] = 250, ["DM"] = 250, ["VDM"] = 250, ["RDM"] = 250, ["NRA"] = 80,
    ["JBL HP"] = 50, ["DB"] = 250, ["MG"] = 250, ["PG"] = 250, ["KOS"] = 250
}

-- ======================
-- LISTAS DE MOTIVOS
-- ======================
local motivosCadeia = { {"NRA", 80}, {"JBL HP", 50}, {"JBL Spawn", 50}, {"ASM", 80}, {"Loja Solo", 150}, {"Loja em dois", 150}, {"Assalto Banco < 5", 150}, {"DB", 250}, {"DM", 250}, {"Acao Safe", 250}, {"Acao Desmanche", 250}, {"AB Desmanche", 250}, {"KOS", 250}, {"MG", 250}, {"PG", 250}, {"TK", 250}, {"VDM", 250}, {"HK", 250}, {"PTR Solo", 250}, {"Sniper Rua", 250}, {"Anti-RP", 250}, {"Invasao s/ marcar", 250}, {"NS", 250}, {"RDM", 250}, {"RK", 250}, {"Correu interior", 250}, {"Corrupcao", 300}, {"Dark RP", 300} }
local motivosMute   = { {"Cobrancas ADM", 10}, {"Farpa media", 5}, {"Bullying", 5}, {"Flood chat", 3}, {"Baixo calao", 5}, {"Preconceito", 15}, {"Conteudo sexual", 15}, {"MUC /AN", 1}, {"MUC /ANORG", 1}, {"MUC Atendimento", 2} }
local motivosBan    = { {"CL", 5}, {"Handling", 5}, {"Animacao Vantajosa", 5}, {"Anti-RP extremo", 15}, {"Cortando animacao", 15}, {"Cheat", 0}, {"Ofensa Staff", 0}, {"Ofensa Servidor", 0}, {"Comercio Ilegal", 0}, {"Nick Improprio", 0} }
local motivosKick   = { {"Remover acc", 0}, {"JBL SAFE 1/2", 0}, {"JBL HP 1/2", 0}, {"RT", 0}, {"Relogar", 0} }

-- ======================
-- COMANDOS
-- ======================
local function paineltv_main()
    repeat wait(100) until isSampAvailable()

    carregarPosPainelTv()
    carregarPreferenciasPainelTv()

    -- Ativar/desativar cursor manualmente
    sampRegisterChatCommand("kj", function()
        if _G.HZModuloAtivo and not _G.HZModuloAtivo("painel_tv") then return end
        setCursor(not cursorAtivo)
        sampAddChatMessage("{FFFF00}[Setor] Cursor alternado.", -1)
    end)

    -- Toggle manual do painel (opcional). Cursor sempre OFF ao abrir/fechar.
    sampRegisterChatCommand("tvz", function()
        if _G.HZModuloAtivo and not _G.HZModuloAtivo("painel_tv") then
            sampAddChatMessage("{FF6B6B}[MODS] Painel TV esta desligado. Use /mods para ativar.", -1)
            return
        end
        janela.v = not janela.v
        menuAtual = "principal"
        aguardandoConfirmBanPerm = false
        setCursor(false)
        painelAbertoPorAuto = false
    end)

    while true do
        wait(0)

        -- Hotkeys (opcionais)
        if hotkeyPermitido() then
            if hotkeyF6Painel and isKeyJustPressed(vkeys.VK_F6) then
                janela.v = not janela.v
                menuAtual = "principal"
                aguardandoConfirmBanPerm = false
                setCursor(false)
                painelAbertoPorAuto = false
            end
            if hotkeyF7TvOff and isKeyJustPressed(vkeys.VK_F7) then
                sampSendChat("/tvoff")
            end
            if hotkeyF8Cursor and isKeyJustPressed(vkeys.VK_F8) then
                setCursor(not cursorAtivo)
            end

            if hotkeyAvisarStaffAtiva then
                hotkeyAvisarStaffIndice = normalizarIndiceHotkeyAviso(hotkeyAvisarStaffIndice)
                local teclaAviso = hotkeysAvisarStaff[hotkeyAvisarStaffIndice]
                if teclaAviso and isKeyJustPressed(teclaAviso.vk) then
                    avisarStaffJogadorTelado()
                end
            end
        end

        if janela.v then imgui.Process = true end
    end
end

-- ======================
-- INTERFACE
-- ======================
local fontIcons = nil

local function paineltv_OnInitialize()
    local io = imgui.GetIO()

    -- Range incluindo U+2699 (⚙) e símbolos comuns
    local ranges = ffi.new("ImWchar[3]", 0x0020, 0x2FFF, 0)

    fontIcons = io.Fonts:AddFontFromFileTTF("C:\\Windows\\Fonts\\seguisym.ttf", 16.0, nil, ranges)
end

local function paineltv_OnDrawFrame()
    if not janela.v then return end

    local style = imgui.GetStyle()
    style.WindowRounding = 7.0
    style.FrameRounding = 5.0
    style.ChildWindowRounding = 7.0
    style.WindowPadding = imgui.ImVec2(10, 9)
    style.ItemSpacing = imgui.ImVec2(6, 5)
    style.FramePadding = imgui.ImVec2(8, 4)

    local C_BG       = imgui.ImVec4(0.025, 0.035, 0.050, 0.94)
    local C_PANEL    = imgui.ImVec4(0.045, 0.065, 0.090, 0.95)
    local C_CARD     = imgui.ImVec4(0.055, 0.080, 0.115, 0.96)
    local C_LINE     = imgui.ImVec4(0.120, 0.650, 0.920, 0.95)
    local C_PRIMARY  = imgui.ImVec4(0.005, 0.435, 0.665, 0.95)
    local C_HOVER    = imgui.ImVec4(0.165, 0.660, 0.910, 1.00)
    local C_ACTIVE   = imgui.ImVec4(0.020, 0.350, 0.540, 1.00)
    local C_TEXT     = imgui.ImVec4(0.930, 0.970, 1.000, 1.00)
    local C_MUTED    = imgui.ImVec4(0.620, 0.700, 0.790, 1.00)
    local C_DANGER   = imgui.ImVec4(0.720, 0.085, 0.115, 0.94)
    local C_DANGER_H = imgui.ImVec4(0.950, 0.130, 0.170, 1.00)
    local C_WARN     = imgui.ImVec4(0.910, 0.560, 0.110, 0.95)
    local C_GREEN    = imgui.ImVec4(0.200, 0.850, 0.470, 1.00)
    local C_BLUE     = imgui.ImVec4(0.020, 0.330, 0.720, 0.95)
    local C_BLUE_H   = imgui.ImVec4(0.110, 0.530, 0.950, 1.00)
    local C_DARKBTN  = imgui.ImVec4(0.060, 0.080, 0.110, 0.95)

    style.Colors[imgui.Col.WindowBg] = C_BG
    style.Colors[imgui.Col.ChildWindowBg] = C_PANEL
    style.Colors[imgui.Col.Border] = imgui.ImVec4(0.060, 0.520, 0.760, 0.55)
    style.Colors[imgui.Col.Separator] = C_LINE
    style.Colors[imgui.Col.Text] = C_TEXT
    style.Colors[imgui.Col.FrameBg] = imgui.ImVec4(0.045, 0.060, 0.085, 0.98)
    style.Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.070, 0.140, 0.190, 0.95)
    style.Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.020, 0.290, 0.430, 0.95)
    style.Colors[imgui.Col.Button] = C_PRIMARY
    style.Colors[imgui.Col.ButtonHovered] = C_HOVER
    style.Colors[imgui.Col.ButtonActive] = C_ACTIVE

    local function pushBtn(c, h, a)
        imgui.PushStyleColor(imgui.Col.Button, c)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, h or C_HOVER)
        imgui.PushStyleColor(imgui.Col.ButtonActive, a or C_ACTIVE)
    end

    local function popBtn()
        imgui.PopStyleColor(3)
    end

    local function hzButton(label, size, c, h, a)
        pushBtn(c or C_PRIMARY, h or C_HOVER, a or C_ACTIVE)
        local ok = imgui.Button(label, size)
        popBtn()
        return ok
    end

    local function sectionTitle(txt)
        imgui.Spacing()
        imgui.Separator()
        imgui.TextColored(C_LINE, u8(txt))
    end

    local function fitWindowHeight()
        if menuAtual == "principal" then
            if _G.HZMonitorEtapa1 and _G.HZMonitorEtapa1.motivoAberto and _G.HZMonitorEtapa1.motivoAberto.v then return 472 end
            return 397
        end
        if menuAtual == "config" then return 385 end
        if menuAtual == "categorias" then return 295 end
        if menuAtual == "confirmar" then return 335 end
        if tostring(menuAtual):find("lista_") then return 330 end
        return alturaJanela
    end

    imgui.SetNextWindowSize(imgui.ImVec2(340, fitWindowHeight()), imgui.Cond.Always)
    if not painelTvPosCarregada then
        if painelTvX ~= nil and painelTvY ~= nil then
            imgui.SetNextWindowPos(imgui.ImVec2(painelTvX, painelTvY), imgui.Cond.Always)
        end
        painelTvPosCarregada = true
    end

    imgui.Begin(u8"Setor Seguranca", janela, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar)

    do
        local pos = imgui.GetWindowPos()
        if pos and (painelTvX == nil or painelTvY == nil or math.abs((tonumber(painelTvX) or 0) - pos.x) > 1 or math.abs((tonumber(painelTvY) or 0) - pos.y) > 1) then
            painelTvX = math.floor(pos.x)
            painelTvY = math.floor(pos.y)
            salvarPosPainelTv(false)
        end
    end

    local H_BTN_MAIN = modoCompacto and 30 or 34
    local H_CHILD_LIST = modoCompacto and 142 or 165

    -- Topbar fixa, compacta, sem scroll
    imgui.BeginChild("##hz_topbar", imgui.ImVec2(0, 38), true)
    imgui.SetCursorPosY(9)
    imgui.TextColored(C_LINE, u8"SETOR SEGURANCA")
    imgui.SameLine()
    imgui.TextColored(C_MUTED, u8" | TV PANEL")

    local btnW, btnH = 28, 24
    local rightX = imgui.GetWindowWidth() - (btnW * 2) - 18
    if rightX < 0 then rightX = 0 end
    imgui.SameLine()
    imgui.SetCursorPosX(rightX)
    imgui.SetCursorPosY(7)

    if fontIcons ~= nil then imgui.PushFont(fontIcons) end
    if hzButton(ICON_GEAR, imgui.ImVec2(btnW, btnH), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
        if menuAtual ~= "config" then
            menuAnterior = menuAtual
            menuAtual = "config"
            aguardandoConfirmBanPerm = false
        else
            menuAtual = menuAnterior
            aguardandoConfirmBanPerm = false
        end
    end
    if fontIcons ~= nil then imgui.PopFont() end

    imgui.SameLine()
    if hzButton(u8"X", imgui.ImVec2(btnW, btnH), imgui.ImVec4(0.100, 0.040, 0.055, 0.95), C_DANGER, C_DANGER_H) then
        salvarPosPainelTv(true)
        janela.v = false
        menuAtual = "principal"
        aguardandoConfirmBanPerm = false
        painelAbertoPorAuto = false
        setCursor(false)
    end
    imgui.EndChild()

    if menuAtual == "config" then
        imgui.TextColored(C_LINE, u8"CONFIGURACOES")
        imgui.TextColored(C_MUTED, u8"Ajustes do painel")
        imgui.Separator()

        imgui.BeginChild("##hz_config", imgui.ImVec2(0, 275), true)

        imgui.TextColored(C_LINE, u8"COMPORTAMENTO")
        imgui.Spacing()

        do
            local b = imgui.ImBool(painelAutoAbrir)
            if imgui.Checkbox(u8"Abrir painel ao telar", b) then
                painelAutoAbrir = b.v
                salvarPreferenciasPainelTv()
            end
        end

        do
            local b = imgui.ImBool(fecharPainelSempreTvoff)
            if imgui.Checkbox(u8"Fechar painel ao /tvoff", b) then
                fecharPainelSempreTvoff = b.v
                salvarPreferenciasPainelTv()
            end
        end

        do
            local b = imgui.ImBool(bloquearAcoesSemIdTelado)
            if imgui.Checkbox(u8"Bloquear acoes se o jogador estiver offline", b) then
                bloquearAcoesSemIdTelado = b.v
                salvarPreferenciasPainelTv()
            end
        end

        do
            local b = imgui.ImBool(confirmarBanPermanente2x)
            if imgui.Checkbox(u8"Confirmar duas vezes Ban permanente", b) then
                confirmarBanPermanente2x = b.v
                salvarPreferenciasPainelTv()
            end
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.TextColored(C_LINE, u8"AVISO STAFF")

        do
            local b = imgui.ImBool(hotkeyAvisarStaffAtiva)
            if imgui.Checkbox(u8"Avisar qual jogador estou telando", b) then
                hotkeyAvisarStaffAtiva = b.v
                salvarPreferenciasPainelTv()
            end
        end

        hotkeyAvisarStaffIndice = normalizarIndiceHotkeyAviso(hotkeyAvisarStaffIndice)
        if hzButton(u8"<", imgui.ImVec2(38,28), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
            hotkeyAvisarStaffIndice = normalizarIndiceHotkeyAviso(hotkeyAvisarStaffIndice-1)
            salvarPreferenciasPainelTv()
        end
        imgui.SameLine()
        hzButton(u8("Tecla: "..hotkeysAvisarStaff[hotkeyAvisarStaffIndice].nome), imgui.ImVec2(190,28), C_CARD, C_HOVER, C_ACTIVE)
        imgui.SameLine()
        if hzButton(u8">", imgui.ImVec2(-1,28), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
            hotkeyAvisarStaffIndice = normalizarIndiceHotkeyAviso(hotkeyAvisarStaffIndice+1)
            salvarPreferenciasPainelTv()
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.TextColored(C_LINE, u8"PUNICOES")
        imgui.Spacing()

        if imgui.RadioButton(u8"Lista de motivos", modoPainel == 1) then
            modoPainel = 1
            modoConfigurado = true
            salvarPreferenciasPainelTv()
        end

        if imgui.RadioButton(u8"Motivo manual", modoPainel == 2) then
            modoPainel = 2
            modoConfigurado = true
            salvarPreferenciasPainelTv()
        end

        imgui.TextColored(C_MUTED, u8"A escolha fica salva automaticamente.")
        imgui.EndChild()

        if hzButton(u8"VOLTAR", imgui.ImVec2(-1, 30), C_PRIMARY, C_HOVER, C_ACTIVE) then
            menuAtual = menuAnterior
            aguardandoConfirmBanPerm = false
        end

    elseif menuAtual == "principal" then
        -- Card compacto do jogador em 2 linhas
        imgui.BeginChild("##hz_player_card", imgui.ImVec2(0, 62), true)
        imgui.SetCursorPosY(9)

        -- Linha 1: NICK à esquerda | ONLINE/OFFLINE à direita
        imgui.TextColored(C_LINE, u8"NICK:")
        imgui.SameLine()
        imgui.TextColored(C_TEXT, u8(nickTelado))

        imgui.SameLine()
        local jogadorOnline = idValido()
        local statusTxt = jogadorOnline and "ON" or "OFF"
        local statusColor = jogadorOnline and C_GREEN or C_DANGER_H
        local xStatus = imgui.GetWindowWidth() - imgui.CalcTextSize(u8(statusTxt)).x - 14
        if xStatus > imgui.GetCursorPosX() then imgui.SetCursorPosX(xStatus) end
        imgui.TextColored(statusColor, u8(statusTxt))

        -- Linha 2: ID/RG à esquerda | TV OFF à direita
        imgui.TextColored(C_LINE, u8"ID:")
        imgui.SameLine()
        imgui.TextColored(C_TEXT, u8(idTelado))
        imgui.SameLine()
        imgui.TextColored(C_MUTED, u8" | ")
        imgui.SameLine()
        imgui.TextColored(C_LINE, u8"RG:")
        imgui.SameLine()
        imgui.TextColored(C_TEXT, u8(rgTelado))
        imgui.SameLine()
        imgui.TextColored(C_MUTED, u8" | ")
        imgui.SameLine()
        imgui.TextColored(C_LINE, u8"LEVEL:")
        imgui.SameLine()
        imgui.TextColored(C_TEXT, u8(levelTelado))

        imgui.SameLine()
        local xTv = imgui.GetWindowWidth() - 92
        if xTv > imgui.GetCursorPosX() then imgui.SetCursorPosX(xTv) end
        if hzButton(u8"TV OFF", imgui.ImVec2(76, 24), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
            sampSendChat("/tvoff")
        end
        imgui.EndChild()

        sectionTitle("ACOES RAPIDAS")
        if hzButton(u8"PUNICAO", imgui.ImVec2(-1, 36), C_DANGER, C_DANGER_H, C_DANGER) then menuAtual = "categorias" end
        if hzButton(u8"PRENDER ARMAS", imgui.ImVec2(-1, 36), imgui.ImVec4(0.520, 0.085, 0.090, 0.88), C_DANGER_H, C_DANGER) then
            if podeExecutarAcao() then sampSendChat("/prenderarmas " .. rgTelado) end
        end
        if hzButton(u8"CHECAR JOGADOR", imgui.ImVec2(-1, 36), C_PRIMARY, C_HOVER, C_ACTIVE) then
            if podeExecutarAcao() then sampSendChat("/checar " .. rgTelado) end
        end
        -- Monitoramento discreto por caixa de selecao.
        if _G.HZMonitorEtapa1 then
            _G.HZMonitorEtapa1.prepararCheckbox(rgTelado, nickTelado)
            if imgui.Checkbox(u8"Em monitoramento", _G.HZMonitorEtapa1.checkbox) then
                _G.HZMonitorEtapa1.alterarCheckbox(rgTelado, nickTelado)
            end

            if _G.HZMonitorEtapa1.motivoAberto and _G.HZMonitorEtapa1.motivoAberto.v then
                imgui.PushItemWidth(-1)
                imgui.InputText(u8"##motivo_monitoramento", _G.HZMonitorEtapa1.motivoBuffer)
                imgui.PopItemWidth()
                imgui.TextColored(C_MUTED, u8"Informe o motivo do monitoramento")

                if hzButton(u8"SALVAR MONITORAMENTO", imgui.ImVec2(205, 30), C_BLUE, C_BLUE_H, C_BLUE) then
                    _G.HZMonitorEtapa1.salvarMotivoPainel()
                end
                imgui.SameLine()
                if hzButton(u8"CANCELAR", imgui.ImVec2(-1, 30), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
                    _G.HZMonitorEtapa1.cancelarMotivoPainel()
                end
            end
        end

        sectionTitle("VIDA / COLETE")
        imgui.BeginChild("##hz_status", imgui.ImVec2(0, 58), true)
        if hzButton(u8"-", imgui.ImVec2(36, 30), C_BLUE, C_BLUE_H, C_BLUE) then
            valorStatus.v = math.max(0, valorStatus.v - 10)
        end
        imgui.SameLine()
        imgui.PushItemWidth(54)
        imgui.InputInt("##val", valorStatus, 0, 0)
        imgui.PopItemWidth()
        imgui.SameLine(0, 2)
        if hzButton(u8"+", imgui.ImVec2(36, 30), C_BLUE, C_BLUE_H, C_BLUE) then
            valorStatus.v = math.min(999, valorStatus.v + 10)
        end
        imgui.SameLine()
        if hzButton(u8"VIDA", imgui.ImVec2(72, 30), C_DANGER, C_DANGER_H, C_DANGER) then
            if podeExecutarAcao() then sampSendChat("/setvida " .. rgTelado .. " " .. valorStatus.v) end
        end
        imgui.SameLine()
        if hzButton(u8"COLETE", imgui.ImVec2(82, 30), C_BLUE, C_BLUE_H, C_BLUE) then
            if podeExecutarAcao() then sampSendChat("/setcolete " .. rgTelado .. " " .. valorStatus.v) end
        end
        imgui.EndChild()

        -- Relogio discreto no rodape do Painel TV
        local relogioTxt = relogioServidor
        if relogioTxt == "" then
            relogioTxt = os.date("%d/%m/%Y, %H:%M:%S")
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.BeginChild("##hz_relogio_tv", imgui.ImVec2(0, 20), false)
        local txtSize = imgui.CalcTextSize(u8(relogioTxt))
        local posXRelogio = (imgui.GetWindowWidth() - txtSize.x) / 2
        if posXRelogio < 0 then posXRelogio = 0 end
        imgui.SetCursorPosX(posXRelogio)
        imgui.SetCursorPosY(2)
        imgui.TextColored(C_MUTED, u8(relogioTxt))
        imgui.EndChild()

    elseif menuAtual == "categorias" then
        imgui.TextColored(C_LINE, u8"PUNICOES")
        imgui.TextColored(C_MUTED, u8"Selecione o tipo de acao")
        imgui.Separator()
        local cats = {
            {"CADEIA", "lista_cadeia", "/punicao", "CADEIA"},
            {"BANIMENTO", "lista_ban", "/ban", "BANIMENTO"},
            {"MUTE", "lista_mute", "/mute", "MUTE"},
            {"KICK", "lista_kick", "/kick", "KICK"}
        }
        for _, c in ipairs(cats) do
            if hzButton(u8(c[1]), imgui.ImVec2(-1, modoCompacto and 30 or 34), C_CARD, C_HOVER, C_ACTIVE) then
                menuAtual = c[2]
                comandoBase = c[3]
                labelPunicao = c[4]
                aguardandoConfirmBanPerm = false
            end
        end
        if hzButton(u8"VOLTAR", imgui.ImVec2(-1, 28), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
            menuAtual = "principal"
            aguardandoConfirmBanPerm = false
        end

    elseif menuAtual:find("lista_") then
        imgui.TextColored(C_LINE, u8(labelPunicao))
        imgui.TextColored(C_MUTED, u8"Informe ou selecione o motivo")
        imgui.Separator()
        if modoPainel == 1 then
            imgui.PushItemWidth(-1)
            imgui.InputText(u8"Pesquisar", pesquisa)
            imgui.PopItemWidth()
            local lista = (menuAtual == "lista_cadeia" and motivosCadeia) or (menuAtual == "lista_mute" and motivosMute) or (menuAtual == "lista_ban" and motivosBan) or motivosKick
            imgui.BeginChild("sc", imgui.ImVec2(0, H_CHILD_LIST), true)
            for _, v in ipairs(lista) do
                if v[1]:lower():find(pesquisa.v:lower()) then
                    if hzButton(u8(v[1] .. "  |  " .. tostring(v[2])), imgui.ImVec2(-1, 27), C_CARD, C_HOVER, C_ACTIVE) then
                        motivoSel = v[1]
                        tempoPunicao.v = v[2]
                        menuAtual = "confirmar"
                        aguardandoConfirmBanPerm = false
                    end
                end
            end
            imgui.EndChild()
        else
            imgui.TextColored(C_MUTED, u8("Motivo Manual (" .. labelPunicao .. ")"))
            imgui.PushItemWidth(-1)
            if imgui.InputText("##mman", bufMotivoManual) then
                local motUpper = bufMotivoManual.v:upper()
                if tabelaTempos[motUpper] then tempoPunicao.v = tabelaTempos[motUpper] end
            end
            imgui.PopItemWidth()
            if comandoBase ~= "/kick" then
                imgui.TextColored(C_MUTED, comandoBase == "/punicao" and u8"Tempo (Minutos)" or u8"Tempo (Dias)")
                imgui.PushItemWidth(-1)
                imgui.InputInt("##tman", tempoPunicao)
                imgui.PopItemWidth()
            end
            if hzButton(u8"PROSSEGUIR", imgui.ImVec2(-1, H_BTN_MAIN), C_PRIMARY, C_HOVER, C_ACTIVE) then
                motivoSel = bufMotivoManual.v
                menuAtual = "confirmar"
                aguardandoConfirmBanPerm = false
            end
        end
        if hzButton(u8"VOLTAR", imgui.ImVec2(-1, 28), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
            menuAtual = "categorias"
            bufMotivoManual.v = ""
            tempoPunicao.v = 0
            aguardandoConfirmBanPerm = false
        end

    elseif menuAtual == "confirmar" then
        local statusLabel = labelPunicao
        if labelPunicao == "BANIMENTO" then
            statusLabel = (tempoPunicao.v == 0) and "BANIMENTO PERMANENTE" or "BANIMENTO TEMPORARIO"
        end
        imgui.TextColored(C_LINE, u8("CONFIRMAR " .. statusLabel))
        imgui.TextColored(C_MUTED, u8"Confira antes de aplicar")
        imgui.Separator()
        imgui.BeginChild("##hz_confirm", imgui.ImVec2(0, 116), true)
        if comandoBase == "/mute" then
            imgui.TextColored(C_MUTED, u8("RG: " .. rgTelado .. "   |   ID: " .. idTelado))
        else
            imgui.TextColored(C_MUTED, u8("NICK: " .. nickTelado))
            imgui.TextColored(C_MUTED, u8("RG: " .. rgTelado .. "   |   ID: " .. idTelado))
        end
        imgui.TextColored(C_TEXT, u8("MOTIVO: " .. motivoSel))
        if comandoBase ~= "/kick" then
            local txt = (comandoBase == "/ban" or comandoBase == "/mute") and u8"DIAS" or u8"TEMPO"
            imgui.InputInt(txt, tempoPunicao)
        end
        imgui.EndChild()

        local precisa2x = (confirmarBanPermanente2x and comandoBase == "/ban" and tempoPunicao.v == 0)
        local textoBtn = u8"CONFIRMAR PUNICAO"
        if precisa2x and not aguardandoConfirmBanPerm then textoBtn = u8"CONFIRMAR (2x)" elseif precisa2x and aguardandoConfirmBanPerm then textoBtn = u8"CONFIRMAR AGORA" end

        if hzButton(textoBtn, imgui.ImVec2(-1, 40), C_DANGER, C_DANGER_H, C_DANGER) then
            if not podeExecutarAcao() then
            else
                if precisa2x and not aguardandoConfirmBanPerm then
                    aguardandoConfirmBanPerm = true
                else
                    if comandoBase == "/kick" then
                        sampSendChat("/kick " .. rgTelado .. " " .. motivoSel)
                    elseif comandoBase == "/ban" then
                        if tempoPunicao.v == 0 then
                            sampSendChat("/ban " .. rgTelado .. " " .. motivoSel)
                        else
                            sampSendChat("/bantemp " .. rgTelado .. " " .. tempoPunicao.v .. " " .. motivoSel)
                        end
                    else
                        sampSendChat(comandoBase .. " " .. rgTelado .. " " .. tempoPunicao.v .. " " .. motivoSel)
                    end
                    menuAtual = "principal"
                    bufMotivoManual.v = ""
                    aguardandoConfirmBanPerm = false
                end
            end
        end
        if hzButton(u8"CANCELAR", imgui.ImVec2(-1, 28), C_DARKBTN, C_PRIMARY, C_ACTIVE) then
            menuAtual = "principal"
            bufMotivoManual.v = ""
            aguardandoConfirmBanPerm = false
        end
    end

    alturaJanela = imgui.GetCursorPosY() + 12
    imgui.End()
end


-- ======================
-- CAPTURA DE DADOS
-- ======================
local function paineltv_parse_info(text)
    paineltv_tentar_capturar_relogio(text)
    local clean = text:gsub("{%x%x%x%x%x%x}", ""):gsub("%s+", " ")
    local n = clean:match("NICK:%s*([A-Za-z0-9_]+)")
    local r = clean:match("RG:%s*(%d+)")
    local i = clean:match("ID:%s*(%d+)")
    local lvl = clean:match("LEVEL:%s*(%d+)") or clean:match("Level:%s*(%d+)")

    if n then nickTelado = n end
    if r then rgTelado = r end
    if lvl then levelTelado = lvl end

    if i then
        local novoId = i
        local trocouTelado = (novoId ~= "---" and novoId ~= ultimoIdTelado)

        -- ABRE automaticamente ao telar, sem precisar configurar e já no MODO 2
        if painelAutoAbrir and (not janela.v) and trocouTelado then
            janela.v = true
            menuAtual = "principal"
            aguardandoConfirmBanPerm = false
            setCursor(false)
            painelAbertoPorAuto = true
        end

        -- Aplicar configs ao trocar telado
        if trocouTelado then
            if voltarPrincipalAoTrocarTelado then
                menuAtual = "principal"
                aguardandoConfirmBanPerm = false
            end
            if limparMotivoTempoAoTrocarTelado then
                motivoSel = ""
                tempoPunicao.v = 0
                bufMotivoManual.v = ""
                aguardandoConfirmBanPerm = false
            end
        end

        idTelado = novoId
        ultimoIdTelado = novoId

        if trocouTelado and _G.HZAvisosAC then
            _G.HZAvisosAC.confirmarReport(nickTelado, novoId)
        end
    end
end

local function paineltv_onShowTextDraw(id, data) if data.text then paineltv_parse_info(data.text) end end
local function paineltv_onTextDrawSetString(id, text) paineltv_parse_info(text) end
local function paineltv_onShowPlayerTextDraw(playerId, data) if data.text then paineltv_parse_info(data.text) end end
local function paineltv_onPlayerTextDrawSetString(playerId, id, text) paineltv_parse_info(text) end

local function paineltv_onSendCommand(cmd)
    local cmdAc = tostring(cmd or ""):lower():match("^%s*(.-)%s*$")
    if cmdAc == "/reports" or cmdAc:match("^/reports%s+") then
        _G.HZAvisosAC.marcarReport()
    elseif cmdAc:match("^/tv%s+") or cmdAc == "/tvz" then
        -- /tv digitado, painel e navegacao pelas setas nao sao telagens de report.
        _G.HZAvisosAC.cancelarReport()
    end

    if cmdAc:match("^/tvoff") then
        _G.HZAvisosAC.aguardandoReport = false
        idTelado, rgTelado, nickTelado = "---", "---", "---"
        ultimoIdTelado = "---"
        setCursor(false)
        aguardandoConfirmBanPerm = false

        if fecharPainelSempreTvoff then
            janela.v = false
            painelAbertoPorAuto = false
            menuAtual = "principal"
            return
        end

        if painelAbertoPorAuto then
            janela.v = false
            painelAbertoPorAuto = false
        end
    end
end

    _G.PainelTVModule = {
        main = paineltv_main,
        OnInitialize = paineltv_OnInitialize,
        OnDrawFrame = paineltv_OnDrawFrame,
        onShowTextDraw = paineltv_onShowTextDraw,
        onTextDrawSetString = paineltv_onTextDrawSetString,
        onShowPlayerTextDraw = paineltv_onShowPlayerTextDraw,
        onPlayerTextDrawSetString = paineltv_onPlayerTextDrawSetString,
        isOpen = function() return janela.v == true end,
        onSendCommand = paineltv_onSendCommand,
        setEnabled = function(ativo)
            if not ativo then
                janela.v = false
                painelAbertoPorAuto = false
                setCursor(false)
            end
        end
    }
end

-- REVISAO: conversao nome -> RG aplicada apenas aos comandos autorizados; punicoes excluidas.
-- ============================================================
-- SETOR SEGURANCA INTEGRADO
-- ============================================================
-- ============================================================
-- SETOR SEGURANCA - ATUALIZACAO 01/05/2026
-- ============================================================
-- Regras:
-- Este sistema pertence a administracao Horizonte Roleplay.
-- Nenhuma alteracao, modificacao ou remocao no codigo e permitido.
-- O sistema devera permanecer 100% original.
-- Alteracoes nao autorizadas podem gerar punicao administrativa,
-- remocao da staff e outras medidas internas.
-- Uso restrito e exclusivo da administracao.
-- ============================================================
--
local samp = require 'samp.events'
local sampev = samp
local requests = require 'requests'
local imgui = require "imgui"
local encoding = require "encoding"
encoding.default = "CP1252"
local u8 = encoding.UTF8

local json = require "dkjson"

script_name("Suporte")
script_author("Nathan")
script_version("2.8")

-- ============================================================
-- WEBHOOKS CONSOLIDADOS (SETOR SEGURANÇA)
-- ============================================================
local WEBHOOKS = {
    -- Punicoes já existentes no painel
    BAN             = "https://discord.com/api/webhooks/1472343861719339212/BbCTngmkr9YZH5W7PiCVx_IjhC6eboyI072MlddFaGUzQ39i1g9FXI0AcgIJavP3dzdo",
    CADEIA          = "https://discord.com/api/webhooks/1472343962797998090/0zYDFcEW_q7pfrtMYmwk2_hijr33Bb_tS-GyXktfwg3Uvj1ZzAlMtgXk-VX5S5uBlGVU",
    MUTE            = "https://discord.com/api/webhooks/1472344170520907939/BTLBSNDhp054jKOLU7_3Q-eXunG4SM3g2K7uhRKv_3wIaKgp997daaLxwvLh2sYbJfUV",

    -- APIs EXATAS do arquivo Staff-Hz.lua enviado pelo coordenador
    LOG_TAPA         = "https://discord.com/api/webhooks/1519098721806192697/bah3dfhfZD29fJQeOf21awLF9WkcN8pkf1wITxFXDMjl2KXB2fjGg3fs7DoOyZjd2VU5",
    LOG_TRAZER       = "https://discord.com/api/webhooks/1519098792794656979/5xs6w4tv_CYyw0UN4BgjH1HBie9VgNuHUZMc_cfJFkXzJl5a-Fjfr3vaEzZMMBGG4AY1",
    LOG_IR           = "https://discord.com/api/webhooks/1519098786343817501/mmohOhvvFt8HtM8oFCDC7v4PzvEAh9yQCQ8sdVeOVsrrrGZyPTTJzVtHB6Wrdj_DknHT",
    LOG_CONGELAR     = "https://discord.com/api/webhooks/1519123580041035849/-HJzL4KKnS6sYqL3wssbAvsU54kCcSbaHrAfdZIJSJ2WfzoUz325I4bLdi-N1RQCX8sP",
    LOG_DESCONGELAR  = "https://discord.com/api/webhooks/1519123575108272268/Wj1tYTA4RQmpt_jIx8HtlNzuzed3DgQyAEVaYY94otiCTR9IfhWnMHqO_K9laLwAFYIe",
    LOG_PRENDERARMAS = "https://discord.com/api/webhooks/1519149792872108062/Nfnx7YOtGbBcDYvAbV3K9Uns6yiwZEWmgWWfLqXt0u68ejT4FOYG8HvjLxgIYFu_n6xB",
    LOG_SETVIDA      = "https://discord.com/api/webhooks/1519338573218840728/eiMlWVsK_0FqTHL-AwDNDFj0tICtgbkmqOlSN1dyaFCh-VOfQlvWfKCfDP49Kh-_iGjN",
    LOG_SETCOLETE    = "https://discord.com/api/webhooks/1519341309121269921/Jeb-TRF1I2zj3rrfwqx3pGSTGEdKYiHWHhFKW-dBf2hwiXZRtFmQZjusZjwFu2LsOFfJ",
    LOG_REVIVER      = "https://discord.com/api/webhooks/1519353929492860968/FjWWaoy1g2F3Jf05XzRFCe84L4ZZOczEsvD9FAAtR_ZhTclMxp14agsXIhgZG3dudTGH",
    -- Teleportes para locais (APIs EXATAS do Staff-Hz do coordenador)
    LOG_IRPOSTO      = "https://discord.com/api/webhooks/1519374390360539228/erwvupCvH1jEOA1e9HHZlp4CCyfcV2N1f-ktB5v1sz6nMyh_koUUfAJVnu2l9nQeGT1g",
    LOG_IRCASA       = "https://discord.com/api/webhooks/1519374377999663328/pCuRmkQN53eXJBqOKck_DtBxzx0NlNxjFzu1pIvs7lKrIOKPxNbQ0wjB0rapQ3XpZKQs",
    LOG_IREMPRESA    = "https://discord.com/api/webhooks/1519374367719428246/gVjTpRPrviLTqAUXnpTxYz-P_NlxfG7kEQmykJI8hvQE7U9VzZuNtPGauVIUF3P4Bg7z"
}

-- ============================================================
-- VARIÁVEIS DE CONTROLE - SETOR SEGURANÇA
-- ============================================================
local emAtendimento = false
local nickJogadorAtendido = ""
local idJogadorAtendido = ""
local cargoAdmin = "Desconhecido"
local nomeAdmin = ""
_G.HZStaffLogada = false
local historicoConversa = {}
local tempoInicio = 0
local tempoFinalCongelado = ""
local jogadorCaiu = false
local tempoExibicaoAviso = 0
local v_altura_tapa = "1"
local convertendoComandoPainel = false

local fontePrincipal, fonteTitulo, fonteAvisoSaida

-- ================== SISTEMA TV NOVATOS ==================
local font
local tvNovatosAtivo = false
local tvTodosAtivo = false
local VK_UP, VK_DOWN, VK_RIGHT, VK_LEFT = 0x26, 0x28, 0x27, 0x25
local wasUpDown, wasDownDown, wasRightDown, wasLeftDown = false, false, false, false
local rgCache = {}

local CACHE_PATH = getWorkingDirectory() .. "\\config\\hz_rg_cache.json"
local CONFIG_PATH = getWorkingDirectory() .. "\\config\\hz_setor_config.json"
local rgDatabase = {}

local configSistema = {
    tvNovatosAtivo = false,
    tvTodosAtivo = false,
    v_altura_tapa = "1",
    painelAtendimentoX = 20,
    painelAtendimentoY = 630,
    seletorX = 300,
    seletorY = 220,
    painelTvX = 20,
    painelTvY = 220,
    monitoradosX = 780,
    monitoradosY = 220,
    modsX = 360,
    modsY = 180,
    modsModoSeguro = false,
    modulos = {
        painel_tv = true,
        navegacao_tv = true,
        monitoramento = true,
        atendimento = true,
        camera_staff = true,
        automacoes_staff = true
    }
}

_G.HZModulosPadrao = {
    painel_tv = true, navegacao_tv = true, monitoramento = true,
    atendimento = true, camera_staff = true, automacoes_staff = true
}

_G.HZPermissaoMinimaModulo = {
    atendimento = 1,
    painel_tv = 2,
    navegacao_tv = 2,
    monitoramento = 3,
    camera_staff = 3,
    automacoes_staff = 1
}

-- Alguns servidores repetem a confirmacao de login administrativo em eventos
-- consecutivos. Centraliza o aviso para nao duplicar mensagens nem inicializacoes.
_G.HZUltimoAvisoCargo = _G.HZUltimoAvisoCargo or { chave = "", tempo = 0 }
function _G.HZAvisarCargoUmaVez(cargo, nome, sufixo)
    local agora = os.clock and os.clock() or 0
    local chave = tostring(cargo or ""):lower() .. "|" .. tostring(nome or ""):lower()
    if _G.HZUltimoAvisoCargo.chave == chave
        and agora - (tonumber(_G.HZUltimoAvisoCargo.tempo) or 0) < 5 then
        return false
    end
    _G.HZUltimoAvisoCargo.chave = chave
    _G.HZUltimoAvisoCargo.tempo = agora
    sampAddChatMessage(
        "{48C6FF}[CARGO] Identificado como " .. tostring(cargo or "Staff") .. ". " .. tostring(sufixo or "Permissoes aplicadas."),
        -1
    )
    return true
end

function _G.HZNivelCargo(cargo)
    cargo = tostring(cargo or ""):lower()
    if cargo:find("diretor", 1, true) then return 5, "Diretor" end
    if cargo:find("coorden", 1, true) then return 4, "Coordenador" end
    if cargo:find("admin", 1, true) then return 3, "Administrador" end
    if cargo:find("moder", 1, true) then return 2, "Moderador" end
    if cargo:find("ajud", 1, true) then return 1, "Ajudante" end
    return 0, "Nao identificado"
end

function _G.HZTemPermissaoModulo(id)
    if not _G.HZStaffLogada then return false end
    local nivel = _G.HZNivelCargo(cargoAdmin)
    return nivel >= tonumber(_G.HZPermissaoMinimaModulo[id] or 99)
end

function _G.HZModuloAtivo(id)
    return _G.HZTemPermissaoModulo(id)
        and type(configSistema.modulos) == "table"
        and configSistema.modulos[id] ~= false
end

local ultimoSalvamentoConfig = 0
local seletorPosCarregada = false
_G.HZModsPosCarregada = _G.HZModsPosCarregada or false

local seletorJogadorAberto = imgui.ImBool(false)
local seletorJogadorOpcoes = {}
local seletorJogadorBusca = ""
local seletorComandoOriginal = nil
local seletorJogadorIndice = 1

-- Controle para salvar/mover janelas
local painelAtendimentoArrastando = false
local painelAtendimentoOffsetX = 0
local painelAtendimentoOffsetY = 0

-- Estado da TV/cache precisa ficar antes das funcoes que leem/alteram esses valores.
local lastTvRequestedId = nil
local lastTvRequestedRG = nil
local rgTeladoAtual = nil
local nickTeladoAtual = nil
local nickPendenteCache = nil
local lastTvSentId = nil
local lastTvSentTime = 0

-- RGs capturados diretamente do chat no formato Nome[RG].
-- Usado pelos comandos autorizados para resolver nick -> RG sem depender de telagem previa.
local rgChatPorNick = {}

local function montarComandoComRG(cmd, rg)
    local original = tostring(cmd or "")
    local barra, comando, alvo, resto = original:match("^(%s*/)(%S+)%s+(%S+)%s*(.*)$")

    if not comando or not alvo then return nil end

    -- /stt possui o alvo no segundo argumento:
    -- /stt fome NOME 100 -> /stt fome RG 100
    if comando:lower() == "stt" then
        local status, alvoStt, quantidade = original:match("^%s*/stt%s+(%S+)%s+(%S+)%s+(%d+)%s*$")
        if status and alvoStt and quantidade then
            return "/stt " .. status .. " " .. tostring(rg) .. " " .. quantidade
        end
        return nil
    end

    local novoCmd = barra .. comando .. " " .. tostring(rg)

    if resto and resto ~= "" then
        novoCmd = novoCmd .. " " .. resto
    end

    return novoCmd
end

local function abrirSeletorJogador(busca, comandoOriginal)
    seletorJogadorBusca = tostring(busca or "")
    seletorComandoOriginal = comandoOriginal
    seletorJogadorIndice = 1
    seletorJogadorAberto.v = true
    imgui.Process = true
end

local function carregarCacheRG()
    local f = io.open(CACHE_PATH, "r")

    if f then
        local content = f:read("*a")
        f:close()

        local data = json.decode(content)

        if type(data) == "table" then
            rgDatabase = data
        end
    end
end

local function salvarCacheRG()
    local f = io.open(CACHE_PATH, "w+")

    if f then
        f:write(json.encode(rgDatabase, { indent = true }))
        f:close()
    end
end

local function aplicarConfigSistema()
    if type(configSistema.modulos) ~= "table" then configSistema.modulos = {} end
    for id, padrao in pairs(_G.HZModulosPadrao) do
        if configSistema.modulos[id] == nil then configSistema.modulos[id] = padrao end
    end
    -- O /mods apenas libera o recurso. A navegacao sempre inicia parada
    -- e somente o comando /hz1 ativa os atalhos pelas setas.
    tvNovatosAtivo = false
    tvTodosAtivo = false
    v_altura_tapa = tostring(configSistema.v_altura_tapa or v_altura_tapa or "1")
end

local function salvarConfigSistema(forcar)
    if not forcar and os.clock and os.clock() - ultimoSalvamentoConfig < 0.5 then
        return
    end

    ultimoSalvamentoConfig = os.clock and os.clock() or 0

    configSistema.tvNovatosAtivo = tvNovatosAtivo == true
    configSistema.tvTodosAtivo = tvTodosAtivo == true
    configSistema.v_altura_tapa = tostring(v_altura_tapa or "1")

    -- Mantem a posicao atual do Painel TV sincronizada com o mesmo arquivo de config.
    -- Usa ponte global porque a posicao real fica local dentro do modulo do Painel TV.
    if _G.PainelTVGetSavedPos then
        local tvx, tvy = _G.PainelTVGetSavedPos()
        if tvx ~= nil and tvy ~= nil then
            configSistema.painelTvX = tvx
            configSistema.painelTvY = tvy
        end
    end

    -- Mescla com o JSON existente para não apagar preferências do Painel TV.
    local data = {}
    local f = io.open(CONFIG_PATH, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local decoded = json.decode(content)
        if type(decoded) == "table" then data = decoded end
    end

    for k, v in pairs(configSistema) do
        data[k] = v
    end

    f = io.open(CONFIG_PATH, "w+")
    if f then
        f:write(json.encode(data, { indent = true }))
        f:close()
    end
end

local function carregarConfigSistema()
    local f = io.open(CONFIG_PATH, "r")

    if f then
        local content = f:read("*a")
        f:close()

        local data = json.decode(content)
        if type(data) == "table" then
            for k, v in pairs(data) do
                configSistema[k] = v
            end
        end
    end

    aplicarConfigSistema()

    -- Garante que o Painel TV use a posicao carregada pelo config principal tambem.
    if _G.PainelTVSetSavedPos then
        _G.PainelTVSetSavedPos(configSistema.painelTvX, configSistema.painelTvY)
    end
end

local function normalizarNickCache(s)
    if not s then return "" end
    return tostring(s):lower():gsub("_", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function removerNickDuplicadoDeOutrosRGs(rgAtual, nickAtual)
    local nickNorm = normalizarNickCache(nickAtual)
    if nickNorm == "" then return false end

    local mudou = false
    rgAtual = tostring(rgAtual or "")

    for rg, info in pairs(rgDatabase) do
        if tostring(rg) ~= rgAtual and type(info) == "table" then
            -- Se outro RG estava com o mesmo nick atual, não deixa esse nick duplicado.
            if normalizarNickCache(info.nick) == nickNorm then
                info.nick = "Desconhecido"
                mudou = true
            end

            -- Remove o nick da lista de nomes antigos de outros RGs.
            if type(info.nomes_antigos) == "table" then
                for i = #info.nomes_antigos, 1, -1 do
                    if normalizarNickCache(info.nomes_antigos[i]) == nickNorm then
                        table.remove(info.nomes_antigos, i)
                        mudou = true
                    end
                end
            end
        end
    end

    return mudou
end

local function normalizarBuscaNome(s)
    if not s then return "" end

    s = tostring(s):lower()

    -- Remove acentos comuns para a busca nao falhar por diferenca de digitacao.
    -- IMPORTANTE: nao usar chave vazia [""], pois isso quebra o gsub e pode
    -- fazer a busca pela TAB nao encontrar jogadores online pelo nome.
    local mapa = {
        ["á"]="a", ["à"]="a", ["ã"]="a", ["â"]="a", ["ä"]="a",
        ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
        ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
        ["ó"]="o", ["ò"]="o", ["õ"]="o", ["ô"]="o", ["ö"]="o",
        ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u",
        ["ç"]="c"
    }

    for a, b in pairs(mapa) do
        if a ~= "" then
            s = s:gsub(a, b)
        end
    end

    -- CORRECAO FORTE:
    -- Qualquer caractere que nao seja letra/numero vira espaco.
    -- Assim nomes como __cearense, _cearense, cearense, ce_arense,
    -- cearense_, joao_silva e joaosilva ficam comparaveis.
    return s
        :gsub("[^%w]+", " ")
        :gsub("%s+", " ")
        :match("^%s*(.-)%s*$")
end

local function compactarBuscaNome(s)
    return normalizarBuscaNome(s):gsub("%s+", "")
end

local function textoContemNome(nome, busca)
    local nomeNorm = normalizarBuscaNome(nome)
    local buscaNorm = normalizarBuscaNome(busca)

    if buscaNorm == "" or nomeNorm == "" then return false end

    local nomeCompacto = nomeNorm:gsub("%s+", "")
    local buscaCompacta = buscaNorm:gsub("%s+", "")

    if buscaCompacta == "" or nomeCompacto == "" then return false end

    -- Match direto normalizado.
    if nomeNorm == buscaNorm then return true end
    if nomeCompacto == buscaCompacta then return true end

    -- Match parcial normalizado.
    if nomeNorm:find(buscaNorm, 1, true) ~= nil then return true end
    if nomeCompacto:find(buscaCompacta, 1, true) ~= nil then return true end

    -- Match inverso: evita falhar quando o cache tem nome menor/sem prefixo
    -- e a TAB tem prefixos/simbolos, ou vice-versa.
    if buscaNorm:find(nomeNorm, 1, true) ~= nil then return true end
    if buscaCompacta:find(nomeCompacto, 1, true) ~= nil then return true end

    -- Se digitou por partes, todas precisam existir em algum ponto do nick.
    for parte in buscaNorm:gmatch("%S+") do
        local parteCompacta = parte:gsub("%s+", "")
        if parteCompacta ~= "" and nomeCompacto:find(parteCompacta, 1, true) == nil then
            return false
        end
    end

    return true
end

-- ============================================================
-- FALLBACK PELA TAB / PLAYERS ONLINE
-- Usa a lista interna do SA-MP para encontrar jogadores online
-- quando o nome ainda nao existe no cache de RG.
-- ============================================================
local function buscarJogadoresOnlinePorNomeOuID(valor)
    local resultados = {}
    valor = tostring(valor or ""):match("^%s*(.-)%s*$")

    if valor == "" then return resultados end

    local busca = normalizarBuscaNome(valor)
    local buscaSemEspaco = busca:gsub("%s+", "")
    local valorNumerico = valor:match("^%d+$") ~= nil

    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then
            local nick = sampGetPlayerNickname(id) or ""
            local nickNorm = normalizarBuscaNome(nick)
            local nickSemEspaco = nickNorm:gsub("%s+", "")
            local score = 0

            if sampGetPlayerScore then
                score = sampGetPlayerScore(id) or 0
            end

            local match = false
            local prioridade = 99

            if valorNumerico and tostring(id) == valor then
                match = true
                prioridade = 1
            elseif not valorNumerico and nickNorm == busca then
                match = true
                prioridade = 2
            elseif not valorNumerico and nickSemEspaco == buscaSemEspaco then
                match = true
                prioridade = 3
            elseif not valorNumerico and nickNorm:find(busca, 1, true) ~= nil then
                match = true
                prioridade = 4
            elseif not valorNumerico and nickSemEspaco:find(buscaSemEspaco, 1, true) ~= nil then
                match = true
                prioridade = 5
            else
                -- Busca por partes: /tv joao silva encontra Joao_DaSilva, Joao-Silva etc.
                local todasPartes = true
                for parte in busca:gmatch("%S+") do
                    if not nickNorm:find(parte, 1, true) and not nickSemEspaco:find(parte, 1, true) then
                        todasPartes = false
                        break
                    end
                end

                if todasPartes and busca ~= "" then
                    match = true
                    prioridade = 6
                end
            end

            if match then
                table.insert(resultados, {
                    id = tonumber(id),
                    nick = nick,
                    origem = "tab",
                    prioridade = prioridade,
                    score = score
                })
            end
        end
    end

    table.sort(resultados, function(a, b)
        if tonumber(a.prioridade or 99) ~= tonumber(b.prioridade or 99) then
            return tonumber(a.prioridade or 99) < tonumber(b.prioridade or 99)
        end
        return tonumber(a.id or 0) < tonumber(b.id or 0)
    end)

    return resultados
end

local function escolherMelhorJogadorOnline(valor, encontrados)
    encontrados = encontrados or buscarJogadoresOnlinePorNomeOuID(valor)

    if #encontrados == 0 then return nil, encontrados end
    if #encontrados == 1 then return encontrados[1], encontrados end

    -- Se existe somente um resultado de prioridade maxima/exata, usa direto.
    local melhorPrioridade = encontrados[1].prioridade or 99
    local melhores = {}

    for _, p in ipairs(encontrados) do
        if (p.prioridade or 99) == melhorPrioridade then
            table.insert(melhores, p)
        end
    end

    if #melhores == 1 and melhorPrioridade <= 3 then
        return melhores[1], encontrados
    end

    return nil, encontrados
end

local function telarJogadorOnlinePelaTAB(id, nick)
    id = tonumber(id)

    if not id or not sampIsPlayerConnected(id) then
        sampAddChatMessage("{FF0000}ERRO: Jogador nao esta online para telar pela TAB.", -1)
        return false
    end

    nick = nick or sampGetPlayerNickname(id) or tostring(id)

    -- Telagem pela TAB nunca pertence a /reports e nao pode gerar aviso /ac.
    if _G.HZAvisosAC then _G.HZAvisosAC.cancelarReport() end

    lastTvRequestedId = id
    lastTvRequestedRG = nil
    rgTeladoAtual = nil
    nickPendenteCache = nick
    nickTeladoAtual = nick
    lastTvSentId = id
    lastTvSentTime = os.time()

    lua_thread.create(function()
        -- Envia exatamente o clique da TAB que o servidor Horizonte espera.
        -- Nao repete o clique e nunca converte o ID interno em /tv ID.
        if type(sampSendClickPlayer) == "function" then
            sampSendClickPlayer(id, 0)
        else
            sampAddChatMessage("{FF0000}ERRO: Esta versao nao possui suporte ao clique da TAB.", -1)
        end
    end)

    sampAddChatMessage(string.format("{FFFF00}[TV] RG nao encontrado no cache. Telando %s pela TAB.", nick), -1)
    return true
end

local function buscarRGPorNomeOuRG(valor, silencioso)
    valor = tostring(valor or ""):match("^%s*(.-)%s*$")

    if valor == "" then
        if not silencioso then sampAddChatMessage("{FF0000}ERRO: Informe o RG ou nome do jogador.", -1) end
        return nil
    end

    local rgDireto = tostring(valor):gsub("%D", "")

    if rgDireto ~= "" and rgDireto == valor:gsub("%s+", "") then
        -- Se digitou numero, trata como RG direto.
        -- Nao depende do cache para permitir /tv RG completo.
        return rgDireto
    end

    local encontrados = {}
    local vistosRG = {}

    for rg, info in pairs(rgDatabase) do
        if type(info) == "table" and not vistosRG[tostring(rg)] then
            local nickAtual = info.nick or ""

            if nickAtual ~= "" and nickAtual ~= "Desconhecido" and textoContemNome(nickAtual, valor) then
                table.insert(encontrados, { rg = tostring(rg), nick = nickAtual })
                vistosRG[tostring(rg)] = true
            else
                local antigos = info.nomes_antigos or {}
                for _, antigo in ipairs(antigos) do
                    if antigo and antigo ~= "" and antigo ~= "Desconhecido" and textoContemNome(antigo, valor) then
                        table.insert(encontrados, { rg = tostring(rg), nick = nickAtual ~= "" and nickAtual or antigo })
                        vistosRG[tostring(rg)] = true
                        break
                    end
                end
            end
        end
    end

    if #encontrados == 1 then
        return encontrados[1].rg
    end

    if #encontrados > 1 then
        if not silencioso then
            seletorJogadorOpcoes = encontrados
            sampAddChatMessage("{FFFF00}Mais de um jogador encontrado. Selecione na janela.", -1)
        end

        return nil, "multiple"
    end

    if not silencioso then
        sampAddChatMessage("{FF0000}ERRO: Nome nao encontrado no cache. Use /tv RG_COMPLETO uma vez para salvar.", -1)
    end

    return nil
end


-- ============================================================
-- MONITORAMENTO STAFF - ETAPA 1 (COMPATIVEL COM LIMITE LUA 5.1)
-- Sem novos locals no escopo principal: evita "too many local variables".
-- ============================================================
_G.HZMonitorEtapa1 = _G.HZMonitorEtapa1 or {
    path = getWorkingDirectory() .. "\\config\\hz_monitorados.json",
    dados = {}
}
_G.HZMonitorEtapa1.checkbox = _G.HZMonitorEtapa1.checkbox or imgui.ImBool(false)
_G.HZMonitorEtapa1.motivoAberto = _G.HZMonitorEtapa1.motivoAberto or imgui.ImBool(false)
_G.HZMonitorEtapa1.motivoBuffer = _G.HZMonitorEtapa1.motivoBuffer or imgui.ImBuffer(120)
_G.HZMonitorEtapa1.checkboxRg = _G.HZMonitorEtapa1.checkboxRg or ""
_G.HZMonitorEtapa1.alvoRg = _G.HZMonitorEtapa1.alvoRg or ""
_G.HZMonitorEtapa1.alvoNick = _G.HZMonitorEtapa1.alvoNick or ""

_G.HZMonitorEtapa1.adminAtivo = _G.HZMonitorEtapa1.adminAtivo or false
_G.HZMonitorEtapa1.adminPendenteAte = _G.HZMonitorEtapa1.adminPendenteAte or 0
_G.HZMonitorEtapa1.proximaVerificacao = _G.HZMonitorEtapa1.proximaVerificacao or 0
_G.HZMonitorEtapa1.onlinePorRG = _G.HZMonitorEtapa1.onlinePorRG or {}
_G.HZMonitorEtapa1.inicializadoOnline = _G.HZMonitorEtapa1.inicializadoOnline or false

function _G.HZMonitorEtapa1.prepararCheckbox(rg, nick)
    rg = tostring(rg or ""):gsub("%D", "")
    if _G.HZMonitorEtapa1.checkboxRg ~= rg then
        _G.HZMonitorEtapa1.checkboxRg = rg
        _G.HZMonitorEtapa1.motivoAberto.v = false
        _G.HZMonitorEtapa1.motivoBuffer.v = ""
    end

    if not _G.HZMonitorEtapa1.motivoAberto.v then
        _G.HZMonitorEtapa1.checkbox.v = rg ~= "" and _G.HZMonitorEtapa1.dados[rg] ~= nil
    end
end

function _G.HZMonitorEtapa1.alterarCheckbox(rg, nick)
    rg = tostring(rg or ""):gsub("%D", "")
    if rg == "" then
        _G.HZMonitorEtapa1.checkbox.v = false
        sampAddChatMessage("{FF0000}[MONITOR] RG do jogador ainda nao foi capturado.", -1)
        return
    end

    if _G.HZMonitorEtapa1.checkbox.v then
        _G.HZMonitorEtapa1.alvoRg = rg
        _G.HZMonitorEtapa1.alvoNick = tostring(nick or "Desconhecido")
        _G.HZMonitorEtapa1.motivoBuffer.v = ""
        _G.HZMonitorEtapa1.motivoAberto.v = true
    else
        _G.HZMonitorEtapa1.motivoAberto.v = false
        _G.HZMonitorEtapa1.motivoBuffer.v = ""
        if _G.HZMonitorEtapa1.dados[rg] then
            _G.HZMonitorEtapa1.desmonitor(rg)
        end
    end
end

function _G.HZMonitorEtapa1.salvarMotivoPainel()
    local motivo = tostring(_G.HZMonitorEtapa1.motivoBuffer.v or ""):match("^%s*(.-)%s*$")
    if motivo == "" then
        sampAddChatMessage("{FFFF00}[MONITOR] Informe o motivo antes de salvar.", -1)
        return
    end

    _G.HZMonitorEtapa1.monitor(tostring(_G.HZMonitorEtapa1.alvoRg) .. " " .. motivo)
    _G.HZMonitorEtapa1.motivoAberto.v = false
    _G.HZMonitorEtapa1.motivoBuffer.v = ""
    _G.HZMonitorEtapa1.checkbox.v = _G.HZMonitorEtapa1.dados[tostring(_G.HZMonitorEtapa1.alvoRg)] ~= nil
end

function _G.HZMonitorEtapa1.cancelarMotivoPainel()
    _G.HZMonitorEtapa1.motivoAberto.v = false
    _G.HZMonitorEtapa1.motivoBuffer.v = ""
    _G.HZMonitorEtapa1.checkbox.v = _G.HZMonitorEtapa1.dados[tostring(_G.HZMonitorEtapa1.checkboxRg or "")] ~= nil
end

function _G.HZMonitorEtapa1.abrirComandoPainel(rg, nick)
    rg = tostring(rg or ""):gsub("%D", "")
    if rg == "" then
        sampAddChatMessage("{FF0000}[MONITOR] RG do jogador ainda nao foi capturado.", -1)
        return
    end

    if _G.HZMonitorEtapa1.dados and _G.HZMonitorEtapa1.dados[rg] then
        if type(sampSetChatInputEnabled) == "function" and type(sampSetChatInputText) == "function" then
            sampSetChatInputEnabled(true)
            sampSetChatInputText("/desmonitor " .. rg)
        else
            sampAddChatMessage("{FFFF00}[MONITOR] Use /desmonitor " .. rg, -1)
        end
    else
        if type(sampSetChatInputEnabled) == "function" and type(sampSetChatInputText) == "function" then
            sampSetChatInputEnabled(true)
            sampSetChatInputText("/monitor " .. rg .. " ")
        else
            sampAddChatMessage("{FFFF00}[MONITOR] Use /monitor " .. rg .. " [motivo]", -1)
        end
    end
end

function _G.HZMonitorEtapa1.carregar()
    _G.HZMonitorEtapa1.dados = {}

    local f = io.open(_G.HZMonitorEtapa1.path, "r")
    if not f then return end

    local content = f:read("*a")
    f:close()

    local ok, data = pcall(json.decode, content)
    if ok and type(data) == "table" then
        _G.HZMonitorEtapa1.dados = data
    end
end

function _G.HZMonitorEtapa1.salvar()
    local f = io.open(_G.HZMonitorEtapa1.path, "w+")
    if not f then
        sampAddChatMessage("{FF0000}[MONITOR] Nao foi possivel salvar hz_monitorados.json.", -1)
        return false
    end

    local ok, content = pcall(json.encode, _G.HZMonitorEtapa1.dados, { indent = true })
    if not ok then
        f:close()
        sampAddChatMessage("{FF0000}[MONITOR] Erro ao preparar o arquivo JSON.", -1)
        return false
    end

    f:write(content)
    f:close()
    return true
end


function _G.HZMonitorEtapa1.encontrarOnline(rg, info)
    rg = tostring(rg or "")
    info = type(info) == "table" and info or {}

    -- Primeiro usa RG confirmado para o ID nesta sessão.
    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) and tostring(rgCache[id] or "") == rg then
            return tonumber(id), sampGetPlayerNickname(id)
        end
    end

    -- Depois compara os nomes exatos associados ao RG.
    local nomesValidos = {}

    local function adicionarNome(nome)
        nome = tostring(nome or "")
        local chave = compactarBuscaNome(nome)

        if chave ~= "" and nome ~= "Desconhecido" then
            nomesValidos[chave] = true
        end
    end

    adicionarNome(info.nick)

    local cadastroRG = rgDatabase[tostring(rg)]
    if type(cadastroRG) == "table" then
        adicionarNome(cadastroRG.nick)

        if type(cadastroRG.nomes_antigos) == "table" then
            for _, nomeAntigo in ipairs(cadastroRG.nomes_antigos) do
                adicionarNome(nomeAntigo)
            end
        end
    end

    if next(nomesValidos) == nil then return nil, nil end

    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then
            local nickAtual = sampGetPlayerNickname(id) or ""

            if nomesValidos[compactarBuscaNome(nickAtual)] then
                return tonumber(id), nickAtual
            end
        end
    end

    return nil, nil
end

function _G.HZMonitorEtapa1.notificarEntrada(rg, info, id, nick)
    local motivo = tostring((info and info.motivo) or "Nao informado")
    local nome = tostring(nick or (info and info.nick) or "Desconhecido")

    sampAddChatMessage(string.format(
        "{FF3B3B}[MONITOR] ATENCAO: %s [RG %s | ID %s] entrou no servidor. Motivo: %s",
        nome, tostring(rg), tostring(id or "?"), motivo
    ), -1)

    if type(addOneOffSound) == "function" then
        pcall(addOneOffSound, 0.0, 0.0, 0.0, 1052)
    end
end

function _G.HZMonitorEtapa1.verificarEntradas(avisarAtuais)
    if not _G.HZMonitorEtapa1.adminAtivo then return end

    local agora = os.clock()
    if not avisarAtuais and agora < (_G.HZMonitorEtapa1.proximaVerificacao or 0) then return end
    _G.HZMonitorEtapa1.proximaVerificacao = agora + 1.0

    local novoEstado = {}

    for rg, info in pairs(_G.HZMonitorEtapa1.dados or {}) do
        if type(info) == "table" then
            local id, nick = _G.HZMonitorEtapa1.encontrarOnline(rg, info)
            local online = id ~= nil
            novoEstado[tostring(rg)] = online
            local antes = _G.HZMonitorEtapa1.onlinePorRG[tostring(rg)] == true

            if online and (avisarAtuais or (_G.HZMonitorEtapa1.inicializadoOnline and not antes)) then
                _G.HZMonitorEtapa1.notificarEntrada(rg, info, id, nick)
            end
        end
    end

    _G.HZMonitorEtapa1.onlinePorRG = novoEstado
    _G.HZMonitorEtapa1.inicializadoOnline = true

    if avisarAtuais then
        local totalLista = 0
        local totalOnline = 0

        for _, _ in pairs(_G.HZMonitorEtapa1.dados or {}) do
            totalLista = totalLista + 1
        end

        for _, online in pairs(novoEstado) do
            if online then totalOnline = totalOnline + 1 end
        end

        sampAddChatMessage(string.format(
            "{80D8FF}[MONITOR] Lista carregada: %d monitorado(s), %d online.",
            totalLista,
            totalOnline
        ), -1)
    end
end

function _G.HZMonitorEtapa1.definirAdminAtivo(ativo, avisarAtuais)
    ativo = ativo == true

    if ativo and not _G.HZMonitorEtapa1.adminAtivo then
        _G.HZMonitorEtapa1.adminAtivo = true
        _G.HZMonitorEtapa1.adminPendenteAte = 0
        _G.HZMonitorEtapa1.onlinePorRG = {}
        _G.HZMonitorEtapa1.inicializadoOnline = false
        _G.HZMonitorEtapa1.proximaVerificacao = 0
        sampAddChatMessage("{00FF7F}[MONITOR] Modo admin detectado. Alertas ativados.", -1)
        if avisarAtuais then _G.HZMonitorEtapa1.verificarEntradas(true) end
    elseif not ativo and _G.HZMonitorEtapa1.adminAtivo then
        _G.HZMonitorEtapa1.adminAtivo = false
        _G.HZMonitorEtapa1.adminPendenteAte = 0
        _G.HZMonitorEtapa1.onlinePorRG = {}
        _G.HZMonitorEtapa1.inicializadoOnline = false
        sampAddChatMessage("{FFFF00}[MONITOR] Modo admin encerrado. Alertas pausados.", -1)
    end
end

function _G.HZMonitorEtapa1.marcarAdminPendente()
    -- /la ou /logaradm apenas inicia a espera.
    -- O monitor será ativado somente pela mensagem real de login da staff.
    _G.HZMonitorEtapa1.adminPendenteAte = math.huge
end

function _G.HZMonitorEtapa1.ativarEListar()
    -- Evita que a mesma mensagem de login ative o monitor duas vezes.
    if _G.HZMonitorEtapa1.adminAtivo then
        _G.HZMonitorEtapa1.adminPendenteAte = 0
        return
    end

    _G.HZMonitorEtapa1.adminPendenteAte = 0
    _G.HZMonitorEtapa1.adminAtivo = true
    _G.HZMonitorEtapa1.onlinePorRG = {}
    _G.HZMonitorEtapa1.inicializadoOnline = false
    _G.HZMonitorEtapa1.proximaVerificacao = 0
    _G.HZMonitorEtapa1.carregar()

    sampAddChatMessage(
        "{00FF7F}[MONITOR] Modo admin detectado. Alertas ativados.",
        -1
    )

    lua_thread.create(function()
        wait(1200)

        if _G.HZMonitorEtapa1.adminAtivo then
            _G.HZMonitorEtapa1.carregar()
            _G.HZMonitorEtapa1.onlinePorRG = {}
            _G.HZMonitorEtapa1.inicializadoOnline = false
            _G.HZMonitorEtapa1.proximaVerificacao = 0
            _G.HZMonitorEtapa1.verificarEntradas(true)
        end
    end)
end

function _G.HZMonitorEtapa1.atualizar()
    -- Nunca ativa por tempo ou apenas pelo envio de /la.
    -- As entradas só são verificadas depois da confirmação real do login.
    _G.HZMonitorEtapa1.verificarEntradas(false)
end

function _G.HZMonitorEtapa1.obterNick(rg, nomeDigitado)
    local info = rgDatabase[tostring(rg or "")]
    if type(info) == "table" and info.nick and info.nick ~= "" then
        return tostring(info.nick)
    end

    if nomeDigitado and not tostring(nomeDigitado):match("^%d+$") then
        return tostring(nomeDigitado)
    end

    return "Desconhecido"
end

function _G.HZMonitorEtapa1.monitor(arg)
    arg = tostring(arg or ""):match("^%s*(.-)%s*$")
    local alvo, motivo = arg:match("^(%S+)%s+(.+)$")

    if not alvo or not motivo or motivo:match("^%s*$") then
        sampAddChatMessage("{FFFF00}Use: /monitor [RG ou nome] [motivo]", -1)
        return
    end

    local rg, status = buscarRGPorNomeOuRG(alvo, true)
    if not rg then
        if status == "multiple" then
            sampAddChatMessage("{FFFF00}[MONITOR] Mais de um jogador encontrado. Nesta etapa, use o RG completo.", -1)
        else
            sampAddChatMessage("{FF0000}[MONITOR] Jogador nao encontrado. Use o RG completo ou um nome salvo no cache.", -1)
        end
        return
    end

    rg = tostring(rg)
    _G.HZMonitorEtapa1.dados[rg] = {
        rg = rg,
        nick = _G.HZMonitorEtapa1.obterNick(rg, alvo),
        motivo = tostring(motivo),
        staff = tostring(nomeAdmin or "Desconhecido"),
        data = os.date("%d/%m/%Y %H:%M:%S")
    }

    if _G.HZMonitorEtapa1.salvar() then
        sampAddChatMessage(string.format("{00FF7F}[MONITOR] %s [RG %s] adicionado. Motivo: %s", _G.HZMonitorEtapa1.dados[rg].nick, rg, motivo), -1)
        local idAtual = _G.HZMonitorEtapa1.encontrarOnline(rg, _G.HZMonitorEtapa1.dados[rg])
        _G.HZMonitorEtapa1.onlinePorRG[rg] = idAtual ~= nil
    end
end

function _G.HZMonitorEtapa1.desmonitor(arg)
    local alvo = tostring(arg or ""):match("^%s*(.-)%s*$")
    if alvo == "" then
        sampAddChatMessage("{FFFF00}Use: /desmonitor [RG ou nome]", -1)
        return
    end

    local rg, status = buscarRGPorNomeOuRG(alvo, true)
    if not rg and alvo:match("^%d+$") then rg = alvo end

    if not rg then
        if status == "multiple" then
            sampAddChatMessage("{FFFF00}[MONITOR] Mais de um jogador encontrado. Nesta etapa, use o RG completo.", -1)
        else
            sampAddChatMessage("{FF0000}[MONITOR] Jogador nao encontrado. Use o RG completo.", -1)
        end
        return
    end

    rg = tostring(rg)
    local antigo = _G.HZMonitorEtapa1.dados[rg]
    if not antigo then
        sampAddChatMessage("{FFFF00}[MONITOR] Esse RG nao esta monitorado.", -1)
        return
    end

    _G.HZMonitorEtapa1.dados[rg] = nil
    _G.HZMonitorEtapa1.onlinePorRG[rg] = nil
    if _G.HZMonitorEtapa1.salvar() then
        sampAddChatMessage(string.format("{00FF7F}[MONITOR] %s [RG %s] removido.", tostring(antigo.nick or "Desconhecido"), rg), -1)
    end
end

local function getInfoRG(rg)
    rg = tostring(rg or "")
    local info = rgDatabase[rg]

    if type(info) == "table" then
        return info.nick or "Desconhecido", rg
    end

    return "Desconhecido", rg
end

function _G.HZAvisosAC.nomePorRG(rg)
    rg = tostring(rg or "")
    if tostring(rgTeladoAtual or "") == rg and tostring(nickTeladoAtual or "") ~= "" then
        return tostring(nickTeladoAtual)
    end
    if tostring(lastTvRequestedRG or "") == rg and tostring(nickTeladoAtual or "") ~= "" then
        return tostring(nickTeladoAtual)
    end
    local nome = getInfoRG(rg)
    if nome and nome ~= "Desconhecido" then return tostring(nome) end
    for id, rgSalvo in pairs(rgCache) do
        if tostring(rgSalvo) == rg and sampIsPlayerConnected(tonumber(id)) then
            return tostring(sampGetPlayerNickname(tonumber(id)) or ("RG " .. rg))
        end
    end
    return "RG " .. rg
end

function _G.HZAvisosAC.comando(cmd)
    local cmdOriginal = tostring(cmd or ""):match("^%s*(.-)%s*$")
    cmd = cmdOriginal:lower()
    if cmd == "" or cmd:match("^/ac%s") then return end

    -- Avisa no /ac quando um mute for aplicado:
    -- /mute RG DIAS MOTIVO
    local rgMute, diasMute = cmd:match("^/mute%s+(%d+)%s+(%d+)%s+.+$")
    if rgMute and diasMute then
        local motivoMute = cmdOriginal:match("^/%S+%s+%d+%s+%d+%s+(.+)$") or "Nao informado"
        motivoMute = tostring(motivoMute):match("^%s*(.-)%s*$")

        local palavraDias = tonumber(diasMute) == 1 and "dia" or "dias"
        local nomeMute = _G.HZAvisosAC.nomePorRG(rgMute)

        _G.HZAvisosAC.enviar(
            'Mutei por ' .. diasMute .. ' ' .. palavraDias ..
            ' o player ' .. nomeMute .. ' por ' .. motivoMute,
            450
        )
        return
    end

    -- Avisa no /ac quando um desmute for aplicado:
    -- /desmute RG
    local rgDesmute = cmd:match("^/desmute%s+(%d+)%s*$")
    if rgDesmute then
        local nome = _G.HZAvisosAC.nomePorRG(rgDesmute)
        _G.HZAvisosAC.enviar(
            'Desmutei o jogador ' .. nome .. '',
            450
        )
        return
    end

    local rg, valor = cmd:match("^/setvida%s+(%d+)%s+(%d+)%s*$")
    if rg and valor then
        _G.HZAvisosAC.enviar("Setei " .. valor .. " de vida no Player " .. _G.HZAvisosAC.nomePorRG(rg), 450)
        return
    end

    rg, valor = cmd:match("^/setcolete%s+(%d+)%s+(%d+)%s*$")
    if rg and valor then
        _G.HZAvisosAC.enviar("Setei " .. valor .. " de colete no Player " .. _G.HZAvisosAC.nomePorRG(rg), 450)
        return
    end

    -- Formato final do servidor: /stt STATUS RG QUANTIDADE
    local status, rgStatus, qtdStatus = cmd:match("^/stt%s+(.+)%s+(%d+)%s+(%d+)%s*$")
    if status and rgStatus and qtdStatus then
        status = tostring(status):match("^%s*(.-)%s*$")
        _G.HZAvisosAC.enviar(
            "Setei " .. qtdStatus .. " de " .. status .. " no Player " .. _G.HZAvisosAC.nomePorRG(rgStatus),
            450
        )
        return
    end

    rg = cmd:match("^/reviver%s+(%d+)%s*$")
    if rg then
        _G.HZAvisosAC.enviar("Revivi o Player " .. _G.HZAvisosAC.nomePorRG(rg), 450)
        return
    end

    -- /d RG mensagem: avisa somente depois que o comando final ja saiu com RG.
    rg = cmd:match("^/d%s+(%d+)%s+.+$")
    if rg then
        _G.HZAvisosAC.enviar(
            "Respondi a duvida do Player " .. _G.HZAvisosAC.nomePorRG(rg),
            450
        )
    end
end

local function getRGTeladoAtual()
    if rgTeladoAtual and tostring(rgTeladoAtual) ~= "" then
        return tostring(rgTeladoAtual)
    end

    if lastTvRequestedRG and tostring(lastTvRequestedRG) ~= "" then
        return tostring(lastTvRequestedRG)
    end

    if lastTvRequestedId and rgCache[lastTvRequestedId] then
        return tostring(rgCache[lastTvRequestedId])
    end

    return nil
end

-- Comandos que aceitam NOME ABREVIADO e podem abrir o seletor de players.
-- Mantem o padrao HZ: o comando final enviado sempre usa RG, nunca ID.
local comandosComSeletorPorNome = {
    -- Somente estes comandos podem converter nome abreviado para RG.
    -- Punicoes ficam deliberadamente fora desta lista por seguranca.
    tv = true,
    d = true,
    duvida = true,
    ir = true,
    trazer = true,
    tapa = true,
    reviver = true,
    congelar = true,
    descongelar = true,
    prenderarmas = true,
    checar = true,
    checarjogador = true,
    setvida = true,
    setcolete = true
}

local function comandoUsaAlvoOnline(nomeCmd)
    nomeCmd = tostring(nomeCmd or ""):lower()
    return comandosComSeletorPorNome[nomeCmd] == true
end

-- Busca segura: usa somente o NICK ATUAL exato salvo no banco.
-- Nao consulta nomes antigos, busca parcial ou RG preso apenas ao ID.
function HZ_buscarRGPorNickAtualExato(nick)
    local alvo = compactarBuscaNome(nick)
    if alvo == "" then return nil end
    local encontrado = nil
    for rg, info in pairs(rgDatabase) do
        if type(info) == "table" then
            local nickAtual = tostring(info.nick or "")
            if nickAtual ~= "" and nickAtual ~= "Desconhecido"
               and compactarBuscaNome(nickAtual) == alvo then
                if encontrado and tostring(encontrado) ~= tostring(rg) then return nil end
                encontrado = tostring(rg)
            end
        end
    end
    return encontrado
end

local function resolverRGDaOpcaoJogador(p)
    if not p or not p.nick or tostring(p.nick) == "" then return nil end
    local nickAtual = tostring(p.nick)

    -- RG capturado para o nick completo exato nesta sessao.
    local chaveNick = compactarBuscaNome(nickAtual)
    local rgChat = rgChatPorNick[chaveNick]
    if rgChat and tostring(rgChat) ~= "" then return tostring(rgChat) end

    -- Banco persistente: somente o nick atual exato.
    -- Nunca usa RG preso ao ID, nome antigo ou correspondencia parcial.
    local rgBanco = HZ_buscarRGPorNickAtualExato(nickAtual)
    if rgBanco and tostring(rgBanco) ~= "" then return tostring(rgBanco) end

    return nil
end

local function resolverPrimeiroArgumentoComoRG(cmd)
    local barra, comando, alvo, resto = cmd:match("^(%s*/)(%S+)%s+(%S+)%s*(.*)$")

    if not comando or not alvo then return nil end

    comando = comando:lower()

    -- Punicoes nao passam pela conversao de nome abreviado.
    -- /ban, /bantemp, /cadeia e /punicao continuam exigindo RG digitado
    -- ou sendo aplicados pelo painel, conforme o fluxo original.
    if not comandosComSeletorPorNome[comando] then return nil end

    -- No HZ, numero digitado em comando e RG.
    -- Nunca tratamos numero como ID e nunca convertemos numero para ID.
    if alvo:match("^%d+$") then return nil end

    local function montarNovoComando(alvoFinal)
        -- Preserva qualquer argumento depois do nome abreviado.
        -- Ex.: /setvida joao 100 -> /setvida RG 100 | /tapa joao 5 -> /tapa RG 5
        local novoCmd = barra .. comando .. " " .. tostring(alvoFinal)
        if resto and resto ~= "" then
            novoCmd = novoCmd .. " " .. resto
        end
        return novoCmd
    end

    local usaOnline = comandoUsaAlvoOnline(comando)

    -- Comandos de alvo online podem abrir seletor por nome abreviado,
    -- mas o comando final SEMPRE deve sair com RG, nunca com ID.
    if usaOnline then
        local encontradosOnline = buscarJogadoresOnlinePorNomeOuID(alvo)

        if #encontradosOnline == 1 then
            local p = encontradosOnline[1]

            -- CORRECAO /TV:
            -- Quando o alvo foi encontrado online pela TAB, somente considera o RG
            -- confiavel se ele estiver ligado ao ID atual ou tiver sido capturado no
            -- chat para o nick exato. Nao usa o banco historico como primeira opcao,
            -- pois ele pode conter associacao antiga/incorreta e o servidor responder
            -- "RG nao encontrado ou jogador offline".
            if comando == "tv" then
                local idAtual = p.id and tonumber(p.id) or nil
                local rgAtual = nil

                -- Nao usa RG preso ao ID, pois IDs sao reutilizados.
                if p.nick and tostring(p.nick) ~= "" then
                    local chaveNick = compactarBuscaNome(tostring(p.nick))
                    if rgChatPorNick[chaveNick] and tostring(rgChatPorNick[chaveNick]) ~= "" then
                        rgAtual = tostring(rgChatPorNick[chaveNick])
                    end
                end

                if not rgAtual and p.nick and tostring(p.nick) ~= "" then
                    rgAtual = HZ_buscarRGPorNickAtualExato(p.nick)
                end

                if rgAtual then
                    lastTvRequestedRG = rgAtual
                    rgTeladoAtual = rgAtual
                    nickPendenteCache = p.nick or alvo
                    nickTeladoAtual = p.nick or alvo
                    sampAddChatMessage(string.format("{00FF7F}RG localizado: %s -> RG %s.", tostring(p.nick or alvo), tostring(rgAtual)), -1)
                    return montarNovoComando(rgAtual)
                end

                -- Sem vinculo seguro de RG com o ID online: tela diretamente pela TAB.
                telarJogadorOnlinePelaTAB(p.id, p.nick or alvo)
                return false
            end

            local rg = resolverRGDaOpcaoJogador(p)

            if rg then
                sampAddChatMessage(string.format("{00FF7F}RG localizado: %s -> RG %s.", tostring(p.nick or alvo), tostring(rg)), -1)
                return montarNovoComando(rg)
            end

            -- Para /ir, /trazer e demais comandos, nao envia ID para evitar bug/aleatorio.

            sampAddChatMessage("{FF0000}ERRO: Nao encontrei o RG desse jogador. Aguarde o RG aparecer no chat ou use o RG completo no comando.", -1)
            return false
        end

        if #encontradosOnline > 1 then
            seletorJogadorOpcoes = encontradosOnline
            sampAddChatMessage("{FFFF00}Mais de um jogador online encontrado. Selecione na janela.", -1)
            abrirSeletorJogador(alvo, cmd)
            return false
        end
    end

    -- Fallback pelo cache de RG.
    local rg, status = buscarRGPorNomeOuRG(alvo, true)

    if rg then
        if comando == "tv" then
            lastTvRequestedRG = rg
            rgTeladoAtual = rg
            nickPendenteCache = alvo
            nickTeladoAtual = alvo
        end
        return montarNovoComando(rg)
    end

    if status == "multiple" then
        buscarRGPorNomeOuRG(alvo, false)
        abrirSeletorJogador(alvo, cmd)
        return false
    end

    if comando == "tv" then
        -- Impede que /tv NOME seja enviado cru ao servidor quando o jogador
        -- nao existe nem no cache nem na TAB online.
        sampAddChatMessage("{FF0000}ERRO: Jogador nao encontrado no cache nem na TAB.", -1)
        return false
    end

    return nil
end

local function getRGTeladoAtualSeguro()
    if rgTeladoAtual and tostring(rgTeladoAtual) ~= "" then
        return tostring(rgTeladoAtual)
    end

    if lastTvRequestedRG and tostring(lastTvRequestedRG) ~= "" then
        return tostring(lastTvRequestedRG)
    end

    if lastTvRequestedId and rgCache[lastTvRequestedId] then
        return tostring(rgCache[lastTvRequestedId])
    end

    return nil
end

local function corrigirComandoPainelRG(cmd)
    local rg = getRGTeladoAtualSeguro()
    if not rg then return nil end

    local original = tostring(cmd or "")
    local nomeCmd = original:match("^%s*/(%S+)") or ""
    local c = nomeCmd:lower()

    local comandosJogador = {
        tv = true,
        d = true,
        duvida = true,
        kick = true,
        ir = true,
        trazer = true,
        tapa = true,
        reviver = true,
        congelar = true,
        descongelar = true,
        prenderarmas = true,
        checar = true,
        checarjogador = true,
        checkar = true,
        info = true,
        spec = true,
        setvida = true,
        setcolete = true,
        stt = true,
        ban = true,
        bantemp = true,
        cadeia = true,
        punicao = true
    }

    if not comandosJogador[c] then return nil end

    -- Painel sem alvo: /prenderarmas, /checar, /reviver...
    if original:match("^%s*/%S+%s*$") then
        return "/" .. nomeCmd .. " " .. rg
    end

    -- REGRA HZ ATUAL:
    -- Se o comando ja veio com numero, esse numero e RG.
    -- Nao converte mais numero curto para RG do telado, para evitar trocar o alvo digitado.

    -- Painel mandando quantidade sem alvo: /setvida 100, /setcolete 100, /tapa 50
    if c == "setvida" or c == "setcolete" or c == "tapa" then
        local unico = original:match("^%s*/%S+%s+(%d+)%s*$")
        if unico then
            return "/" .. nomeCmd .. " " .. rg .. " " .. unico
        end
    end

    return nil
end

local historicoN, histIndexN, histMaxN = {}, 0, 200
local catalogoN = {}
local idAtualN, ultimoCicloN = nil, nil
local historicoA, histIndexA, histMaxA = {}, 0, 400
local idAtualA, ultimoCicloA = nil, nil

-- Mantido fora de setor_main para nao ultrapassar o limite de 60 upvalues do LuaJIT.
function _G.HZResetarNavegacaoTV()
    historicoN, histIndexN, idAtualN, ultimoCicloN = {}, 0, nil, nil
    historicoA, histIndexA, idAtualA, ultimoCicloA = {}, 0, nil, nil
    wasUpDown, wasDownDown, wasRightDown, wasLeftDown = false, false, false, false
    _G.HZNavNovatoPendente = nil
    _G.HZNavNovatoSuprimirErroAte = 0
end

-- ================== SISTEMA CÂMERA STAFF INTEGRADO ==================
local CAMERA_CHAT_COLOR = -1
local camOn = false
local godMode = false
local isStaffMode = false
local posX, posY, posZ = 0, 0, 0
local angZ, angY = 0, 0
local BASE_SPEED = 0.1
local SPEED_STEP = 0.1
local MAX_SPEED_FACTOR = 1.5
local speedFactor = 1.0
local lastSceneX, lastSceneY, lastSceneZ = 0, 0, 0
local loadingScene = false
local lastPlayerX, lastPlayerY, lastPlayerZ = 0, 0, 0

-- ================== SISTEMA AUTOMÁTICO /SACIARME NA STAFF ==================
local staffWorkActive = false
local saciarmeInterval = 20 * 60
local saciarmeNextTime = 0

local function startStaffSaciarme()
    staffWorkActive = true
    saciarmeNextTime = os.time() + saciarmeInterval
    sampSendChat("/saciarme")
end

local function stopStaffSaciarme()
    staffWorkActive = false
    saciarmeNextTime = 0
end

-- ================== SISTEMA AUTOMÁTICO DE MENSAGENS DE SUPORTE POR CARGO ==================
local staffSupportActive = false
local staffSupportRole = nil
local staffSupportIndex = 1
local staffSupportInterval = 10 * 60
local staffSupportNextTime = 0

local staffSupportData = {
    ajudante = {
        messages = {
            "/A Esta precisando de ajuda ou atendimento use /atendimento iremos te ajudar",
            "/A Esta com duvida use /duvida ou /ajuda para suporte da staff",
            "/A Esta bugado ou precisa de ajuda use /atendimento para suporte"
        }
    },
    moderador = {
        messages = {
            "/A Viu algum jogador quebrando regra da nossa cidade use /reportar id motivo",
            "/A Jogadores cometendo anti rp reporte para administracao use /reportar id motivo",
            "/A Sofreu por anti rp em nossa cidade use /reportar id motivo"
        }
    },
    administrador = {
        messages = {
            "/A Uso de trapaca hack ou cheater e proibido em nossa cidade pode gerar banimento",
            "/A Quebra de regra no servidor pode gerar punicao conforme a gravidade",
        }
    }
}

local function getStaffSupportRole(cargo)
    if not cargo then return nil end
    local lower = cargo:lower()
    if lower:find("ajudante") then
        return "ajudante"
    elseif lower:find("moderador") then
        return "moderador"
    elseif lower:find("administrador") or lower:find("admin")
        or lower:find("coorden") or lower:find("diretor") then
        return "administrador"
    end
    return nil
end

local function isSupportAllowedTime()
    local t = os.date("*t")
    if t.hour < 6 or (t.hour == 6 and t.min < 30) then
        return false
    end
    return true
end

local function getNextAllowedSupportTime()
    local t = os.date("*t")
    if t.hour < 6 or (t.hour == 6 and t.min < 30) then
        t.hour = 6
        t.min = 30
        t.sec = 0
        return os.time(t)
    end
    t.hour = 6
    t.min = 30
    t.sec = 0
    t.day = t.day + 1
    return os.time(t)
end

local function startStaffSupport(cargo)
    local role = getStaffSupportRole(cargo or cargoAdmin)
    if not role or not staffSupportData[role] then
        staffSupportActive = false
        staffSupportRole = nil
        staffSupportIndex = 1
        staffSupportNextTime = 0
        return
    end
    staffSupportActive = true
    staffSupportRole = role
    staffSupportIndex = 1
    if isSupportAllowedTime() then
        staffSupportNextTime = os.time() + 5 * 60
    else
        staffSupportNextTime = getNextAllowedSupportTime() + 5 * 60
    end
end

local function stopStaffSupport()
    staffSupportActive = false
    staffSupportRole = nil
    staffSupportIndex = 1
    staffSupportNextTime = 0
end

local function sendStaffSupportMessage()
    if not staffSupportActive or not staffSupportRole then
        stopStaffSupport()
        return
    end

    local data = staffSupportData[staffSupportRole]
    if not data then
        stopStaffSupport()
        return
    end

    local message = data.messages[staffSupportIndex]
    if message and message ~= "" then
        sampSendChat(message)
    end

    staffSupportIndex = staffSupportIndex % #data.messages + 1
    staffSupportNextTime = os.time() + staffSupportInterval
    if not isSupportAllowedTime() then
        staffSupportNextTime = getNextAllowedSupportTime()
    end
end

-- Mantem as automacoes fora do loop principal para respeitar o limite de
-- 60 upvalues do LuaJIT usado por esta versao do MoonLoader.
function _G.HZAtualizarAutomacoesStaff()
    if not _G.HZModuloAtivo("automacoes_staff") then return end

    if staffWorkActive and os.time() >= saciarmeNextTime then
        sampSendChat("/saciarme")
        saciarmeNextTime = os.time() + saciarmeInterval
    end

    if staffSupportActive and os.time() >= staffSupportNextTime then
        sendStaffSupportMessage()
    end
end

local function upJustPressed()
    local d = isKeyDown(VK_UP)
    local j = d and not wasUpDown
    wasUpDown = d
    return j
end

local function downJustPressed()
    local d = isKeyDown(VK_DOWN)
    local j = d and not wasDownDown
    wasDownDown = d
    return j
end

local function rightJustPressed()
    local d = isKeyDown(VK_RIGHT)
    local j = d and not wasRightDown
    wasRightDown = d
    return j
end

local function leftJustPressed()
    local d = isKeyDown(VK_LEFT)
    local j = d and not wasLeftDown
    wasLeftDown = d
    return j
end

local function anunciarTelagemComRG(id)
    local rg = rgCache[id]
    return rg ~= nil
end

local function normalize_digits(s)
    if not s then return nil end
    local d = s:gsub("%D", "")
    if d == "" then return nil end
    return d
end

local function try_parse_rg_and_id_from_text(s)
    if type(s) ~= "string" then return nil, nil end

    -- IMPORTANTE:
    -- Nao pode capturar "ORG 500" como se fosse "RG 500".
    -- Por isso o RG precisa estar no inicio do texto ou separado por caractere que nao seja letra.
    local rgRaw = s:match("^%s*[Rr]%s*[Gg]%s*[:%-]?%s*([%d%s%.]+)")

    if not rgRaw then
        rgRaw = s:match("[^%a][Rr]%s*[Gg]%s*[:%-]?%s*([%d%s%.]+)")
    end

    local idRaw = s:match("^%s*[Ii]%s*[Dd]%s*[:%-]?%s*(%d+)")

    if not idRaw then
        idRaw = s:match("[^%a][Ii]%s*[Dd]%s*[:%-]?%s*(%d+)")
    end

    local rg = normalize_digits(rgRaw)
    local pid = idRaw and tonumber(idRaw) or nil

    return rg, pid
end

local function try_parse_nick_from_text(s)
    if type(s) ~= "string" then return nil end

    local clean = s:gsub("{%x%x%x%x%x%x}", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")

    local nome = clean:match("[Nn]ick%s*[:%-]?%s*([%a%d_]+)")
        or clean:match("[Nn]ome%s*[:%-]?%s*([%a%d_]+)")
        or clean:match("[Jj]ogador%s*[:%-]?%s*([%a%d_]+)")

    return nome
end

local function salvarRGNoBanco(rg, nome, pid)
    if not rg then return end

    rg = tostring(rg):gsub("%D", "")
    if rg == "" then return end

    nome = nome or "Desconhecido"

    if nome ~= "Desconhecido" then
        removerNickDuplicadoDeOutrosRGs(rg, nome)
    end

    if not rgDatabase[rg] then
        rgDatabase[rg] = {
            nick = nome,
            nomes_antigos = {},
            ultimo_id = pid or 0,
            ultima_vez_visto = os.date("%d/%m/%Y %H:%M:%S")
        }
    else
        local antigoNick = rgDatabase[rg].nick

        if antigoNick and antigoNick ~= nome and nome ~= "Desconhecido" then
            rgDatabase[rg].nomes_antigos = rgDatabase[rg].nomes_antigos or {}

            local existe = false

            for _, n in ipairs(rgDatabase[rg].nomes_antigos) do
                if n == antigoNick then
                    existe = true
                    break
                end
            end

            if not existe then
                table.insert(rgDatabase[rg].nomes_antigos, antigoNick)
            end
        end

        if nome ~= "Desconhecido" then
            rgDatabase[rg].nick = nome
        end

        rgDatabase[rg].ultimo_id = pid or rgDatabase[rg].ultimo_id or 0
        rgDatabase[rg].ultima_vez_visto = os.date("%d/%m/%Y %H:%M:%S")
    end

    salvarCacheRG()
end

-- Anti-duplicacao da captura de RG.
-- O mesmo RG pode chegar em mais de um evento do SA-MP:
-- onShowTextDraw, onTextDrawSetString, onShowPlayerTextDraw e onPlayerTextDrawSetString.
-- Sem essa trava, a mensagem "Info:" e o salvamento podem acontecer 2x ou mais.
local ultimoInfoChave = nil
local ultimoInfoTempo = 0

local function maybe_store_and_announce(rg, pid, nickCapturado)
    local changed = false

    if rg then
        rg = tostring(rg):gsub("%D", "")

        -- Se o /tv foi feito por RG/nome e ja sabemos o RG esperado,
        -- ignora numeros soltos de outros textdraws, como ORG 500.
        if lastTvRequestedRG and tostring(lastTvRequestedRG) ~= "" and not pid and rg ~= tostring(lastTvRequestedRG) then
            return false
        end

        local pidFinal = pid or lastTvRequestedId
        local nome = nickCapturado

        if not nome and pidFinal then
            nome = sampGetPlayerNickname(pidFinal)
        end

        if not nome and rgDatabase[rg] and rgDatabase[rg].nick then
            nome = rgDatabase[rg].nick
        end

        nome = nome or nickPendenteCache or nickTeladoAtual or "Desconhecido"

        -- Trava curta contra captura duplicada do mesmo jogador/RG.
        -- Mantem o estado/cache coerente, mas nao repete mensagem no chat.
        local chaveAtual = tostring(rg) .. "|" .. tostring(pidFinal or 0) .. "|" .. tostring(nome or "")
        local agora = os.clock()

        if ultimoInfoChave == chaveAtual and (agora - ultimoInfoTempo) < 2.0 then
            if pidFinal then
                rgCache[pidFinal] = rg
            end

            rgTeladoAtual = rg
            lastTvRequestedRG = rg
            nickTeladoAtual = nome
            nickPendenteCache = nil
            return false
        end

        ultimoInfoChave = chaveAtual
        ultimoInfoTempo = agora

        rgTeladoAtual = rg
        lastTvRequestedRG = rg
        nickTeladoAtual = nome
        nickPendenteCache = nil

        if pidFinal then
            rgCache[pidFinal] = rg
        end

        salvarRGNoBanco(rg, nome, pidFinal)

        -- A navegacao de novatos pode usar a TAB apenas para descobrir o RG.
        -- Assim que o RG chega, conclui a telagem pelo comando correto do servidor.
        if _G.HZNavNovatoPendente
            and pidFinal
            and tonumber(_G.HZNavNovatoPendente.id) == tonumber(pidFinal) then
            _G.HZNavNovatoPendente = nil
            lua_thread.create(function()
                wait(150)
                sampSendChat("/tv " .. tostring(rg))
            end)
        end

        changed = true

        local lvl = pidFinal and (sampGetPlayerScore(pidFinal) or 0) or 0
        sampAddChatMessage(string.format("{00FF7F}Info: Level %d", lvl), -1)
    end

    return changed
end

local function ehNovato(id)
    if not id or not sampIsPlayerConnected(id) then return false end
    local lvl = sampGetPlayerScore(id)
    if lvl == nil then return false end
    -- Para a navegacao, novato e todo jogador entre Level 0 e Level 30.
    return tonumber(lvl) ~= nil and tonumber(lvl) >= 0 and tonumber(lvl) <= 30
end

local function addToCatalogN(id)
    if ehNovato(id) then catalogoN[id] = true end
end

local function pushHistoricoN(id)
    if not ehNovato(id) then return end
    if histIndexN < #historicoN then
        for i=#historicoN, histIndexN+1, -1 do table.remove(historicoN, i) end
    end
    table.insert(historicoN, id)
    if #historicoN > histMaxN then
        local excesso = #historicoN - histMaxN
        for i=1,excesso do table.remove(historicoN,1) end
        histIndexN = math.max(0, histIndexN - excesso)
    end
    histIndexN = #historicoN
end

-- A navegacao trabalha com IDs da TAB, mas o comando /tv do Horizonte exige RG.
-- Resolve pelo nick atual para impedir que um ID reutilizado aponte para outro jogador.
function _G.HZResolverRGNavegacao(id)
    id = tonumber(id)
    if not id or not sampIsPlayerConnected(id) then return nil end

    local nick = tostring(sampGetPlayerNickname(id) or "")
    if nick == "" then return nil end

    local chaveNick = compactarBuscaNome(nick)
    local rg = rgCache[id]

    -- Descarta cache do ID quando ele foi reutilizado por outro nick.
    if rg and rgDatabase[tostring(rg)] and rgDatabase[tostring(rg)].nick then
        if tostring(rgDatabase[tostring(rg)].nick):lower() ~= nick:lower() then
            rg = nil
            rgCache[id] = nil
        end
    end

    if not rg or tostring(rg) == "" then
        rg = rgChatPorNick[chaveNick]
    end

    if not rg or tostring(rg) == "" then
        rg = HZ_buscarRGPorNickAtualExato(nick)
    end

    rg = tostring(rg or ""):gsub("%D", "")
    if rg == "" then return nil end
    return rg, nick
end

function _G.HZTelarRGNavegacao(id)
    local rg, nick = _G.HZResolverRGNavegacao(id)
    if not rg then return false end

    if lastTvRequestedRG == rg and os.time() - lastTvSentTime < 3 then
        lastTvRequestedId = id
        return true
    end

    lastTvRequestedId = id
    lastTvRequestedRG = rg
    rgTeladoAtual = rg
    nickPendenteCache = nick
    nickTeladoAtual = nick
    lastTvSentId = id
    lastTvSentTime = os.time()
    sampSendChat("/tv " .. rg)
    return true
end

local function telarIdN(id)
    if not id then return false end
    if not ehNovato(id) then
        sampAddChatMessage("{FFA500}Ignorando "..tostring(id).." (nao esta entre Level 0 e 30).", -1)
        return false
    end
    if _G.HZTelarRGNavegacao(id) then return true end

    -- Novatos frequentemente ainda nao existem no cache de RG.
    -- Nesse caso usa o ID/Level da TAB para iniciar a telagem e capturar o RG.
    local nick = tostring(sampGetPlayerNickname(id) or id)
    _G.HZNavNovatoPendente = { id = id, inicio = os.clock and os.clock() or 0 }
    _G.HZNavNovatoSuprimirErroAte = (os.clock and os.clock() or 0) + 6.0
    return telarJogadorOnlinePelaTAB(id, nick)
end

local function getNovatosSorted()
    local lst = {}
    for i=0, sampGetMaxPlayerId() do if ehNovato(i) then table.insert(lst, i) end end
    table.sort(lst)
    return lst
end

local function pickNextByCycleN()
    local lst = getNovatosSorted()
    if #lst == 0 then return nil end
    local startId = ultimoCicloN or idAtualN
    local startPos = 0
    if startId ~= nil then
        for i,v in ipairs(lst) do if v == startId then startPos = i break end end
    end
    local n = #lst
    for step=1,n do
        local idx = ((startPos + step - 1) % n) + 1
        local id = lst[idx]
        if id ~= idAtualN then return id end
    end
    return lst[1]
end

local function telarIdA(id, prefixoCor)
    if not id or not sampIsPlayerConnected(id) then
        sampAddChatMessage("{FFA500}ID "..tostring(id).." indisponivel agora.", -1)
        return false
    end
    return _G.HZTelarRGNavegacao(id)
end

local function pushHistoricoA(id)
    if not (id and sampIsPlayerConnected(id)) then return end
    if histIndexA < #historicoA then
        for i=#historicoA, histIndexA+1, -1 do table.remove(historicoA, i) end
    end
    table.insert(historicoA, id)
    if #historicoA > histMaxA then
        local excesso = #historicoA - histMaxA
        for i=1,excesso do table.remove(historicoA,1) end
        histIndexA = math.max(0, histIndexA - excesso)
    end
    histIndexA = #historicoA
end

local function getAllSorted()
    local lst = {}
    for i=0, sampGetMaxPlayerId() do if sampIsPlayerConnected(i) then table.insert(lst, i) end end
    table.sort(lst)
    return lst
end

local function pickNextByCycleA()
    local lst = getAllSorted()
    if #lst == 0 then return nil end
    local startId = ultimoCicloA or idAtualA
    local startPos = 0
    if startId ~= nil then
        for i,v in ipairs(lst) do if v == startId then startPos = i break end end
    end
    local n = #lst
    for step=1,n do
        local idx = ((startPos + step - 1) % n) + 1
        local id = lst[idx]
        if id ~= idAtualA and _G.HZResolverRGNavegacao(id) then return id end
    end
    if _G.HZResolverRGNavegacao(lst[1]) then return lst[1] end
    return nil
end

local function camEnable(staff)
    if camOn then return end

    lastPlayerX, lastPlayerY, lastPlayerZ = getCharCoordinates(PLAYER_PED)

    isStaffMode = staff
    posX, posY, posZ = lastPlayerX, lastPlayerY, lastPlayerZ
    angZ = getCharHeading(PLAYER_PED) * -1.0
    angY = 0

    setFixedCameraPosition(posX, posY, posZ, 0, 0, 0)
    camOn = true
    godMode = true
    freezeCharPosition(PLAYER_PED, true)
    setCharProofs(PLAYER_PED, true, true, true, true, true)

    if isStaffMode then
        setCharVisible(PLAYER_PED, false)
    else
        sampAddChatMessage("INFO: Ola Adm voce logou no modo trabalho de Camera staff!", CAMERA_CHAT_COLOR)
    end
end

local function camDisable()
    if not camOn then return end

    local wasStaff = isStaffMode
    camOn = false
    godMode = false
    restoreCamera()
    setCameraBehindPlayer()
    freezeCharPosition(PLAYER_PED, false)
    setCharProofs(PLAYER_PED, false, false, false, false, false)
    setCharVisible(PLAYER_PED, true)

    if not wasStaff then
        sampAddChatMessage("INFO: Voce sair do modo trabalho da Camera staff", CAMERA_CHAT_COLOR)
    end
    isStaffMode = false
end

local function updateCam()
    local speed = BASE_SPEED * speedFactor
    local dx, dy = getPcMouseMovement()
    angZ = angZ + dx / 4
    angY = angY + dy / 4
    if angY > 89 then angY = 89 elseif angY < -89 then angY = -89 end

    local rz, ry = math.rad(angZ), math.rad(angY)
    local sinZ, cosZ = math.sin(rz), math.cos(rz)
    local sinY, cosY = math.sin(ry), math.cos(ry)

    local mvx, mvy, mvz = 0, 0, 0
    if isKeyDown(0x57) then mvx = mvx + sinZ * cosY; mvy = mvy + cosZ * cosY; mvz = mvz + sinY end
    if isKeyDown(0x53) then mvx = mvx - sinZ * cosY; mvy = mvy - cosZ * cosY; mvz = mvz - sinY end
    if isKeyDown(0x41) then mvx = mvx - cosZ; mvy = mvy + sinZ end
    if isKeyDown(0x44) then mvx = mvx + cosZ; mvy = mvy - sinZ end
    if isKeyDown(0x51) then mvz = mvz + 1 end
    if isKeyDown(0x45) then mvz = mvz - 1 end

    posX = posX + mvx * speed
    posY = posY + mvy * speed
    posZ = posZ + mvz * speed

    if isStaffMode then
        setCharCoordinates(PLAYER_PED, posX, posY, posZ - 1.0)
        setCharHeading(PLAYER_PED, angZ * -1.0)
    end

    setFixedCameraPosition(posX, posY, posZ, 0, 0, 0)
    local poiX = posX + math.sin(rz) * math.cos(ry) * 10
    local poiY = posY + math.cos(rz) * math.cos(ry) * 10
    local poiZ = posZ + math.sin(ry) * 10
    pointCameraAtPoint(poiX, poiY, poiZ, 2)
end

local function stealthTeleportToCam()
    if not camOn then return end
    local startX, startY, startZ = getCharCoordinates(PLAYER_PED)
    for i = 1, 20 do
        local t = i / 20
        setCharCoordinates(PLAYER_PED, startX + (posX - startX) * t, startY + (posY - startY) * t, startZ + (posZ - startZ) * t)
        wait(15)
    end
    camDisable()
    sampAddChatMessage("INFO: teleportado discretamente para a posicao da camera.", CAMERA_CHAT_COLOR)
end

local function stealthTeleportBack()
    if lastPlayerX == 0 and lastPlayerY == 0 and lastPlayerZ == 0 then return end
    local cx, cy, cz = getCharCoordinates(PLAYER_PED)
    for i = 1, 20 do
        local t = i / 20
        setCharCoordinates(PLAYER_PED, cx + (lastPlayerX - cx) * t, cy + (lastPlayerY - cy) * t, cz + (lastPlayerZ - cz) * t)
        wait(15)
    end
    camDisable()
    sampAddChatMessage("INFO: voce voltou discretamente para a posicao anterior.", CAMERA_CHAT_COLOR)
end

function sampev.onSetPlayerHealth(playerId, health)
    if playerId == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) and godMode then
        return false
    end
end

-- Variáveis de captura de Segurança
local v_rg, v_tempo, v_motivo, v_tipo = "", "", "", ""
local aguardandoConfirmacao = false

-- ============================================================
-- JANELA DE SELECAO DE JOGADOR POR NOME PARCIAL
-- ============================================================
local VK_RETURN_SELETOR = 0x0D
local VK_ESCAPE_SELETOR = 0x1B

local seletorPressUp = false
local seletorPressDown = false
local seletorPressEnter = false
local seletorPressEsc = false

local function fecharSeletorJogador()
    salvarConfigSistema(true)
    seletorPressUp = false
    seletorPressDown = false
    seletorPressEnter = false
    seletorPressEsc = false
    seletorJogadorAberto.v = false
    imgui.Process = false
    seletorComandoOriginal = nil
    seletorJogadorIndice = 1
end

-- Bloqueia as teclas do seletor no GTA, mas ainda permite navegar no painel.
-- As teclas sao capturadas aqui antes do jogo receber, e depois usadas no ImGui.
local WM_KEYDOWN_SELETOR = 0x0100
local WM_SYSKEYDOWN_SELETOR = 0x0104
local WM_KEYUP_SELETOR = 0x0101
local WM_SYSKEYUP_SELETOR = 0x0105

local function setor_onWindowMessage(msg, wparam, lparam)
    if seletorJogadorAberto.v then
        local ehKeyDown = (msg == WM_KEYDOWN_SELETOR or msg == WM_SYSKEYDOWN_SELETOR)
        local ehKeyUp = (msg == WM_KEYUP_SELETOR or msg == WM_SYSKEYUP_SELETOR)

        local teclaSeletor =
            wparam == VK_ESCAPE_SELETOR or
            wparam == VK_RETURN_SELETOR or
            wparam == VK_UP or
            wparam == VK_DOWN or
            wparam == VK_LEFT or
            wparam == VK_RIGHT

        if teclaSeletor and (ehKeyDown or ehKeyUp) then
            if ehKeyDown then
                if wparam == VK_UP then seletorPressUp = true end
                if wparam == VK_DOWN then seletorPressDown = true end
                if wparam == VK_RETURN_SELETOR then seletorPressEnter = true end
                if wparam == VK_ESCAPE_SELETOR then seletorPressEsc = true end
            end

            -- Consome a tecla para o personagem nao andar/nem abrir o menu do GTA.
            if consumeWindowMessage then
                consumeWindowMessage(true, true)
            end
            return false
        end
    end
end

local function comandoUsaAlvoOnline(nomeCmd)
    nomeCmd = tostring(nomeCmd or ""):lower()
    return ({
        tv = true,
        ir = true,
        trazer = true,
        tapa = true,
        reviver = true,
        congelar = true,
        descongelar = true,
        prenderarmas = true,
        checar = true,
        checarjogador = true,
        checkar = true,
        info = true,
        spec = true,
        setvida = true,
        setcolete = true,
        stt = true
    })[nomeCmd] == true
end

local function sincronizarRGSelecionadoComTAB(rg, nick, idAtual)
    rg = tostring(rg or ""):gsub("%D", "")
    nick = tostring(nick or "")

    if rg == "" then return nil end

    local idNum = tonumber(idAtual)
    if idNum and sampIsPlayerConnected(idNum) then
        rgCache[idNum] = rg
        salvarRGNoBanco(rg, nick ~= "" and nick or (sampGetPlayerNickname(idNum) or "Desconhecido"), idNum)
        return idNum
    end

    if nick == "" or nick == "Desconhecido" then return nil end

    local encontrados = buscarJogadoresOnlinePorNomeOuID(nick)
    local escolhido = nil

    if #encontrados == 1 then
        escolhido = encontrados[1]
    elseif #encontrados > 1 then
        local nickCompacto = compactarBuscaNome(nick)
        for _, jogador in ipairs(encontrados) do
            if compactarBuscaNome(jogador.nick or "") == nickCompacto then
                escolhido = jogador
                break
            end
        end
    end

    if escolhido and escolhido.id and sampIsPlayerConnected(tonumber(escolhido.id)) then
        local pid = tonumber(escolhido.id)
        local nickOnline = escolhido.nick or nick
        rgCache[pid] = rg
        salvarRGNoBanco(rg, nickOnline, pid)
        return pid
    end

    return nil
end

local function executarOpcaoSeletor(p)
    if not p then return end

    local nick = tostring(p.nick or "Desconhecido")
    local rg = resolverRGDaOpcaoJogador(p)
    local id = p.id and tostring(p.id) or nil

    -- Quando o seletor encontra pelo banco de RG, mas o ID atual ainda nao esta
    -- ligado no cache online, reconcilia pela TAB antes de executar o comando.
    if rg and rg ~= "" then
        local idSincronizado = sincronizarRGSelecionadoComTAB(rg, nick, id)
        if idSincronizado then
            id = tostring(idSincronizado)
        end
    end

    if seletorComandoOriginal and seletorComandoOriginal ~= "" then
        local nomeCmd = tostring(seletorComandoOriginal):match("^%s*/(%S+)") or ""
        local cmdLower = nomeCmd:lower()

        -- REGRA HZ:
        -- ID e usado apenas internamente para achar o jogador na TAB.
        -- Para /tv selecionado a partir da TAB, se nao existir um RG ligado com
        -- seguranca ao ID atual, tela pela TAB em vez de usar RG historico do banco.
        if cmdLower == "tv" and id then
            local idNum = tonumber(id)
            local rgSeguro = nil

            if idNum and rgCache[idNum] and tostring(rgCache[idNum]) ~= "" then
                rgSeguro = tostring(rgCache[idNum])
            end

            if not rgSeguro and nick ~= "" then
                local chaveNick = compactarBuscaNome(nick)
                if rgChatPorNick[chaveNick] and tostring(rgChatPorNick[chaveNick]) ~= "" then
                    rgSeguro = tostring(rgChatPorNick[chaveNick])
                end
            end

            if not rgSeguro then
                telarJogadorOnlinePelaTAB(idNum, nick)
                fecharSeletorJogador()
                return
            end

            rg = rgSeguro
        end

        -- O comando final enviado ao servidor usa RG quando existe associacao segura.
        if rg and rg ~= "" then
            if cmdLower == "tv" then
                lastTvRequestedRG = rg
                rgTeladoAtual = rg
                nickPendenteCache = nick
                nickTeladoAtual = nick
            end

            local novoCmd = montarComandoComRG(seletorComandoOriginal, rg)

            if novoCmd then
                sampSendChat(novoCmd)
                sampAddChatMessage(string.format("{00FF7F}Selecionado: %s - RG %s", nick, rg), -1)
            else
                sampAddChatMessage("{FF0000}ERRO: Nao foi possivel montar o comando.", -1)
            end
        else
            -- Para /tv, ainda permitimos telar pela TAB internamente caso o RG ainda nao esteja no cache.
            -- Para qualquer outro comando, nunca envia ID.
            if cmdLower == "tv" and id then
                telarJogadorOnlinePelaTAB(tonumber(id), nick)
                sampAddChatMessage(string.format("{FFFF00}RG ainda nao encontrado no cache. Telando %s pela TAB para capturar o RG.", nick), -1)
            else
                sampAddChatMessage("{FF0000}ERRO: Nao encontrei o RG desse jogador. Aguarde o RG aparecer no chat ou use o RG completo no comando.", -1)
            end
        end
    else
        if rg and rg ~= "" then
            sampAddChatMessage(string.format("{00FF7F}Selecionado: %s - RG %s", nick, rg), -1)
        else
            sampAddChatMessage(string.format("{FFFF00}Selecionado: %s, mas RG ainda nao encontrado no cache.", nick), -1)
        end
    end

    fecharSeletorJogador()
end


-- ============================================================
-- TEMA VISUAL HORIZONTE - APENAS DESIGN
-- Nao altera logica, comandos, cache, TV ou webhooks.
-- ============================================================
local UI_HZ = {
    bg        = imgui.ImVec4(0.025, 0.035, 0.055, 1.00),
    bg2       = imgui.ImVec4(0.045, 0.065, 0.095, 1.00),
    panel     = imgui.ImVec4(0.055, 0.080, 0.115, 1.00),
    card      = imgui.ImVec4(0.065, 0.095, 0.140, 1.00),
    cardHover = imgui.ImVec4(0.03, 0.25, 0.36, 0.82),
    primary   = imgui.ImVec4(0.02, 0.25, 0.37, 0.78),
    primary2  = imgui.ImVec4(0.08, 0.48, 0.68, 0.86),
    glow      = imgui.ImVec4(0.20, 0.65, 0.86, 0.90),
    danger    = imgui.ImVec4(0.78, 0.12, 0.18, 0.95),
    text      = imgui.ImVec4(0.95, 0.97, 1.00, 1.00),
    muted     = imgui.ImVec4(0.66, 0.71, 0.78, 1.00),
    green     = imgui.ImVec4(0.24, 0.86, 0.51, 1.00),
}

local function uiPushColor(col, color)
    if imgui.PushStyleColor and col and color then
        imgui.PushStyleColor(col, color)
        return 1
    end
    return 0
end

local function uiPopColor(n)
    if imgui.PopStyleColor and n and n > 0 then
        imgui.PopStyleColor(n)
    end
end

local function uiPushVar(var, value)
    if imgui.PushStyleVar and var and value then
        imgui.PushStyleVar(var, value)
        return 1
    end
    return 0
end

local function uiPopVar(n)
    if imgui.PopStyleVar and n and n > 0 then
        imgui.PopStyleVar(n)
    end
end

local function uiApplyWindowTheme()
    local c, v = 0, 0

    if imgui.Col then
        c = c + uiPushColor(imgui.Col.WindowBg, UI_HZ.bg)
        c = c + uiPushColor(imgui.Col.TitleBg, UI_HZ.bg2)
        c = c + uiPushColor(imgui.Col.TitleBgActive, UI_HZ.primary)
        c = c + uiPushColor(imgui.Col.Border, UI_HZ.glow)
        c = c + uiPushColor(imgui.Col.Separator, UI_HZ.primary)
        c = c + uiPushColor(imgui.Col.Text, UI_HZ.text)
        c = c + uiPushColor(imgui.Col.Button, UI_HZ.card)
        c = c + uiPushColor(imgui.Col.ButtonHovered, UI_HZ.cardHover)
        c = c + uiPushColor(imgui.Col.ButtonActive, UI_HZ.primary)
        c = c + uiPushColor(imgui.Col.Header, UI_HZ.primary)
        c = c + uiPushColor(imgui.Col.HeaderHovered, UI_HZ.primary2)
        c = c + uiPushColor(imgui.Col.HeaderActive, UI_HZ.glow)
    end

    if imgui.StyleVar then
        v = v + uiPushVar(imgui.StyleVar.WindowRounding, 8)
        v = v + uiPushVar(imgui.StyleVar.FrameRounding, 6)
        v = v + uiPushVar(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 7))
        v = v + uiPushVar(imgui.StyleVar.WindowPadding, imgui.ImVec2(12, 12))
    end

    return c, v
end

local function uiEndWindowTheme(c, v)
    uiPopVar(v)
    uiPopColor(c)
end

-- Central de modulos: cada alternancia entra em vigor no mesmo frame e fica salva.
_G.HZModsJanela = _G.HZModsJanela or imgui.ImBool(false)
_G.HZModsPagina = _G.HZModsPagina or "GERAL"
_G.HZModulosUI = {
    { "painel_tv", "PAINEL TV", "Telagem, punicoes e status." },
    { "navegacao_tv", "NAVEGACAO TV", "Atalhos de navegacao pelas setas." },
    { "monitoramento", "MONITORAMENTO", "Alertas e jogadores monitorados." },
    { "atendimento", "ATENDIMENTO", "Cronometro visual de suporte." },
    { "camera_staff", "CAMERA STAFF", "Camera livre e comandos staff." },
    { "automacoes_staff", "AUTOMACOES STAFF", "Rotinas automaticas da staff." }
}

function _G.HZFecharPainelMods()
    salvarConfigSistema(true)
    _G.HZModsJanela.v = false
    imgui.ShowCursor = false

    local painelTvAberto = _G.PainelTVModule and _G.PainelTVModule.isOpen
        and _G.PainelTVModule.isOpen()
    local monitorAberto = _G.HZMonitorPanel and _G.HZMonitorPanel.aberto
        and _G.HZMonitorPanel.aberto.v

    if not painelTvAberto and not monitorAberto and not seletorJogadorAberto.v then
        imgui.Process = false
    end
end

function _G.HZDefinirModulo(id, ativo)
    if not _G.HZTemPermissaoModulo(id) then
        local _, cargoNome = _G.HZNivelCargo(cargoAdmin)
        sampAddChatMessage("{FF6B6B}[MODS] Funcao bloqueada para o cargo " .. cargoNome .. ".", -1)
        return false
    end
    configSistema.modulos[id] = ativo == true

    if id == "painel_tv" and _G.PainelTVModule and _G.PainelTVModule.setEnabled then
        _G.PainelTVModule.setEnabled(ativo)
    elseif id == "navegacao_tv" then
        -- Alternar o modulo nunca inicia a navegacao automaticamente.
        tvNovatosAtivo, tvTodosAtivo = false, false
        if _G.HZResetarNavegacaoTV then _G.HZResetarNavegacaoTV() end
    elseif id == "monitoramento" and not ativo and _G.HZMonitorPanel then
        _G.HZMonitorPanel.aberto.v = false
    elseif id == "atendimento" and not ativo then
        jogadorCaiu = false
    elseif id == "camera_staff" and not ativo and camOn then
        camDisable()
    elseif id == "automacoes_staff" then
        if ativo then
            if startStaffSaciarme then startStaffSaciarme() end
            if startStaffSupport then startStaffSupport(cargoAdmin) end
        else
            if stopStaffSaciarme then stopStaffSaciarme() end
            if stopStaffSupport then stopStaffSupport() end
        end
    end

    salvarConfigSistema(true)
    return true
end

-- Painel seguro para MoonLoader 0.26.x. Usa apenas componentes basicos do ImGui,
-- evitando chamadas de desenho que podem fechar o GTA sem gerar traceback.
function _G.HZDesenharPainelModsCompat()
    if not _G.HZModsJanela.v then return end
    local pushedColors, pushedVars = uiApplyWindowTheme()
    imgui.SetNextWindowSize(imgui.ImVec2(540, 500), imgui.Cond.Always)
    if not _G.HZModsPosCarregada then
        imgui.SetNextWindowPos(imgui.ImVec2(
            tonumber(configSistema.modsX) or 360,
            tonumber(configSistema.modsY) or 180
        ), imgui.Cond.Always)
        _G.HZModsPosCarregada = true
    end
    local flags = 0
    if imgui.WindowFlags then
        if imgui.WindowFlags.NoResize then flags = flags + imgui.WindowFlags.NoResize end
        if imgui.WindowFlags.NoCollapse then flags = flags + imgui.WindowFlags.NoCollapse end
    end
    imgui.Begin("SETOR ADVANCED - MODULOS (COMPATIVEL)", _G.HZModsJanela, flags)
    local pos = imgui.GetWindowPos()
    if pos then
        configSistema.modsX = math.floor(pos.x)
        configSistema.modsY = math.floor(pos.y)
        salvarConfigSistema(false)
    end

    local okId, meuId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local meuNome = okId and tostring(sampGetPlayerNickname(meuId) or "Staff") or "Staff"
    local _, cargoNome = _G.HZNivelCargo(cargoAdmin)
    imgui.TextColored(UI_HZ.glow, "SETOR ADVANCED  |  /MODS")
    imgui.TextColored(UI_HZ.text, meuNome .. "  -  " .. cargoNome)
    imgui.TextColored(UI_HZ.muted, "Modo compativel com MoonLoader 0.26.x")
    imgui.Separator()
    imgui.BeginChild("##mods_compat_lista", imgui.ImVec2(0, 385), true)
    for i, item in ipairs(_G.HZModulosUI) do
        local id, titulo, descricao = item[1], item[2], item[3]
        local valor = imgui.ImBool(_G.HZModuloAtivo(id))
        if imgui.Checkbox(titulo .. "##compat_" .. id, valor) then
            _G.HZDefinirModulo(id, valor.v)
        end
        imgui.SameLine()
        local permitido = _G.HZTemPermissaoModulo(id)
        local estado = permitido and (_G.HZModuloAtivo(id) and "ATIVO" or "DESATIVADO") or "BLOQUEADO"
        imgui.TextColored(_G.HZModuloAtivo(id) and UI_HZ.green or UI_HZ.muted, estado)
        imgui.TextColored(UI_HZ.muted, descricao)
        if i < #_G.HZModulosUI then imgui.Separator() end
    end
    imgui.EndChild()
    if imgui.Button("FECHAR", imgui.ImVec2(150, 32)) then
        _G.HZFecharPainelMods()
    end
    imgui.End()
    uiEndWindowTheme(pushedColors, pushedVars)
    if not _G.HZModsJanela.v then _G.HZFecharPainelMods() end
end

function _G.HZDesenharPainelMods()
    if not _G.HZModsJanela.v then return end
    local versaoMoonLoader = tonumber(getMoonloaderVersion and getMoonloaderVersion() or 26) or 26
    -- Quando disponivel, o painel principal e renderizado exclusivamente pelo
    -- callback do mimgui. Nao desenhar a mesma janela no ImGui antigo.
    if _G.HZMimguiOk and configSistema.modsModoSeguro ~= true and versaoMoonLoader > 26 then
        return
    end
    if configSistema.modsModoSeguro == true or versaoMoonLoader <= 26 or not _G.HZMimguiOk then
        return _G.HZDesenharPainelModsCompat()
    end
    local pushedColors, pushedVars = uiApplyWindowTheme()
    local flags = 0
    if imgui.WindowFlags then
        if imgui.WindowFlags.NoResize then flags = flags + imgui.WindowFlags.NoResize end
        if imgui.WindowFlags.NoCollapse then flags = flags + imgui.WindowFlags.NoCollapse end
        if imgui.WindowFlags.NoTitleBar then flags = flags + imgui.WindowFlags.NoTitleBar end
        if imgui.WindowFlags.NoScrollbar then flags = flags + imgui.WindowFlags.NoScrollbar end
    end

    -- Uma unica janela mantem o design avancado estavel em diferentes PCs/GPU.
    -- Sombras externas com janelas auxiliares causam crash nativo em algumas instalacoes.
    imgui.SetNextWindowSize(imgui.ImVec2(800, 565), imgui.Cond.Always)
    if not _G.HZModsPosCarregada then
        imgui.SetNextWindowPos(imgui.ImVec2(
            tonumber(configSistema.modsX) or 360,
            tonumber(configSistema.modsY) or 180
        ), imgui.Cond.Always)
        _G.HZModsPosCarregada = true
    end
    imgui.Begin("SETOR ADVANCED  |  /MODS", _G.HZModsJanela, flags)
    local modsPos = imgui.GetWindowPos()
    if modsPos and (math.abs((tonumber(configSistema.modsX) or 0) - modsPos.x) > 1
        or math.abs((tonumber(configSistema.modsY) or 0) - modsPos.y) > 1) then
        configSistema.modsX = math.floor(modsPos.x)
        configSistema.modsY = math.floor(modsPos.y)
        salvarConfigSistema(false)
    end
    local headerDL = imgui.GetWindowDrawList()
    local headerMin = imgui.ImVec2(modsPos.x, modsPos.y)
    local headerMax = imgui.ImVec2(modsPos.x + 800, modsPos.y + 54)
    headerDL:AddRectFilledMultiColor(
        headerMin, headerMax,
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.00, 0.34, 0.62, 1.00)),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.00, 0.62, 0.92, 1.00)),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.00, 0.30, 0.55, 1.00)),
        imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.01, 0.12, 0.23, 1.00))
    )
    headerDL:AddText(imgui.ImVec2(modsPos.x + 22, modsPos.y + 12), 0xFFFFFFFF, "SETOR ADVANCED")
    headerDL:AddText(imgui.ImVec2(modsPos.x + 22, modsPos.y + 30), 0xBFFFFFFF, "CENTRAL ADMINISTRATIVA  /MODS")
    headerDL:AddCircleFilled(imgui.ImVec2(modsPos.x + 765, modsPos.y + 27), 15, 0x55203040, 24)
    headerDL:AddText(imgui.ImVec2(modsPos.x + 761, modsPos.y + 19), 0xFFFFFFFF, "X")
    imgui.SetCursorScreenPos(imgui.ImVec2(modsPos.x + 750, modsPos.y + 12))
    if imgui.InvisibleButton("##mods_fechar_topo", imgui.ImVec2(30, 30)) then
        _G.HZFecharPainelMods()
    end
    imgui.SetCursorScreenPos(imgui.ImVec2(modsPos.x + 12, modsPos.y + 66))
    local _, cargoNome = _G.HZNivelCargo(cargoAdmin)
    local okStaffId, staffId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local staffNome = okStaffId and tostring(sampGetPlayerNickname(staffId) or "Staff") or "Staff"

    -- Navegacao lateral no estilo de uma central administrativa.
    imgui.BeginChild("##mods_sidebar", imgui.ImVec2(190, 0), true)
    for _, pagina in ipairs({ "GERAL", "PAINEIS", "FERRAMENTAS" }) do
        local selecionada = _G.HZModsPagina == pagina
        local corBotao = selecionada and UI_HZ.primary or UI_HZ.card
        local pc = uiPushColor(imgui.Col and imgui.Col.Button, corBotao)
        pc = pc + uiPushColor(imgui.Col and imgui.Col.ButtonHovered, UI_HZ.cardHover)
        if imgui.Button((selecionada and ">  " or "   ") .. pagina .. "##pagina_" .. pagina,
            imgui.ImVec2(164, 36)) then
            _G.HZModsPagina = pagina
        end
        uiPopColor(pc)
    end

    -- Perfil fixo no rodape, desenhado sem imagem externa.
    local perfilPos = imgui.GetWindowPos()
    local perfilTam = imgui.GetWindowSize()
    local perfilDL = imgui.GetWindowDrawList()
    local perfilY = perfilPos.y + perfilTam.y - 78
    perfilDL:AddRectFilled(imgui.ImVec2(perfilPos.x + 10, perfilY - 10),
        imgui.ImVec2(perfilPos.x + perfilTam.x - 10, perfilY - 8),
        imgui.ColorConvertFloat4ToU32(UI_HZ.primary), 1, 15)
    perfilDL:AddCircleFilled(imgui.ImVec2(perfilPos.x + 35, perfilY + 25), 23,
        imgui.ColorConvertFloat4ToU32(UI_HZ.primary), 28)
    perfilDL:AddCircleFilled(imgui.ImVec2(perfilPos.x + 35, perfilY + 25), 18,
        imgui.ColorConvertFloat4ToU32(UI_HZ.bg2), 28)
    perfilDL:AddText(imgui.ImVec2(perfilPos.x + 27, perfilY + 17), 0xFFFFFFFF,
        tostring(staffNome):sub(1, 2):upper())
    perfilDL:AddText(imgui.ImVec2(perfilPos.x + 68, perfilY + 7), 0xFFFFFFFF, staffNome)
    perfilDL:AddText(imgui.ImVec2(perfilPos.x + 68, perfilY + 32),
        imgui.ColorConvertFloat4ToU32(UI_HZ.glow), cargoNome)
    imgui.EndChild()

    imgui.SameLine()
    imgui.BeginChild("##mods_conteudo", imgui.ImVec2(0, 0), false)
    imgui.TextColored(UI_HZ.glow, "CENTRAL DE CONTROLE")
    imgui.TextColored(UI_HZ.text, _G.HZModsPagina)
    imgui.TextColored(UI_HZ.muted, "Clique em um cartao para ativar ou desativar a funcao.")
    imgui.Separator()
    imgui.Spacing()

    local itensPagina = {}
    for _, item in ipairs(_G.HZModulosUI) do
        local id = item[1]
        local mostrar = _G.HZModsPagina == "GERAL"
            or (_G.HZModsPagina == "PAINEIS" and
                (id == "painel_tv" or id == "navegacao_tv" or id == "monitoramento" or id == "atendimento"))
            or (_G.HZModsPagina == "FERRAMENTAS" and
                (id == "camera_staff" or id == "automacoes_staff"))
        if mostrar then table.insert(itensPagina, item) end
    end

    for i, item in ipairs(itensPagina) do
        local id, titulo, descricao = item[1], item[2], item[3]
        local permitido = _G.HZTemPermissaoModulo(id)
        local moduloAtivo = _G.HZModuloAtivo(id)
        local statusModulo = permitido and (moduloAtivo and "ATIVO" or "DESATIVADO") or "BLOQUEADO"
        local corCard = moduloAtivo and UI_HZ.primary or (permitido and UI_HZ.card or UI_HZ.bg2)
        local corHover = permitido and UI_HZ.cardHover or UI_HZ.bg2

        local cardPos = imgui.GetCursorScreenPos()
        local cardSize = imgui.ImVec2(270, 99)
        local clicouCard = imgui.InvisibleButton("##acao_" .. id, cardSize)
        local cardHover = imgui.IsItemHovered()
        local dl = imgui.GetWindowDrawList()
        local cardFim = imgui.ImVec2(cardPos.x + cardSize.x, cardPos.y + cardSize.y)
        local cardColor = cardHover and imgui.ImVec4(0.045, 0.22, 0.31, 0.88) or corCard
        dl:AddRectFilled(imgui.ImVec2(cardPos.x + 3, cardPos.y + 5),
            imgui.ImVec2(cardFim.x + 3, cardFim.y + 5), 0x55000000, 10, 15)
        dl:AddRectFilled(cardPos, cardFim, imgui.ColorConvertFloat4ToU32(cardColor), 10, 15)
        dl:AddRectFilled(cardPos, imgui.ImVec2(cardPos.x + 5, cardFim.y),
            imgui.ColorConvertFloat4ToU32(moduloAtivo and UI_HZ.glow or UI_HZ.primary), 10, 5)
        dl:AddCircleFilled(imgui.ImVec2(cardPos.x + 31, cardPos.y + 31), 17,
            imgui.ColorConvertFloat4ToU32(moduloAtivo and UI_HZ.primary2 or UI_HZ.bg2), 24)
        dl:AddText(imgui.ImVec2(cardPos.x + 22, cardPos.y + 23), 0xFFFFFFFF,
            tostring(titulo):sub(1, 2))
        local tituloTam = imgui.CalcTextSize(titulo)
        local statusTam = imgui.CalcTextSize(statusModulo)
        local descricaoTam = imgui.CalcTextSize(descricao)
        dl:AddText(imgui.ImVec2(cardPos.x + (cardSize.x - tituloTam.x) / 2, cardPos.y + 17),
            0xFFFFFFFF, titulo)
        dl:AddText(imgui.ImVec2(cardPos.x + (cardSize.x - statusTam.x) / 2, cardPos.y + 38),
            imgui.ColorConvertFloat4ToU32(moduloAtivo and UI_HZ.green or (permitido and UI_HZ.danger or UI_HZ.muted)),
            statusModulo)
        dl:AddText(imgui.ImVec2(cardPos.x + (cardSize.x - descricaoTam.x) / 2, cardPos.y + 72),
            0xFFB8C3D1, descricao)

        -- Interruptor desenhado, sem imagem ou biblioteca externa.
        local swX, swY = cardPos.x + 211, cardPos.y + 25
        dl:AddRectFilled(imgui.ImVec2(swX, swY), imgui.ImVec2(swX + 42, swY + 22),
            imgui.ColorConvertFloat4ToU32(moduloAtivo and UI_HZ.primary2 or UI_HZ.bg2), 11, 15)
        dl:AddCircleFilled(imgui.ImVec2(swX + (moduloAtivo and 31 or 11), swY + 11), 8,
            0xFFFFFFFF, 20)
        if cardHover then
            dl:AddRect(cardPos, cardFim, imgui.ColorConvertFloat4ToU32(UI_HZ.glow), 10, 15, 1.5)
        end

        if clicouCard then
            if _G.HZDefinirModulo(id, not moduloAtivo) then
                sampAddChatMessage((not moduloAtivo and "{3EDC81}[MODS] Ativado: " or "{FF6B6B}[MODS] Desativado: ") .. titulo, -1)
            end
        end

        if i % 2 == 1 and i < #itensPagina then
            imgui.SameLine()
        elseif i < #itensPagina then
            imgui.Spacing()
        end
    end

    imgui.Separator()
    local fc = uiPushColor(imgui.Col and imgui.Col.Button, UI_HZ.primary)
    fc = fc + uiPushColor(imgui.Col and imgui.Col.ButtonHovered, UI_HZ.primary2)
    local rodapePos = imgui.GetCursorScreenPos()
    if imgui.Button("FECHAR PAINEL", imgui.ImVec2(170, 34)) then
        _G.HZFecharPainelMods()
    end
    uiPopColor(fc)
    local textoSalvamento = "SALVAMENTO AUTOMATICO ATIVO"
    local textoSalvamentoTam = imgui.CalcTextSize(textoSalvamento)
    imgui.GetWindowDrawList():AddText(
        imgui.ImVec2(rodapePos.x + 180, rodapePos.y + (34 - textoSalvamentoTam.y) / 2),
        imgui.ColorConvertFloat4ToU32(UI_HZ.muted),
        textoSalvamento
    )
    imgui.EndChild()
    imgui.End()
    uiEndWindowTheme(pushedColors, pushedVars)

    -- Trata tambem o X nativo da barra da janela.
    if not _G.HZModsJanela.v then _G.HZFecharPainelMods() end
end

-- Painel /mods moderno. Usa somente widgets oficiais do mimgui para evitar as
-- chamadas de DrawList do ImGui antigo que fechavam o SA-MP em alguns PCs.
function _G.HZDesenharPainelModsMimgui()
    if not _G.HZMimguiOk or not _G.HZModsJanela.v then return end
    local mi = _G.HZMimgui
    local flags = mi.WindowFlags.NoResize + mi.WindowFlags.NoCollapse
    mi.SetNextWindowSize(mi.ImVec2(760, 520), mi.Cond.Always)
    if not _G.HZModsPosCarregadaMimgui then
        mi.SetNextWindowPos(mi.ImVec2(
            tonumber(configSistema.modsX) or 360,
            tonumber(configSistema.modsY) or 180
        ), mi.Cond.Always)
        _G.HZModsPosCarregadaMimgui = true
    end

    -- mimgui 1.7.x separa variantes float e ImVec2 desta funcao.
    mi.PushStyleVarFloat(mi.StyleVar.WindowRounding, 10)
    mi.PushStyleVarFloat(mi.StyleVar.FrameRounding, 7)
    mi.PushStyleVarVec2(mi.StyleVar.ItemSpacing, mi.ImVec2(9, 8))
    mi.PushStyleColor(mi.Col.WindowBg, mi.ImVec4(0.015, 0.025, 0.045, 0.98))
    mi.PushStyleColor(mi.Col.ChildBg, mi.ImVec4(0.025, 0.045, 0.075, 0.96))
    mi.PushStyleColor(mi.Col.Border, mi.ImVec4(0.08, 0.55, 0.78, 0.65))
    mi.PushStyleColor(mi.Col.Button, mi.ImVec4(0.025, 0.20, 0.31, 0.92))
    mi.PushStyleColor(mi.Col.ButtonHovered, mi.ImVec4(0.03, 0.38, 0.56, 1.00))
    mi.PushStyleColor(mi.Col.ButtonActive, mi.ImVec4(0.02, 0.52, 0.76, 1.00))

    mi.Begin("SETOR ADVANCED  |  /MODS##mimgui", nil, flags)
    local pos = mi.GetWindowPos()
    if pos and (math.abs((tonumber(configSistema.modsX) or 0) - pos.x) > 1
        or math.abs((tonumber(configSistema.modsY) or 0) - pos.y) > 1) then
        configSistema.modsX = math.floor(pos.x)
        configSistema.modsY = math.floor(pos.y)
        salvarConfigSistema(false)
    end

    mi.TextColored(mi.ImVec4(0.15, 0.72, 1.00, 1.00), "SETOR ADVANCED")
    mi.SameLine()
    mi.TextColored(mi.ImVec4(0.62, 0.70, 0.80, 1.00), "CENTRAL ADMINISTRATIVA")
    mi.Separator()

    mi.BeginChild("##mods_mi_sidebar", mi.ImVec2(180, 420), true)
    for _, pagina in ipairs({ "GERAL", "PAINEIS", "FERRAMENTAS" }) do
        local paginaSelecionada = _G.HZModsPagina == pagina
        if paginaSelecionada then
            mi.PushStyleColor(mi.Col.Button, mi.ImVec4(0.02, 0.48, 0.70, 1.00))
        end
        if mi.Button((paginaSelecionada and ">  " or "   ") .. pagina .. "##mi_" .. pagina,
            mi.ImVec2(155, 38)) then
            _G.HZModsPagina = pagina
        end
        if paginaSelecionada then mi.PopStyleColor() end
    end
    mi.Spacing()
    mi.Separator()
    local okStaffId, staffId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local staffNome = okStaffId and tostring(sampGetPlayerNickname(staffId) or "Staff") or "Staff"
    local _, cargoNome = _G.HZNivelCargo(cargoAdmin)
    mi.TextColored(mi.ImVec4(0.62, 0.70, 0.80, 1.00), "STAFF")
    mi.Text(staffNome)
    mi.TextColored(mi.ImVec4(0.15, 0.72, 1.00, 1.00), cargoNome)
    mi.EndChild()

    mi.SameLine()
    mi.BeginChild("##mods_mi_conteudo", mi.ImVec2(0, 420), true)
    mi.TextColored(mi.ImVec4(0.15, 0.72, 1.00, 1.00), "CENTRAL DE CONTROLE")
    mi.Text(_G.HZModsPagina)
    mi.TextColored(mi.ImVec4(0.62, 0.70, 0.80, 1.00),
        "Clique no cartao para ativar ou desativar a funcao.")
    mi.Separator()

    local visiveis = {}
    for _, item in ipairs(_G.HZModulosUI) do
        local id = item[1]
        if _G.HZModsPagina == "GERAL"
            or (_G.HZModsPagina == "PAINEIS" and
                (id == "painel_tv" or id == "navegacao_tv" or id == "monitoramento" or id == "atendimento"))
            or (_G.HZModsPagina == "FERRAMENTAS" and
                (id == "camera_staff" or id == "automacoes_staff")) then
            visiveis[#visiveis + 1] = item
        end
    end

    for i, item in ipairs(visiveis) do
        local id, titulo, descricao = item[1], item[2], item[3]
        local permitido = _G.HZTemPermissaoModulo(id)
        local ativo = _G.HZModuloAtivo(id)
        if ativo then
            mi.PushStyleColor(mi.Col.Button, mi.ImVec4(0.025, 0.28, 0.40, 0.96))
        elseif not permitido then
            mi.PushStyleColor(mi.Col.Button, mi.ImVec4(0.07, 0.08, 0.11, 0.92))
        end
        local estado = permitido and (ativo and "ATIVO" or "DESATIVADO") or "BLOQUEADO"
        local texto = titulo .. "\n" .. estado .. "\n" .. descricao .. "##mi_card_" .. id
        if mi.Button(texto, mi.ImVec2(258, 92)) and permitido then
            if _G.HZDefinirModulo(id, not ativo) then
                sampAddChatMessage((not ativo and "{3EDC81}[MODS] Ativado: " or
                    "{FF6B6B}[MODS] Desativado: ") .. titulo, -1)
            end
        end
        if ativo or not permitido then mi.PopStyleColor() end
        if i % 2 == 1 and i < #visiveis then mi.SameLine() end
    end
    mi.EndChild()

    if mi.Button("FECHAR PAINEL", mi.ImVec2(180, 35)) then
        _G.HZFecharPainelMods()
    end
    mi.SameLine()
    mi.TextColored(mi.ImVec4(0.48, 0.58, 0.70, 1.00), "SALVAMENTO AUTOMATICO ATIVO  |  MIMGUI")
    mi.End()
    mi.PopStyleColor(6)
    mi.PopStyleVar(3)
end

if _G.HZMimguiOk then
    _G.HZMimgui.OnFrame(
        function()
            local versaoMoonLoader = tonumber(getMoonloaderVersion and getMoonloaderVersion() or 26) or 26
            return _G.HZModsJanela.v and configSistema.modsModoSeguro ~= true and versaoMoonLoader > 26
        end,
        function()
            local okPainel, erroPainel = pcall(_G.HZDesenharPainelModsMimgui)
            if not okPainel then
                configSistema.modsModoSeguro = true
                _G.HZModsJanela.v = false
                salvarConfigSistema(true)
                print("[SETOR /MODS] Falha no mimgui: " .. tostring(erroPainel))
                sampAddChatMessage("{FFC857}[MODS] Falha visual detectada. Modo seguro ativado; use /mods novamente.", -1)
            end
        end
    )
end

local function uiTextColor(color, txt)
    if imgui.TextColored then
        imgui.TextColored(color, txt)
    else
        imgui.Text(txt)
    end
end

local function uiPlayerButton(label, selected)
    local pushed = 0

    if selected then
        if imgui.Col then
            pushed = pushed + uiPushColor(imgui.Col.Button, UI_HZ.primary)
            pushed = pushed + uiPushColor(imgui.Col.ButtonHovered, UI_HZ.primary2)
            pushed = pushed + uiPushColor(imgui.Col.ButtonActive, UI_HZ.glow)
        end
    end

    local clicked = imgui.Button(label, imgui.ImVec2(405, 32))
    uiPopColor(pushed)
    return clicked
end



-- ============================================================
-- PAINEL DE MONITORADOS - JANELA INDEPENDENTE E ESTAVEL
-- Reutiliza o tema visual do seletor sem alterar sua logica.
-- ============================================================
_G.HZMonitorPanel = _G.HZMonitorPanel or {
    aberto = imgui.ImBool(false),
    busca = imgui.ImBuffer(64),
    posCarregada = false,
    x = 780,
    y = 220,
    ultimaPosX = nil,
    ultimaPosY = nil
}

function _G.HZMonitorPanel.abrir()
    _G.HZMonitorEtapa1.carregar()
    _G.HZMonitorPanel.aberto.v = true
    _G.HZMonitorPanel.x = tonumber(configSistema.monitoradosX) or 780
    _G.HZMonitorPanel.y = tonumber(configSistema.monitoradosY) or 220
    _G.HZMonitorPanel.posCarregada = false
    imgui.Process = true
end

-- Fecha a lista e devolve corretamente o controle do mouse ao jogo.
function _G.HZMonitorPanel.fechar()
    if _G.HZMonitorPanel.x ~= nil and _G.HZMonitorPanel.y ~= nil then
        configSistema.monitoradosX = math.floor(tonumber(_G.HZMonitorPanel.x) or 780)
        configSistema.monitoradosY = math.floor(tonumber(_G.HZMonitorPanel.y) or 220)
        salvarConfigSistema(true)
    end

    _G.HZMonitorPanel.aberto.v = false
    _G.HZMonitorPanel.posCarregada = false

    -- Mantém o ImGui ativo somente se outro painel que depende dele estiver aberto.
    if not seletorJogadorAberto.v then
        imgui.Process = false
    end
end

function _G.HZMonitorPanel.encontrarOnline(info)
    local nickBusca = normalizarBuscaNome(tostring((info and info.nick) or ""))
    if nickBusca == "" or nickBusca == "desconhecido" then return nil, nil, nil end

    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then
            local nick = sampGetPlayerNickname(id) or ""
            if normalizarBuscaNome(nick) == nickBusca then
                local level = sampGetPlayerScore and (sampGetPlayerScore(id) or 0) or 0
                return id, nick, level
            end
        end
    end
    return nil, nil, nil
end

function _G.HZMonitorPanel.remover(rg)
    rg = tostring(rg or "")
    local antigo = _G.HZMonitorEtapa1.dados[rg]
    if not antigo then return end
    _G.HZMonitorEtapa1.dados[rg] = nil
    if _G.HZMonitorEtapa1.salvar() then
        sampAddChatMessage(string.format("{00FF7F}[MONITOR] %s [RG %s] removido.", tostring(antigo.nick or "Desconhecido"), rg), -1)
    end
end

function _G.HZMonitorPanel.copiarTelagem(rg, info, nickExibido)
    rg = tostring(rg or "")
    info = type(info) == "table" and info or {}

    local nome = tostring(nickExibido or info.nick or "Desconhecido")
    local motivo = tostring(info.motivo or "Nao informado")
    local texto = "Nome: " .. nome .. "\r\nRG: " .. rg .. "\r\nMotivo: " .. motivo

    local copiado = false

    if type(setClipboardText) == "function" then
        copiado = pcall(setClipboardText, texto)
    end

    if not copiado and imgui and type(imgui.SetClipboardText) == "function" then
        copiado = pcall(imgui.SetClipboardText, texto)
    end

    if copiado then
        sampAddChatMessage(string.format("{00FF7F}[MONITOR] Dados de telagem de %s copiados.", nome), -1)
    else
        sampAddChatMessage("{FF0000}[MONITOR] Nao foi possivel copiar para a area de transferencia.", -1)
    end
end

function _G.HZMonitorPanel.desenhar()
    if not _G.HZMonitorPanel.aberto.v then return end

    local pushedColors, pushedVars = uiApplyWindowTheme()
    imgui.SetNextWindowSize(imgui.ImVec2(455, 425), imgui.Cond.Always)
    if not _G.HZMonitorPanel.posCarregada then
        imgui.SetNextWindowPos(imgui.ImVec2(_G.HZMonitorPanel.x, _G.HZMonitorPanel.y), imgui.Cond.Always)
        _G.HZMonitorPanel.posCarregada = true
    end

    local flags = 0
    if imgui.WindowFlags then
        if imgui.WindowFlags.NoResize then flags = flags + imgui.WindowFlags.NoResize end
        if imgui.WindowFlags.NoScrollbar then flags = flags + imgui.WindowFlags.NoScrollbar end
        -- Evita o bug do mouse preso ao recolher/minimizar a janela.
        if imgui.WindowFlags.NoCollapse then flags = flags + imgui.WindowFlags.NoCollapse end
    end

    imgui.Begin("SETOR SEGURANCA - MONITORADOS", _G.HZMonitorPanel.aberto, flags)
    local pos = imgui.GetWindowPos()
    if pos then
        _G.HZMonitorPanel.x, _G.HZMonitorPanel.y = pos.x, pos.y
        if _G.HZMonitorPanel.ultimaPosX == nil
        or math.abs(_G.HZMonitorPanel.ultimaPosX - pos.x) > 1
        or math.abs(_G.HZMonitorPanel.ultimaPosY - pos.y) > 1 then
            _G.HZMonitorPanel.ultimaPosX = pos.x
            _G.HZMonitorPanel.ultimaPosY = pos.y
            configSistema.monitoradosX = math.floor(pos.x)
            configSistema.monitoradosY = math.floor(pos.y)
            salvarConfigSistema(false)
        end
    end

    uiTextColor(UI_HZ.glow, "HORIZONTE ROLEPLAY  |  SETOR SEGURANCA")
    uiTextColor(UI_HZ.muted, "JOGADORES MONITORADOS")
    imgui.Separator()

    imgui.PushItemWidth(-1)
    imgui.InputText("##monitor_busca", _G.HZMonitorPanel.busca)
    imgui.PopItemWidth()
    uiTextColor(UI_HZ.muted, "Pesquisar por nick, RG ou motivo")
    imgui.Separator()

    local filtro = normalizarBuscaNome(_G.HZMonitorPanel.busca.v or "")
    local lista = {}
    for rg, info in pairs(_G.HZMonitorEtapa1.dados or {}) do
        if type(info) == "table" then
            local texto = normalizarBuscaNome(tostring(info.nick or "") .. " " .. tostring(rg) .. " " .. tostring(info.motivo or ""))
            if filtro == "" or texto:find(filtro, 1, true) then
                lista[#lista + 1] = { rg = tostring(rg), info = info }
            end
        end
    end
    table.sort(lista, function(a, b) return tostring(a.info.nick or ""):lower() < tostring(b.info.nick or ""):lower() end)

    uiTextColor(UI_HZ.primary2, "MONITORADOS ENCONTRADOS: " .. tostring(#lista))
    imgui.BeginChild("##monitorados_scroll", imgui.ImVec2(0, 270), true)

    if #lista == 0 then
        uiTextColor(UI_HZ.danger, "Nenhum jogador monitorado encontrado.")
    else
        for i, item in ipairs(lista) do
            local rg, info = item.rg, item.info
            local idOnline, nickOnline, levelOnline = _G.HZMonitorPanel.encontrarOnline(info)
            local nick = nickOnline or tostring(info.nick or "Desconhecido")
            local status = idOnline and "ONLINE" or "OFFLINE"

            uiTextColor(idOnline and UI_HZ.green or UI_HZ.muted, nick .. "  |  " .. status)
            uiTextColor(UI_HZ.primary2, "RG: " .. rg .. (idOnline and ("  |  ID: " .. tostring(idOnline) .. "  |  LV: " .. tostring(levelOnline)) or ""))
            uiTextColor(UI_HZ.muted, "Motivo: " .. tostring(info.motivo or "Nao informado"))

            if idOnline then
                if imgui.Button("TV##mon_tv_" .. i, imgui.ImVec2(85, 28)) then sampSendChat("/tv " .. rg) end
                imgui.SameLine()
                if imgui.Button("IR##mon_ir_" .. i, imgui.ImVec2(85, 28)) then sampSendChat("/ir " .. rg) end
                imgui.SameLine()
            end

            local larguraAcao = idOnline and 105 or 205

            if imgui.Button("TELAGEM##mon_copy_" .. i, imgui.ImVec2(larguraAcao, 28)) then
                _G.HZMonitorPanel.copiarTelagem(rg, info, nick)
            end
            imgui.SameLine()

            local pushedRemove = 0
            if imgui.Col then
                pushedRemove = pushedRemove + uiPushColor(imgui.Col.Button, UI_HZ.danger)
                pushedRemove = pushedRemove + uiPushColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.20, 0.26, 1.00))
                pushedRemove = pushedRemove + uiPushColor(imgui.Col.ButtonActive, imgui.ImVec4(0.65, 0.08, 0.12, 1.00))
            end
            if imgui.Button("REMOVER##mon_rm_" .. i, imgui.ImVec2(larguraAcao, 28)) then
                _G.HZMonitorPanel.remover(rg)
            end
            uiPopColor(pushedRemove)
            imgui.Separator()
        end
    end

    imgui.EndChild()
    if imgui.Button("FECHAR", imgui.ImVec2(140, 30)) then
        _G.HZMonitorPanel.fechar()
    end

    imgui.End()
    uiEndWindowTheme(pushedColors, pushedVars)

    -- Também trata o X nativo da barra de título.
    if not _G.HZMonitorPanel.aberto.v then
        _G.HZMonitorPanel.fechar()
    end
end

local function setor_OnDrawFrame()
    _G.HZDesenharPainelMods()

    if seletorJogadorAberto.v then
        local pushedColors, pushedVars = uiApplyWindowTheme()

        imgui.SetNextWindowSize(imgui.ImVec2(455, 425), imgui.Cond.Always)

        if not seletorPosCarregada then
            imgui.SetNextWindowPos(imgui.ImVec2(tonumber(configSistema.seletorX) or 300, tonumber(configSistema.seletorY) or 220), imgui.Cond.Always)
            seletorPosCarregada = true
        end

        local seletorFlags = 0
        if imgui.WindowFlags then
            if imgui.WindowFlags.NoResize then seletorFlags = seletorFlags + imgui.WindowFlags.NoResize end
            if imgui.WindowFlags.NoScrollbar then seletorFlags = seletorFlags + imgui.WindowFlags.NoScrollbar end
            if imgui.WindowFlags.NoScrollWithMouse then seletorFlags = seletorFlags + imgui.WindowFlags.NoScrollWithMouse end
        end

        imgui.Begin("SETOR SEGURANCA - PLAYER SELECT", seletorJogadorAberto, seletorFlags)

        do
            local pos = imgui.GetWindowPos()
            if pos and (math.abs((tonumber(configSistema.seletorX) or 0) - pos.x) > 1 or math.abs((tonumber(configSistema.seletorY) or 0) - pos.y) > 1) then
                configSistema.seletorX = math.floor(pos.x)
                configSistema.seletorY = math.floor(pos.y)
                salvarConfigSistema(false)
            end
        end

        uiTextColor(UI_HZ.glow, "HORIZONTE ROLEPLAY  |  SETOR SEGURANCA")
        uiTextColor(UI_HZ.muted, "Alvo: " .. tostring(seletorJogadorBusca or "") .. "    Comando: " .. tostring(seletorComandoOriginal or "-"))
        imgui.Separator()

        local total = #seletorJogadorOpcoes
        local navegouSeta = false

        if total > 0 then
            if seletorJogadorIndice < 1 then seletorJogadorIndice = 1 end
            if seletorJogadorIndice > total then seletorJogadorIndice = total end

            if seletorPressUp or wasKeyPressed(VK_UP) then
                seletorPressUp = false
                seletorJogadorIndice = seletorJogadorIndice - 1
                if seletorJogadorIndice < 1 then seletorJogadorIndice = total end
                navegouSeta = true
            elseif seletorPressDown or wasKeyPressed(VK_DOWN) then
                seletorPressDown = false
                seletorJogadorIndice = seletorJogadorIndice + 1
                if seletorJogadorIndice > total then seletorJogadorIndice = 1 end
                navegouSeta = true
            elseif seletorPressEnter or wasKeyPressed(VK_RETURN_SELETOR) then
                seletorPressEnter = false
                executarOpcaoSeletor(seletorJogadorOpcoes[seletorJogadorIndice])
                imgui.End()
                uiEndWindowTheme(pushedColors, pushedVars)
                return
            elseif seletorPressEsc or wasKeyPressed(VK_ESCAPE_SELETOR) then
                seletorPressEsc = false
                fecharSeletorJogador()
                imgui.End()
                uiEndWindowTheme(pushedColors, pushedVars)
                return
            end
        end

        if total == 0 then
            uiTextColor(UI_HZ.danger, "Nenhuma opcao disponivel.")
        else
            uiTextColor(UI_HZ.primary2, "RESULTADOS ENCONTRADOS: " .. tostring(total))
            uiTextColor(UI_HZ.muted, "Use [UP/DOWN] navegar  |  [ENTER] selecionar  |  [ESC] cancelar")
            imgui.Separator()

            -- Lista com rolagem própria. Quando navegar pelas setas, a janela acompanha o item selecionado.
            imgui.BeginChild("##lista_jogadores_scroll", imgui.ImVec2(0, 235), true)

            for i, p in ipairs(seletorJogadorOpcoes) do
                local nick = tostring(p.nick or "Desconhecido")
                local rg = p.rg and tostring(p.rg) or nil
                local id = p.id and tostring(p.id) or nil
                local level = p.score and tostring(p.score) or "?"
                local alvoFinal = rg or id or ""
                local origem = rg and "RG" or "ID"
                local selected = (i == seletorJogadorIndice)

                local prefix = selected and ">> " or "   "
                local status = id and "ONLINE" or "CACHE"
                local label = string.format("%s%s    | %s %s    | LV %s    | %s##sel_%d", prefix, nick, origem, alvoFinal, level, status, i)

                if uiPlayerButton(label, selected) then
                    seletorJogadorIndice = i
                    executarOpcaoSeletor(p)
                    imgui.EndChild()
                    imgui.End()
                    uiEndWindowTheme(pushedColors, pushedVars)
                    return
                end

                if selected and navegouSeta and imgui.SetScrollHere then
                    imgui.SetScrollHere(0.50)
                end
            end

            imgui.EndChild()
        end

        imgui.Separator()

        local pushedCancel = 0
        if imgui.Col then
            pushedCancel = pushedCancel + uiPushColor(imgui.Col.Button, UI_HZ.danger)
            pushedCancel = pushedCancel + uiPushColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.20, 0.26, 1.00))
            pushedCancel = pushedCancel + uiPushColor(imgui.Col.ButtonActive, imgui.ImVec4(0.65, 0.08, 0.12, 1.00))
        end

        if imgui.Button("CANCELAR", imgui.ImVec2(140, 30)) then
            fecharSeletorJogador()
        end

        uiPopColor(pushedCancel)

        imgui.End()
        uiEndWindowTheme(pushedColors, pushedVars)
    end
end

-- ============================================================
-- MAIN - INICIALIZAÇÃO DO SISTEMA INTEGRADO
-- ============================================================
local function setor_main()
    while not isSampAvailable() do wait(100) end

    sampRegisterChatCommand("setorversao", function()
        sampAddChatMessage("{48C6FF}[SETOR UPDATE]: Versao PC instalada: " .. _G.HZUpdaterPC.versao, -1)
        _G.HZUpdaterPC.verificar(false)
    end)

    sampRegisterChatCommand("setoratualizar", function()
        _G.HZUpdaterPC.instalar()
    end)

    lua_thread.create(function()
        wait(5000)
        _G.HZUpdaterPC.verificar(true)
    end)
    
    -- Inicialização do Sistema Integrado
    fonteTitulo = renderCreateFont("Arial", 10, 5) 
    fontePrincipal = renderCreateFont("Arial", 10, 4)
    fonteAvisoSaida = renderCreateFont("Arial", 9, 5)
    font = renderCreateFont("Arial", 16, 5)
    carregarCacheRG()
    carregarConfigSistema()
    _G.HZMonitorEtapa1.carregar()
    sampAddChatMessage(
        "{00FF00}[SETOR] Versao " .. tostring(_G.HZUpdaterPC.versao) .. " Ativa! Desenvolvido por Respected",
        -1
    )

    sampRegisterChatCommand("mods", function()
        if not _G.HZStaffLogada then
            _G.HZFecharPainelMods()
            sampAddChatMessage("{FF6B6B}[MODS] Entre na staff para acessar os modulos.", -1)
            return
        end
        if _G.HZModsJanela.v then
            _G.HZFecharPainelMods()
        else
            _G.HZModsJanela.v = true
            imgui.Process = true
        end
        if _G.HZModsJanela.v and not _G.HZMimguiOk and configSistema.modsModoSeguro ~= true then
            sampAddChatMessage("{FFC857}[MODS] mimgui nao encontrado. Painel compativel ativado.", -1)
            sampAddChatMessage("{A8B5C8}[MODS] Instale o mimgui para usar o novo design.", -1)
        end
        sampAddChatMessage(_G.HZModsJanela.v and "{48C6FF}[MODS] Central de modulos aberta." or "{A8B5C8}[MODS] Central de modulos fechada.", -1)
    end)

    sampRegisterChatCommand("modsseguro", function()
        configSistema.modsModoSeguro = not (configSistema.modsModoSeguro == true)
        _G.HZFecharPainelMods()
        salvarConfigSistema(true)
        if configSistema.modsModoSeguro then
            sampAddChatMessage("{3EDC81}[MODS] Modo seguro ativado. Agora use /mods.", -1)
        else
            sampAddChatMessage("{48C6FF}[MODS] Painel avancado reativado. Agora use /mods.", -1)
        end
    end)

    -- MUTE (COMANDO DIRETO - SETOR SEGURANÇA)
    sampRegisterChatCommand("mu", function(arg)
        local n, r, d, m = arg:match("^(%S+)%s+(%d+)%s+(%d+)%s+(.+)$")
        if n then
            enviarTudo(n, r, d .. " dias", m, "mutou", WEBHOOKS.MUTE, "MUTE")
        end
    end)

    sampRegisterChatCommand("hz1", function()
        if not _G.HZModuloAtivo("navegacao_tv") then
            sampAddChatMessage("{FF6B6B}[MODS] Navegacao TV esta desligada. Use /mods para ativar.", -1)
            return
        end
        tvNovatosAtivo, tvTodosAtivo = true, true
        if _G.HZResetarNavegacaoTV then _G.HZResetarNavegacaoTV() end
        salvarConfigSistema(true)
        sampAddChatMessage("{00FF00}TV ATIVADA - Novatos (↑/↓) e Todos (→/←).", -1)
    end)

    sampRegisterChatCommand("hz0", function()
        tvNovatosAtivo, tvTodosAtivo = false, false
        if _G.HZResetarNavegacaoTV then _G.HZResetarNavegacaoTV() end
        salvarConfigSistema(true)
        sampAddChatMessage("{FF0000}TV DESATIVADA.", -1)
    end)

    sampRegisterChatCommand("painelpos", function(arg)
        local x, y = tostring(arg or ""):match("^(%d+)%s+(%d+)$")
        if x and y then
            configSistema.painelAtendimentoX = tonumber(x)
            configSistema.painelAtendimentoY = tonumber(y)
            salvarConfigSistema(true)
            sampAddChatMessage(string.format("{00FF7F}Painel de atendimento salvo em X:%s Y:%s.", x, y), -1)
        else
            sampAddChatMessage("{FFFF00}Use: /painelpos X Y  | Exemplo: /painelpos 20 630", -1)
        end
    end)

    sampRegisterChatCommand("painelreset", function()
        configSistema.painelAtendimentoX = 20
        configSistema.painelAtendimentoY = 630
        configSistema.seletorX = 300
        configSistema.seletorY = 220
        configSistema.painelTvX = 20
        configSistema.painelTvY = 220
        configSistema.monitoradosX = 780
        configSistema.monitoradosY = 220
        configSistema.modsX = 360
        configSistema.modsY = 180
        if _G.HZMonitorPanel then
            _G.HZMonitorPanel.x = 780
            _G.HZMonitorPanel.y = 220
            _G.HZMonitorPanel.posCarregada = false
        end
        if _G.PainelTVSetSavedPos then _G.PainelTVSetSavedPos(20, 220) end
        seletorPosCarregada = false
        _G.HZModsPosCarregada = false
        salvarConfigSistema(true)
        sampAddChatMessage("{00FF7F}Posicoes dos paineis resetadas e salvas.", -1)
    end)

    sampRegisterChatCommand("tvhist", function()
        sampAddChatMessage("{00CED1}---- HIST NOVATOS (pos="..histIndexN.."/"..#historicoN..") ----", -1)
        local iniN = math.max(1, #historicoN - 15 + 1)
        for i=iniN,#historicoN do
            local id = historicoN[i]; local mark = (i==histIndexN) and " <" or ""
            local nome = sampGetPlayerNickname(id) or "?"
            local lvl  = sampGetPlayerScore(id) or 0
            local on   = sampIsPlayerConnected(id) and "On" or "Off"
            local rg   = rgCache[id] and (" RG "..rgCache[id]) or ""
            sampAddChatMessage(string.format("{AAAAAA}[%d] %s[%d] L%d%s (%s)%s", i, nome, id, lvl, rg, on, mark), -1)
        end
        sampAddChatMessage("{00CED1}---- HIST TODOS (pos="..histIndexA.."/"..#historicoA..") ----", -1)
        local iniA = math.max(1, #historicoA - 15 + 1)
        for i=iniA,#historicoA do
            local id = historicoA[i]; local mark = (i==histIndexA) and " <" or ""
            local nome = sampGetPlayerNickname(id) or "?"
            local lvl  = sampGetPlayerScore(id) or 0
            local on   = sampIsPlayerConnected(id) and "On" or "Off"
            local rg   = rgCache[id] and (" RG "..rgCache[id]) or ""
            sampAddChatMessage(string.format("{AAAAAA}[%d] %s[%d] L%d%s (%s)%s", i, nome, id, lvl, rg, on, mark), -1)
        end
    end)

    sampRegisterChatCommand("rgcache", function()
        local total = 0
        for _ in pairs(rgDatabase) do total = total + 1 end
        sampAddChatMessage(string.format("{00FF7F}Cache RG carregado: %d registro(s). Arquivo: %s", total, CACHE_PATH), -1)
    end)

    sampRegisterChatCommand("rgdedup", function()
        local mudou = false

        for rg, info in pairs(rgDatabase) do
            if type(info) == "table" and info.nick and info.nick ~= "Desconhecido" then
                if removerNickDuplicadoDeOutrosRGs(rg, info.nick) then
                    mudou = true
                end
            end
        end

        if mudou then salvarCacheRG() end
        sampAddChatMessage("{00FF7F}Cache verificado: nicks duplicados removidos sem apagar RGs validos.", -1)
    end)

    sampRegisterChatCommand("rgdel", function(arg)
        local rg = tostring(arg or ""):gsub("%D", "")

        if rg ~= "" and rgDatabase[rg] then
            rgDatabase[rg] = nil
            salvarCacheRG()
            sampAddChatMessage("{00FF7F}RG " .. rg .. " removido do cache.", -1)
        else
            sampAddChatMessage("{FF0000}Informe um RG existente no cache para remover.", -1)
        end
    end)

    sampRegisterChatCommand("rgatual", function()
        if rgTeladoAtual then
            local info = rgDatabase[rgTeladoAtual]
            local nick = (type(info) == "table" and info.nick) or nickTeladoAtual or "Desconhecido"
            sampAddChatMessage(string.format("{00FF7F}Telado atual: %s - RG %s", nick, rgTeladoAtual), -1)
        else
            sampAddChatMessage("{FF0000}Nenhum RG telado atual foi capturado ainda.", -1)
        end
    end)

    sampRegisterChatCommand("rgnome", function(arg)
        local rg, status = buscarRGPorNomeOuRG(arg)
        if rg then
            local info = rgDatabase[rg]
            local nick = (type(info) == "table" and info.nick) or "Desconhecido"
            sampAddChatMessage(string.format("{00FF7F}Encontrado: %s - RG %s", nick, rg), -1)
        elseif status == "multiple" then
            abrirSeletorJogador(arg, nil)
        end
    end)

    -- MONITORAMENTO STAFF - ETAPA 1
    sampRegisterChatCommand("ass", function(arg)
        if _G.HZModuloAtivo("monitoramento") then _G.HZMonitorEtapa1.monitor(arg) end
    end)
    sampRegisterChatCommand("rss", function(arg)
        if _G.HZModuloAtivo("monitoramento") then _G.HZMonitorEtapa1.desmonitor(arg) end
    end)
    sampRegisterChatCommand("ss", function()
        if _G.HZModuloAtivo("monitoramento") then _G.HZMonitorPanel.abrir() end
    end)

    -- COMANDOS DA CÂMERA STAFF
    sampRegisterChatCommand("hz", function()
        if not _G.HZModuloAtivo("camera_staff") then return end
        if camOn then camDisable() else camEnable(false) end
    end)

    sampRegisterChatCommand("hzstaff", function()
        if not _G.HZModuloAtivo("camera_staff") then return end
        if camOn then camDisable() else camEnable(true) end
    end)

    sampRegisterChatCommand("map", function()
        if not _G.HZModuloAtivo("camera_staff") then return end
        if camOn and not isStaffMode then
            lua_thread.create(stealthTeleportToCam)
        end
    end)

    sampRegisterChatCommand("mapp", function()
        if not _G.HZModuloAtivo("camera_staff") then return end
        if not isStaffMode then
            lua_thread.create(stealthTeleportBack)
        end
    end)

    -- LOOP PRINCIPAL
    while true do
        wait(0)

        -- Processa a captura Nome[RG] na thread principal, após o callback
        -- de rede terminar. Nunca varre a TAB diretamente em onServerMessage.
        if #filaCapturaNomeRG > 0 then
            local item = filaCapturaNomeRG[1]

            if item and os.clock() >= (item.processarEm or 0) then
                table.remove(filaCapturaNomeRG, 1)

                -- Captura passiva desativada temporariamente: algumas builds do
                -- MoonLoader encerram a coroutine ao consultar a TAB nesta fila.
                -- O cache principal por /tv e textdraw continua funcionando.
            end
        end

        if _G.HZModsJanela.v or seletorJogadorAberto.v then
            imgui.Process = true
        end

        -- CONTROLE DE VELOCIDADE DA CÂMERA STAFF
        if _G.HZModuloAtivo("camera_staff") and camOn then
            if wasKeyPressed(0x6B) or wasKeyPressed(0xBB) then
                speedFactor = math.min(speedFactor + SPEED_STEP, MAX_SPEED_FACTOR)
                sampAddChatMessage(string.format("Velocidade +%.1fx (agora: %.1fx)", SPEED_STEP, speedFactor), CAMERA_CHAT_COLOR)
            elseif wasKeyPressed(0x6D) or wasKeyPressed(0xBD) then
                speedFactor = math.max(speedFactor - SPEED_STEP, 0.1)
                sampAddChatMessage(string.format("Velocidade -%.1fx (agora: %.1fx)", SPEED_STEP, speedFactor), CAMERA_CHAT_COLOR)
            end
        end

        if _G.HZModuloAtivo("camera_staff") and isCharDead(PLAYER_PED) and camOn then camDisable() end

        if _G.HZModuloAtivo("camera_staff") and camOn then updateCam() end

        _G.HZAtualizarAutomacoesStaff()

        if _G.HZModuloAtivo("monitoramento") then _G.HZMonitorEtapa1.atualizar() end

        if _G.HZModuloAtivo("navegacao_tv") and tvNovatosAtivo then
            local lstN = getNovatosSorted()
            for _, id in ipairs(lstN) do addToCatalogN(id) end
        end

        if _G.HZModuloAtivo("navegacao_tv") and tvNovatosAtivo and not seletorJogadorAberto.v and upJustPressed() then
            if histIndexN < #historicoN then
                histIndexN = histIndexN + 1
                idAtualN = historicoN[histIndexN]
                if not telarIdN(idAtualN) then
                    local moved=false
                    while histIndexN < #historicoN do
                        histIndexN = histIndexN + 1
                        idAtualN = historicoN[histIndexN]
                        if telarIdN(idAtualN) then moved=true break end
                    end
                    if not moved then
                        local id = pickNextByCycleN()
                        if id then ultimoCicloN=id pushHistoricoN(id) idAtualN=id telarIdN(idAtualN) end
                    end
                end
            else
                local id = pickNextByCycleN()
                if id then ultimoCicloN=id pushHistoricoN(id) idAtualN=id telarIdN(idAtualN) end
            end
        end

        if _G.HZModuloAtivo("navegacao_tv") and tvNovatosAtivo and not seletorJogadorAberto.v and downJustPressed() then
            if histIndexN > 1 then
                local moved=false
                while histIndexN > 1 do
                    histIndexN = histIndexN - 1
                    idAtualN = historicoN[histIndexN]
                    if telarIdN(idAtualN) then moved=true break end
                end
                if not moved then sampAddChatMessage("{FFFF00}NOVATOS: inicio do historico.", -1) end
            else
                sampAddChatMessage("{FFFF00}NOVATOS: sem anterior.", -1)
            end
        end

        if _G.HZModuloAtivo("navegacao_tv") and tvTodosAtivo and not seletorJogadorAberto.v and rightJustPressed() then
            if histIndexA < #historicoA then
                histIndexA = histIndexA + 1
                idAtualA = historicoA[histIndexA]
                if not telarIdA(idAtualA) then
                    local moved=false
                    while histIndexA < #historicoA do
                        histIndexA = histIndexA + 1
                        idAtualA = historicoA[histIndexA]
                        if telarIdA(idAtualA) then moved=true break end
                    end
                    if not moved then
                        local id = pickNextByCycleA()
                        if id then ultimoCicloA=id pushHistoricoA(id) idAtualA=id telarIdA(idAtualA) end
                    end
                end
            else
                local id = pickNextByCycleA()
                if id then ultimoCicloA=id pushHistoricoA(id) idAtualA=id telarIdA(idAtualA) end
            end
        end

        if _G.HZModuloAtivo("navegacao_tv") and tvTodosAtivo and not seletorJogadorAberto.v and leftJustPressed() then
            if histIndexA > 1 then
                local moved=false
                while histIndexA > 1 do
                    histIndexA = histIndexA - 1
                    idAtualA = historicoA[histIndexA]
                    if telarIdA(idAtualA, "{87CEEB}Voltando para ") then moved=true break end
                end
                if not moved then sampAddChatMessage("{FFFF00}TODOS: inicio do historico.", -1) end
            else
                sampAddChatMessage("{FFFF00}TODOS: sem anterior.", -1)
            end
        end

        if _G.HZModuloAtivo("atendimento") and (emAtendimento or jogadorCaiu) then
            desenharPainelVisual()
            if jogadorCaiu and os.time() > tempoExibicaoAviso then 
                jogadorCaiu = false 
            end
        end
    end
end

-- ============================================================
-- FUNÇÕES AUXILIARES DE ENVIO
-- ============================================================

-- Envio simples para webhook (SETOR SEGURANÇA)
-- Logs administrativos comuns desativados para otimizar o painel.
-- Mantemos a função para não quebrar chamadas antigas, mas ela não envia nada.
local function escaparJsonDiscord(valor)
    return tostring(valor or "")
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\r", "\\r")
        :gsub("\n", "\\n")
end

function enviarSimples(webhook, msg)
    if type(webhook) ~= "string" or webhook == "" then
        return false
    end

    local payload = '{"content":"' .. escaparJsonDiscord(msg) .. '"}'

    lua_thread.create(function()
        local ok, resposta = pcall(function()
            return requests.post(webhook, {
                data = payload,
                headers = {["Content-Type"] = "application/json"}
            })
        end)

        if not ok then
            sampAddChatMessage("{FF5555}[SETOR]: Falha ao enviar log para o Discord.", -1)
        end
    end)

    return true
end

-- Envio essencial de punições para Discord
-- Mantido apenas para BAN, BANTEMP, CADEIA/PUNIÇÃO e MUTE.
function enviarTudo(nick, id_ou_rg, tempo, motivo, acao, url, tipoPunicao)
    lua_thread.create(function()
        local dataHora = os.date("%d/%m/%Y - %H:%M:%S")

        local formMsg = string.format("```\\nADM: %s\\nNICK: %s\\nRG: %s\\nTEMPO: %s\\nMOTIVO: %s\\nPROVAS: \\n```",
            nomeAdmin, nick, id_ou_rg, tempo, motivo)

        requests.post(url, {data = '{"content":"['..dataHora..']"}', headers = {["Content-Type"] = "application/json"}})
        wait(700)
        local ok = requests.post(url, {data = '{"content":"'..formMsg..'"}', headers = {["Content-Type"] = "application/json"}})

        if ok then
            sampAddChatMessage("{00FF00}[SISTEMA]: Registro de " .. tipoPunicao .. " enviado!", -1)
        end
    end)
end

-- Envia os logs de /irposto, /ircasa e /irempresa usando exatamente
-- os webhooks e o formato do script oficial do coordenador.
function enviarLogLocal(tipo, id)
    local dH = os.date("%d/%m/%Y - %H:%M:%S")
    local msg
    local webhook

    if tipo == "POSTO" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s Foi Ate o Posto (ID %s)",
            dH, cargoAdmin, nomeAdmin, id)
        webhook = WEBHOOKS.LOG_IRPOSTO
    elseif tipo == "CASA" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s Foi Ate a Casa (ID %s)",
            dH, cargoAdmin, nomeAdmin, id)
        webhook = WEBHOOKS.LOG_IRCASA
    elseif tipo == "EMPRESA" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s Foi Ate a Empresa (ID %s)",
            dH, cargoAdmin, nomeAdmin, id)
        webhook = WEBHOOKS.LOG_IREMPRESA
    else
        return false
    end

    return enviarSimples(webhook, msg)
end

-- ============================================================
-- MONITORAMENTO DE COMANDOS (SETOR SEGURANÇA)
-- ============================================================
local function setor_onSendCommand(cmd)
    local dH = os.date("%d/%m/%Y - %H:%M:%S")

    do
        local cmdLimpo = tostring(cmd or ""):lower():match("^%s*(.-)%s*$")
        if cmdLimpo == "/la" or cmdLimpo:match("^/la%s+")
           or cmdLimpo == "/logaradm" or cmdLimpo:match("^/logaradm%s+") then

            -- Apenas marca que o login administrativo foi solicitado.
            -- O estado do monitor só muda quando o servidor confirmar o login.
            _G.HZMonitorEtapa1.marcarAdminPendente()

        elseif cmdLimpo == "/da"
           or cmdLimpo == "/sairadm"
           or cmdLimpo == "/deslogaradm"
           or cmdLimpo == "/offadm"
           or cmdLimpo == "/sairadmin" then

            -- Encerra completamente a sessão do monitor.
            _G.HZMonitorEtapa1.adminPendenteAte = 0
            _G.HZMonitorEtapa1.adminAtivo = false
            _G.HZMonitorEtapa1.onlinePorRG = {}
            _G.HZMonitorEtapa1.inicializadoOnline = false
            _G.HZMonitorEtapa1.proximaVerificacao = 0

            -- /mods e todos os recursos administrativos ficam bloqueados
            -- imediatamente apos /da, sem depender do texto de resposta do servidor.
            _G.HZStaffLogada = false
            cargoAdmin, nomeAdmin = "Desconhecido", ""
            _G.HZFecharPainelMods()
            if _G.HZMonitorPanel then _G.HZMonitorPanel.aberto.v = false end
            tvNovatosAtivo, tvTodosAtivo = false, false
            stopStaffSaciarme()
            stopStaffSupport()
            if camOn then camDisable() end
            if _G.PainelTVModule and _G.PainelTVModule.setEnabled then
                _G.PainelTVModule.setEnabled(false)
            end

            sampAddChatMessage(
                "{FFFF00}[MONITOR] Modo admin encerrado. Alertas pausados.",
                -1
            )
        end
    end

    if convertendoComandoPainel then
        convertendoComandoPainel = false
        if _G.HZAvisosAC then _G.HZAvisosAC.comando(cmd) end
        return
    end

    -- CORRECAO DO PAINEL POS-ATUALIZACAO:
    -- O painel antigo ainda pode mandar ID curto ou comando sem alvo.
    -- Antes de deixar sair para o servidor, troca pelo RG do jogador telado atual.
    do
        local cmdCorrigidoPainel = corrigirComandoPainelRG(cmd)
        if type(cmdCorrigidoPainel) == "string" and cmdCorrigidoPainel ~= cmd then
            convertendoComandoPainel = true
            sampSendChat(cmdCorrigidoPainel)
            return false
        end
    end

    if _G.HZAvisosAC then _G.HZAvisosAC.comando(cmd) end

    -- Captura /tv com RG ou nome para manter o jogador telado atual
    do
        local alvoTv = cmd:match("^%s*/tv%s+(%S+)")
        if alvoTv then
            local rgTv = buscarRGPorNomeOuRG(alvoTv, true)

            if rgTv then
                lastTvRequestedRG = rgTv
                rgTeladoAtual = rgTv

                if rgDatabase[rgTv] and rgDatabase[rgTv].nick then
                    nickTeladoAtual = rgDatabase[rgTv].nick
                elseif not alvoTv:match("^%d+$") then
                    nickPendenteCache = alvoTv
                    nickTeladoAtual = alvoTv
                end
            elseif not alvoTv:match("^%d+$") then
                -- Guarda o nome digitado para vincular quando o RG aparecer no textdraw.
                nickPendenteCache = alvoTv
                nickTeladoAtual = alvoTv
            end
        end
    end

    -- ============================================================
    -- RESOLVEDOR ESPECIAL DO /STT
    -- Formato: /stt STATUS NOME_OU_RG QUANTIDADE
    -- O alvo fica no segundo argumento, diferente dos demais comandos.
    -- ============================================================
    do
        local statusStt, alvoStt, quantidadeStt =
            tostring(cmd or ""):match("^%s*/stt%s+(%S+)%s+(%S+)%s+(%d+)%s*$")

        if statusStt and alvoStt and quantidadeStt and not alvoStt:match("^%d+$") then
            local encontradosStt = buscarJogadoresOnlinePorNomeOuID(alvoStt)

            if #encontradosStt == 1 then
                local jogador = encontradosStt[1]
                local idJogador = tonumber(jogador.id)
                local nickJogador = tostring(jogador.nick or alvoStt)
                local rgJogador = nil

                if idJogador and rgCache[idJogador] and tostring(rgCache[idJogador]) ~= "" then
                    rgJogador = tostring(rgCache[idJogador])
                end

                if not rgJogador then
                    local chaveNick = compactarBuscaNome(nickJogador)
                    if rgChatPorNick[chaveNick] and tostring(rgChatPorNick[chaveNick]) ~= "" then
                        rgJogador = tostring(rgChatPorNick[chaveNick])
                    end
                end

                if not rgJogador then
                    rgJogador = buscarRGPorNomeOuRG(nickJogador, true)
                end

                if rgJogador and tostring(rgJogador) ~= "" then
                    sampSendChat(
                        "/stt " .. statusStt .. " " .. tostring(rgJogador) .. " " .. quantidadeStt
                    )
                    return false
                end

                -- Mantém o mesmo seletor usado por /ir e /tv.
                seletorJogadorOpcoes = encontradosStt
                abrirSeletorJogador(alvoStt, cmd)
                return false

            elseif #encontradosStt > 1 then
                seletorJogadorOpcoes = encontradosStt
                abrirSeletorJogador(alvoStt, cmd)
                return false
            else
                local rgBanco = buscarRGPorNomeOuRG(alvoStt, true)

                if rgBanco and tostring(rgBanco) ~= "" then
                    sampSendChat(
                        "/stt " .. statusStt .. " " .. tostring(rgBanco) .. " " .. quantidadeStt
                    )
                    return false
                end

                sampAddChatMessage(
                    "{FF0000}[Setor] Nenhum jogador encontrado para /stt: " .. tostring(alvoStt),
                    -1
                )
                return false
            end
        end
    end

    -- ============================================================
    -- RESOLVEDOR NOME -> RG (sem alterar os comandos originais)
    -- Permite usar: /tv nome, /ir nome, /trazer nome, etc.
    -- Se o primeiro argumento ja for numero, mantem o fluxo original.
    -- ============================================================
    do
        local cmdResolvido = resolverPrimeiroArgumentoComoRG(cmd)

        if cmdResolvido == false then
            return false
        elseif type(cmdResolvido) == "string" then
            sampSendChat(cmdResolvido)
            return false
        end
    end

    -- Se algum botao do painel enviar comando sem alvo, usa o RG do telado atual
    do
        local rgAtual = getRGTeladoAtual()
        local cmdSemAlvo = cmd:match("^%s*/(ir|trazer|reviver|congelar|descongelar|prenderarmas|checar)%s*$")
        if cmdSemAlvo and rgAtual then
            sampSendChat("/" .. cmdSemAlvo .. " " .. rgAtual)
            return false
        end

        local qtdVida = cmd:match("^%s*/setvida%s+(%d+)%s*$")
        if qtdVida and rgAtual then
            sampSendChat("/setvida " .. rgAtual .. " " .. qtdVida)
            return false
        end

        local qtdColete = cmd:match("^%s*/setcolete%s+(%d+)%s*$")
        if qtdColete and rgAtual then
            sampSendChat("/setcolete " .. rgAtual .. " " .. qtdColete)
            return false
        end

        local altura = cmd:match("^%s*/tapa%s+(%d+)%s*$")
        if altura and rgAtual then
            sampSendChat("/tapa " .. rgAtual .. " " .. altura)
            return false
        end
    end

    -- ============================================================
    -- COMANDOS DO SETOR SEGURANÇA
    -- ============================================================
    
    -- NOVO /STT (Captura dinâmica de Fome, Sede, Sono, Saude)
    if cmd:find("^/tv%s+(%d+)") then
        local rg = cmd:match("^%s*/tv%s+(%d+)%s*$")
        if rg then
            -- Numero digitado manualmente e sempre RG no HZ, nunca ID.
            lastTvRequestedRG = tostring(rg)
            rgTeladoAtual = tostring(rg)
            lastTvRequestedId = nil
        end
    end

    if cmd:find("^/stt%s+(.+)") then
        local resto = cmd:match("^/stt%s+(.+)")
        local opcoes, rg, qtd = resto:match("(.+)%s+(%d+)%s+(%d+)$")
        if rg and qtd then
            local jNome = getInfoRG(rg)
            local msg = string.format("[%s] HZ-ADMIN: O(a) %s %s Setor [%s] no jogador(a) %s RG: %s quantidade: [%s]", dH, cargoAdmin, nomeAdmin, opcoes, jNome, rg, qtd)
            enviarSimples(WEBHOOKS.LOG_STT, msg)
        end
    end

    -- NOVO /CV (CRIAR VEICULO)
    if cmd:find("^/cv%s+(%d+)") then
        local mod = cmd:match("^/cv%s+(%d+)")
        enviarSimples(WEBHOOKS.LOG_CV, string.format("[%s] HZ-ADMIN: O(a) %s %s criou um veiculo (modelo %s)", dH, cargoAdmin, nomeAdmin, mod))
    end

    -- NOVO /RV (REMOVER VEICULO)
    if cmd:find("^/rv%s+(%d+)") then
        local vid = cmd:match("^/rv%s+(%d+)")
        enviarSimples(WEBHOOKS.LOG_RV, string.format("[%s] HZ-ADMIN: O(a) %s %s removeu o veículo ID: %s", dH, cargoAdmin, nomeAdmin, vid))
    end

    -- NOVO /LC 1 (LIMPAR CHAT)
    if cmd:find("^/lc 1") then
        enviarSimples(WEBHOOKS.LOG_LC, string.format("[%s] HZ-ADMIN: O(a) %s %s limpou o chat de todos os jogadores", dH, cargoAdmin, nomeAdmin))
    end

    -- NOVOS /IRCASA, /IREMPRESA, /IRPOSTO
    -- Mesmo padrão do script oficial enviado pelo coordenador.
    local idPosto = cmd:match("^/irposto%s+(%d+)$")
    if idPosto then
        enviarLogLocal("POSTO", idPosto)
    end

    local idCasa = cmd:match("^/ircasa%s+(%d+)$")
    if idCasa then
        enviarLogLocal("CASA", idCasa)
    end

    local idEmpresa = cmd:match("^/irempresa%s+(%d+)$")
    if idEmpresa then
        enviarLogLocal("EMPRESA", idEmpresa)
    end

    -- COMANDOS ORIGINAIS (TAPA, IR, TRAZER)
    if cmd:find("^/tapa%s+(%d+)%s+(%d+)") then 
        _, v_altura_tapa = cmd:match("^/tapa%s+(%d+)%s+(%d+)") 
        salvarConfigSistema(true)
    end
    
    if cmd:find("^/ir%s+(%d+)") then
        local targetRG = cmd:match("^/ir%s+(%d+)")
        local jNome = getInfoRG(targetRG)
        enviarLogTeleporte("IR", jNome, targetRG)
    end

    if cmd:find("^/trazer%s+(%d+)") then
        local targetRG = cmd:match("^/trazer%s+(%d+)")
        local jNome = getInfoRG(targetRG)
        enviarLogTeleporte("TRAZER", jNome, targetRG)
    end

    -- COMANDOS DE STATUS (SETVIDA, SETCOLETE, REVIVER, CONGELAR, ARMAS)
    if cmd:find("^/setvida%s+(%d+)%s+(%d+)") then
        local rg, q = cmd:match("/setvida%s+(%d+)%s+(%d+)")
        local jNome = getInfoRG(rg)
        enviarLogStatus("VIDA", jNome, rg, q)
    end
    if cmd:find("^/setcolete%s+(%d+)%s+(%d+)") then
        local rg, q = cmd:match("/setcolete%s+(%d+)%s+(%d+)")
        local jNome = getInfoRG(rg)
        enviarLogStatus("COLETE", jNome, rg, q)
    end
    if cmd:find("^/reviver%s+(%d+)") then
        local rg = cmd:match("/reviver%s+(%d+)")
        local jNome = getInfoRG(rg)
        enviarLogStatus("REVIVER", jNome, rg)
    end
    if cmd:find("^/congelar%s+(%d+)") then
        local rg = cmd:match("/congelar%s+(%d+)")
        local jNome = getInfoRG(rg)
        enviarLogStatus("CONGELAR", jNome, rg)
    end
    if cmd:find("^/descongelar%s+(%d+)") then
        local rg = cmd:match("/descongelar%s+(%d+)")
        local jNome = getInfoRG(rg)
        enviarLogStatus("DESCONGELAR", jNome, rg)
    end
    if cmd:find("^/prenderarmas%s+(%d+)") then
        local rg = cmd:match("/prenderarmas%s+(%d+)")
        local jNome = getInfoRG(rg)
        enviarLogStatus("ARMAS", jNome, rg)
    end

    -- FINALIZAR ATENDIMENTO MANUAL
    if cmd == "/fa" and emAtendimento then
        table.insert(historicoConversa, "[" .. os.date("%H:%M:%S") .. "] Atendimento finalizado manualmente.")
        finalizarTudo("Atendimento finalizado pelo atendente " .. nomeAdmin)
    end

    -- COMANDOS ESPECÍFICOS DO SETOR SEGURANÇA
    if cmd:find("^/ban%s+(%d+)%s+(.+)") then
        local rg, motivo = cmd:match("^/ban%s+(%d+)%s+(.+)")
        v_rg, v_tempo, v_motivo, v_tipo = rg, "Permanente", motivo, "BAN"
        aguardandoConfirmacao = true
    elseif cmd:find("^/bantemp%s+(%d+)%s+(%d+)%s+(.+)") then
        local rg, tempo, motivo = cmd:match("^/bantemp%s+(%d+)%s+(%d+)%s+(.+)")
        v_rg, v_tempo, v_motivo, v_tipo = rg, tempo .. " dias", motivo, "BAN"
        aguardandoConfirmacao = true
    elseif cmd:find("^/cadeia%s+(%d+)%s+(%d+)%s+(.+)") or cmd:find("^/punicao%s+(%d+)%s+(%d+)%s+(.+)") then
        local rg, tempo, motivo = cmd:match("/%a+%s+(%d+)%s+(%d+)%s+(.+)")
        v_rg, v_tempo, v_motivo, v_tipo = rg, tempo .. " minutos", motivo, "CADEIA"
        aguardandoConfirmacao = true
    end
end

-- ============================================================
-- CAPTURA PASSIVA NOME[RG] PELO CHAT
-- Salva automaticamente pares como: kaycst_[1003984]
-- ============================================================
-- Fila de mensagens para evitar acessar a pool/TAB dentro do callback de rede.
-- O processamento direto durante onServerMessage pode causar reentrada no
-- SAMPFUNCS (BitStream::Write) durante o login/spawn.
filaCapturaNomeRG = filaCapturaNomeRG or {}

function enfileirarCapturaNomeRG(cleanText)
    if type(cleanText) ~= "string" or cleanText == "" then return end

    filaCapturaNomeRG[#filaCapturaNomeRG + 1] = {
        texto = cleanText,
        processarEm = os.clock() + 0.35
    }

    -- Evita crescimento indefinido em servidores com chat muito movimentado.
    if #filaCapturaNomeRG > 100 then
        table.remove(filaCapturaNomeRG, 1)
    end
end

function _G.HZCapturarParesNomeRGDoChat(cleanText)
    if type(cleanText) ~= "string" then return end

    local ignorar = {
        ["id"] = true,
        ["rg"] = true,
        ["org"] = true,
        ["level"] = true,
        ["lvl"] = true,
        ["modelo"] = true,
        ["veiculo"] = true,
        ["veículo"] = true,
        ["casa"] = true,
        ["empresa"] = true,
        ["posto"] = true
    }

    for nome, rg in cleanText:gmatch("([%a%d_]+)%[(%d+)%]") do
        local nomeLower = nome:lower()

        -- Evita salvar palavras genéricas como se fossem jogadores.
        if not ignorar[nomeLower] and nome:match("%a") and rg and rg ~= "" then
            local chaveNick = compactarBuscaNome(nome)
            rgChatPorNick[chaveNick] = tostring(rg)

            -- Liga imediatamente o RG ao ID atual da TAB quando o nick estiver online.
            -- Assim os comandos autorizados por nome funcionam sem depender de /tv previo.
            local pidEncontrado = nil
            local encontrados = buscarJogadoresOnlinePorNomeOuID(nome)

            for _, jogador in ipairs(encontrados) do
                if compactarBuscaNome(jogador.nick or "") == chaveNick then
                    pidEncontrado = tonumber(jogador.id)
                    break
                end
            end

            if pidEncontrado and sampIsPlayerConnected(pidEncontrado) then
                rgCache[pidEncontrado] = tostring(rg)
                salvarRGNoBanco(rg, nome, pidEncontrado)
            else
                salvarRGNoBanco(rg, nome, nil)
            end
        end
    end
end

-- Anti-duplicacao de mensagem do servidor tipo: Nick Nome | RG: 123
-- O servidor/TAB pode ecoar essa linha duas vezes quando a telagem e feita por clique.
local ultimoNickRGMsgChave = nil
local ultimoNickRGMsgTempo = 0

-- ============================================================
-- MONITORAMENTO DE MENSAGENS DO CHAT (SETOR SEGURANÇA)
-- ============================================================
local function setor_onServerMessage(color, text)

    -- Confirma o modo admin pelo nick local e pelo final da mensagem.
    -- O numero entre colchetes no HZ e RG, portanto nao deve ser comparado ao ID da TAB.
    do
        local mensagemAdmin = tostring(text or "")
            :gsub("{%x%x%x%x%x%x}", "")
            :gsub("~[%w]~", "")
            :gsub("%s+", " ")
            :match("^%s*(.-)%s*$")

        local mensagemLower = mensagemAdmin:lower()
        local okMeuId, meuId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local meuNick = ""

        if okMeuId and type(sampGetPlayerNickname) == "function" then
            meuNick = tostring(sampGetPlayerNickname(meuId) or ""):lower()
        end

        local mensagemEhMinha = meuNick ~= "" and mensagemLower:find(meuNick, 1, true) ~= nil
        local loginEstavaPendente = (tonumber(_G.HZMonitorEtapa1.adminPendenteAte) or 0)
            > (os.clock and os.clock() or 0)
        local mensagemPessoalLogin = loginEstavaPendente
            and mensagemLower:find("voc", 1, true) ~= nil
            and mensagemLower:find("logou", 1, true) ~= nil

        if mensagemEhMinha or mensagemPessoalLogin then
            local confirmouLogin =
                mensagemLower:find("logou", 1, true)
                and (mensagemLower:find("staff", 1, true)
                    or mensagemLower:find("administra", 1, true))

            local confirmouLogout =
                mensagemLower:find("deslogou", 1, true)
                and (mensagemLower:find("staff", 1, true)
                    or mensagemLower:find("administra", 1, true))

            if confirmouLogin then
                if (_G.HZMonitorEtapa1.adminPendenteAte or 0) > 0 then
                    _G.HZMonitorEtapa1.ativarEListar()
                end

                -- Diretor/Coordenador usam mensagens diferentes e podem chegar
                -- com acentos convertidos. Identifica o cargo pelas palavras
                -- estaveis da mensagem e libera o /mods pelo nick local.
                local cargoConfirmado = nil
                if mensagemLower:find("diretor", 1, true) then
                    cargoConfirmado = "Diretor"
                elseif mensagemLower:find("coorden", 1, true) then
                    cargoConfirmado = "Coordenador"
                end

                if cargoConfirmado then
                    cargoAdmin = cargoConfirmado
                    nomeAdmin = tostring(sampGetPlayerNickname(meuId) or "")
                    _G.HZStaffLogada = true
                    stopStaffSaciarme()
                    stopStaffSupport()
                    if _G.HZModuloAtivo("automacoes_staff") then
                        startStaffSaciarme()
                        startStaffSupport(cargoAdmin)
                    end
                    _G.HZAvisarCargoUmaVez(cargoConfirmado, nomeAdmin, "Acesso ao /mods liberado.")
                end

            elseif confirmouLogout then
                _G.HZMonitorEtapa1.adminPendenteAte = 0
                _G.HZMonitorEtapa1.definirAdminAtivo(false, false)
            end
        end
    end

    local cleanText = text:gsub("{%x%x%x%x%x%x}", ""):gsub("%s+", " "):trim()
    local dH = os.date("%d/%m/%Y - %H:%M:%S")

    -- Ao descobrir o RG pela TAB, o servidor pode responder com este erro antes
    -- de enviar "Nick ... | RG: ...". Oculta apenas essa resposta intermediaria.
    do
        local agora = os.clock and os.clock() or 0
        local suprimirAte = tonumber(_G.HZNavNovatoSuprimirErroAte) or 0
        local erroRGAusente = cleanText:lower():find("rg nao encontrado ou jogador offline", 1, true)

        if erroRGAusente and agora <= suprimirAte then
            return false
        end

        if agora > suprimirAte then
            _G.HZNavNovatoPendente = nil
            _G.HZNavNovatoSuprimirErroAte = 0
        end
    end

    -- Evita duplicar visualmente a linha do servidor: "Nick Nome | RG: 123".
    -- Mantem a primeira aparicao e bloqueia somente repeticao imediata do mesmo nick/RG.
    do
        local nickMsg, rgMsg = cleanText:match("^[Nn]ick%s+([%a%d_]+)%s*|%s*[Rr][Gg]%s*:%s*(%d+)")

        if nickMsg and rgMsg then
            local chave = tostring(nickMsg):lower() .. "|" .. tostring(rgMsg)
            local agora = os.clock()

            if ultimoNickRGMsgChave == chave and (agora - ultimoNickRGMsgTempo) < 3.0 then
                return false
            end

            ultimoNickRGMsgChave = chave
            ultimoNickRGMsgTempo = agora
        end
    end

    -- Captura imediata das duvidas exibidas no chat:
    -- DUVIDA: Duvida de Nome[RG]: mensagem
    -- Permite usar /d Nome resposta ou /duvida Nome resposta sem precisar telar.
    do
        local nomeDuvida, rgDuvida = cleanText:match("[Dd][Uu][Vv][Ii][Dd][Aa]%s+de%s+([%a%d_]+)%[(%d+)%]%s*:")
        if nomeDuvida and rgDuvida then
            rgChatPorNick[compactarBuscaNome(nomeDuvida)] = tostring(rgDuvida)
        end
    end

    -- Aprende automaticamente Nome[RG], mas fora do callback de rede.
    -- Isso impede reentrada nativa no SAMPFUNCS durante login/spawn.
    enfileirarCapturaNomeRG(cleanText)

    -- ============================================================
    -- CAPTURA AUTOMÁTICA DE CARGO E NICK DO ADMIN
    -- ============================================================
    
    -- CAPTURA CARGO E NICK ADMIN (QUANDO LOGA)
    if cleanText:find("ADMIN: O%(A%) (.-) (.-)%[(%d+)%] logou na staff!") then
        local cargo, nome, idCapturado = cleanText:match("ADMIN: O%(A%) (.-) (.-)%[(%d+)%] logou na staff!")
        local okMeuId, meuId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local meuNick = okMeuId and tostring(sampGetPlayerNickname(meuId) or "") or ""
        -- O numero entre colchetes pode ser RG, por isso a identificacao segura e pelo nick local.
        if meuNick ~= "" and tostring(nome or ""):lower() == meuNick:lower() then
            cargoAdmin, nomeAdmin = cargo, nome
            _G.HZStaffLogada = true
            stopStaffSaciarme()
            stopStaffSupport()

            local nivelCargo, cargoNome = _G.HZNivelCargo(cargoAdmin)
            if nivelCargo >= 1 and _G.HZModuloAtivo("automacoes_staff") then
                startStaffSaciarme()
                startStaffSupport(cargoAdmin)
            end

            if nivelCargo < 3 then
                if camOn then camDisable() end
                if _G.HZMonitorPanel then _G.HZMonitorPanel.aberto.v = false end
            end
            if nivelCargo < 2 then
                tvNovatosAtivo, tvTodosAtivo = false, false
                if _G.PainelTVModule and _G.PainelTVModule.setEnabled then
                    _G.PainelTVModule.setEnabled(false)
                end
            end

            _G.HZAvisarCargoUmaVez(cargoNome, nomeAdmin, "Permissoes aplicadas.")

            -- O monitor já foi ativado pela captura genérica acima.
            -- Aqui mantemos somente a captura de cargo/nick e os serviços da staff.
        end
    end

    -- Formato usado por Coordenador e Diretor, inclusive com prefixo de horario/INFO:
    -- "[21:05:48] INFO: Ola Diretor(a) Nome, voce logou na administracao com sucesso!"
    if not _G.HZStaffLogada then
        local cargoSuperior, nomeSuperior = cleanText:match(
            "[Oo]la%s+([^%s]+)%s+([%a%d_]+),.-logou.-administra"
        )
        if cargoSuperior and nomeSuperior then
            local nivelSuperior, cargoNomeSuperior = _G.HZNivelCargo(cargoSuperior)
            local okMeuId, meuId = sampGetPlayerIdByCharHandle(PLAYER_PED)
            local meuNick = okMeuId and tostring(sampGetPlayerNickname(meuId) or "") or ""

            if nivelSuperior >= 3
                and meuNick ~= ""
                and tostring(nomeSuperior):lower() == meuNick:lower() then
                cargoAdmin, nomeAdmin = cargoSuperior, nomeSuperior
                _G.HZStaffLogada = true
                _G.HZMonitorEtapa1.ativarEListar()
                stopStaffSaciarme()
                stopStaffSupport()

                if _G.HZModuloAtivo("automacoes_staff") then
                    startStaffSaciarme()
                    startStaffSupport(cargoAdmin)
                end

                _G.HZAvisarCargoUmaVez(cargoNomeSuperior, nomeAdmin, "Permissoes completas aplicadas.")
            end
        end
    end

    if cleanText:find("ADMIN: O%(A%) (.-) (.-)%[(%d+)%] saiu da staff") then
        local _, nomeSaida = cleanText:match("ADMIN: O%(A%) (.-) (.-)%[(%d+)%] saiu da staff")
        local okMeuId, meuId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        local meuNick = okMeuId and tostring(sampGetPlayerNickname(meuId) or "") or ""
        if meuNick ~= "" and tostring(nomeSaida or ""):lower() == meuNick:lower() then
            stopStaffSaciarme()
            stopStaffSupport()
            _G.HZMonitorEtapa1.definirAdminAtivo(false, false)
            cargoAdmin, nomeAdmin = "Desconhecido", ""
            _G.HZStaffLogada = false
            _G.HZFecharPainelMods()
            tvNovatosAtivo, tvTodosAtivo = false, false
            if camOn then camDisable() end
            if _G.PainelTVModule and _G.PainelTVModule.setEnabled then _G.PainelTVModule.setEnabled(false) end
        end
    end

    -- INÍCIO DE ATENDIMENTO
    if cleanText:find("atendendo o%(a%) jogador%(a%)") then
        local nome, id = cleanText:match("jogador%(a%)%s+([%a%d_]+)%[(%d+)%]")
        if nome and id then
            nickJogadorAtendido, idJogadorAtendido = nome, id
            emAtendimento, jogadorCaiu, historicoConversa = true, false, {}
            tempoInicio = os.time()
        end
    end

    -- REGISTRO DE CONVERSA DO CHAT SEGURANÇA
    if emAtendimento and (cleanText:find("Chat%-Suporte") or cleanText:find("Chat Suporte")) then
        local hora = os.date("%H:%M:%S")
        local mensagemLimpa = cleanText:match(":%s*(.*)$") or cleanText
        table.insert(historicoConversa, "[" .. hora .. "] " .. mensagemLimpa)
    end

    -- LOG DE TAPA (CONFIRMAÇÃO DO CHAT)
    if cleanText:find("Voce deu um tapa no%(a%) jogador%(a%) ([%a%d_]+)%[(%d+)%]") then
        local jNome, jId = cleanText:match("Voce deu um tapa no%(a%) jogador%(a%) ([%a%d_]+)%[(%d+)%]")
        enviarLogTapa(jNome, jId)
    end

    -- LOG DE VEICULOS (IRVEICULO / TRAZERVEICULO)
    if cleanText:find("INFO: Voce foi ate o ve") and cleanText:find("culo") and cleanText:find("pertence a") then
        local mod, vid, dono = cleanText:match("ve[ií]culo%s+(.-)%[(%d+)%]%s+que%s+pertence%s+a%s+(.+)")
        if vid then
            local msg = string.format("[%s] HZ-ADMIN: O(a) %s %s teleportou para a posicao do veiculo [ID: %s] [Modelo %s] que pertence jogador(a) %s", dH, cargoAdmin, nomeAdmin, vid, mod, dono)
            enviarSimples(WEBHOOKS.LOG_VEICULO, msg)
        end
    end

    if cleanText:find("INFO: Voce trouxe o ve") and cleanText:find("culo") and cleanText:find("pertence a") then
        local mod, vid, dono = cleanText:match("ve[ií]culo%s+(.-)%[(%d+)%]%s+que%s+pertence%s+a%s+(.+)")
        if vid then
            local msg = string.format("[%s] HZ-ADMIN: O(a) %s %s puxou o veiculo [ID: %s] [Modelo %s] que pertence ao jogador(a) %s", dH, cargoAdmin, nomeAdmin, vid, mod, dono)
            enviarSimples(WEBHOOKS.LOG_VEICULO, msg)
        end
    end

    -- PROCESSAMENTO DE PUNIÇÕES REGISTRADAS
    if aguardandoConfirmacao then
        if cleanText:find("HZ%-ADMIN") then
            local nick = cleanText:match("[Jj]ogador%(a%)%s+([%a%d_]+)")
            if nick and nick:lower() ~= nomeAdmin:lower() then
                local acao = (v_tipo == "BAN") and "baniu" or "prendeu"
                local url = (v_tipo == "BAN") and WEBHOOKS.BAN or WEBHOOKS.CADEIA
                enviarTudo(nick, v_rg, v_tempo, v_motivo, acao, url, v_tipo)
                aguardandoConfirmacao = false
            end
        end
    end
end

-- ================== HOOKS: /tv manual e TEXTDRAWS ==================
local function setor_onShowTextDraw(id, data)
    if type(data) == "table" and data.text then
        local rg, pid = try_parse_rg_and_id_from_text(data.text)
        local nick = try_parse_nick_from_text(data.text)
        if rg or pid or nick then maybe_store_and_announce(rg, pid, nick) end
    else
        for _, v in ipairs({data}) do
            if type(v) == "string" then
                local rg, pid = try_parse_rg_and_id_from_text(v)
                local nick = try_parse_nick_from_text(v)
                if rg or pid or nick then maybe_store_and_announce(rg, pid, nick) end
            end
        end
    end
end

local function setor_onTextDrawSetString(id, text)
    local rg, pid = try_parse_rg_and_id_from_text(text)
    local nick = try_parse_nick_from_text(text)
    if rg or pid or nick then maybe_store_and_announce(rg, pid, nick) end
end

local function setor_onShowPlayerTextDraw(playerId, data)
    if type(data) == "table" and data.text then
        local rg, pid = try_parse_rg_and_id_from_text(data.text)
        local nick = try_parse_nick_from_text(data.text)
        if rg or pid or nick then maybe_store_and_announce(rg, pid, nick) end
    else
        for _, v in ipairs({data}) do
            if type(v) == "string" then
                local rg, pid = try_parse_rg_and_id_from_text(v)
                local nick = try_parse_nick_from_text(v)
                if rg or pid or nick then maybe_store_and_announce(rg, pid, nick) end
            end
        end
    end
end

local function setor_onPlayerTextDrawSetString(playerId, id, text)
    local rg, pid = try_parse_rg_and_id_from_text(text)
    local nick = try_parse_nick_from_text(text)
    if rg or pid or nick then maybe_store_and_announce(rg, pid, nick) end
end

-- ============================================================
-- FUNÇÕES DE LOGS (SETOR SEGURANÇA)
-- ============================================================

function enviarLogTeleporte(tipo, jNome, jRG)
    local dH = os.date("%d/%m/%Y - %H:%M:%S")
    local nomeJogador = tostring(jNome or "Desconhecido")
    local rgJogador = tostring(jRG or "Desconhecido")

    local msg
    local webhook

    if tipo == "IR" then
        msg = string.format(
            "[%s] HZ-ADMIN: O(a) %s %s teleportou para a posicao do(a) jogador(a) %s (RG: %s)",
            dH, cargoAdmin, nomeAdmin, nomeJogador, rgJogador
        )
        webhook = WEBHOOKS.LOG_IR
    else
        msg = string.format(
            "[%s] HZ-ADMIN: O(a) %s %s puxou o(a) jogador(a) %s para a sua posicao (RG: %s)",
            dH, cargoAdmin, nomeAdmin, nomeJogador, rgJogador
        )
        webhook = WEBHOOKS.LOG_TRAZER
    end

    return enviarSimples(webhook, msg)
end

function enviarLogStatus(tipo, jNome, jRG, qtd)
    local dH = os.date("%d/%m/%Y - %H:%M:%S")
    local nomeJogador = tostring(jNome or "Desconhecido")
    local rgJogador = tostring(jRG or "Desconhecido")
    local msg, webhook

    if tipo == "CONGELAR" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s congelou o(a) jogador(a) %s (RG: %s)", dH, cargoAdmin, nomeAdmin, nomeJogador, rgJogador)
        webhook = WEBHOOKS.LOG_CONGELAR
    elseif tipo == "DESCONGELAR" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s descongelou o(a) jogador(a) %s (RG: %s)", dH, cargoAdmin, nomeAdmin, nomeJogador, rgJogador)
        webhook = WEBHOOKS.LOG_DESCONGELAR
    elseif tipo == "ARMAS" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s prendeu as armas do(a) jogador(a) %s (RG: %s)", dH, cargoAdmin, nomeAdmin, nomeJogador, rgJogador)
        webhook = WEBHOOKS.LOG_PRENDERARMAS
    elseif tipo == "REVIVER" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s utilizou /reviver e Reviveu o (RG %s)", dH, cargoAdmin, nomeAdmin, rgJogador)
        webhook = WEBHOOKS.LOG_REVIVER
    elseif tipo == "VIDA" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s utilizou /setvida no (RG %s) definindo a Vida (Para: %s)", dH, cargoAdmin, nomeAdmin, rgJogador, tostring(qtd or "?"))
        webhook = WEBHOOKS.LOG_SETVIDA
    elseif tipo == "COLETE" then
        msg = string.format("[%s] HZ-ADMIN: O(a) %s %s utilizou /setcolete no (RG %s) definindo o Colete (Para: %s)", dH, cargoAdmin, nomeAdmin, rgJogador, tostring(qtd or "?"))
        webhook = WEBHOOKS.LOG_SETCOLETE
    end

    if not webhook or not msg then
        return false
    end

    return enviarSimples(webhook, msg)
end

function enviarLogTapa(jNome, jId)
    local dH = os.date("%d/%m/%Y - %H:%M:%S")
    local msg = string.format(
        "[%s] HZ-ADMIN: O(a) %s %s deu um tapa no(a) jogador(a) %s (RG: %s) | (Altura: %s)",
        dH, cargoAdmin, nomeAdmin, tostring(jNome or "Desconhecido"),
        tostring(jId or "Desconhecido"), tostring(v_altura_tapa or "1")
    )

    return enviarSimples(WEBHOOKS.LOG_TAPA, msg)
end

function finalizarTudo(statusTexto)
    if not emAtendimento then return end
    local duracao = os.difftime(os.time(), tempoInicio)
    local m, s = math.floor(duracao / 60), duracao % 60
    local tempoF = string.format("%d minuto%s e %d segundo%s", m, m ~= 1 and "s" or "", s, s ~= 1 and "s" or "")
    local dataF, dHoraLog = os.date("%d/%m/%Y"), os.date("%d/%m/%Y - %H:%M:%S")

    local logGeral = string.format("[%s] HZ-ADMIN: O(a) %s %s atendeu o(a) jogador(a) %s — atendimento durou %s — %s", dHoraLog, cargoAdmin, nomeAdmin, nickJogadorAtendido, tempoF, statusTexto)
    local corpoForm = string.format("**REGISTRO DE ATENDIMENTO**\\n**DATA:** %s\\n**DURAÇÃO:** %s\\n**STATUS:** %s\\n**ATENDENTE:** %s\\n**JOGADOR:** %s\\n**CONVERSA:**\\n```\\n%s\\n```", dataF, tempoF, statusTexto, nomeAdmin, nickJogadorAtendido, table.concat(historicoConversa, "\\n"))

    -- Logs de atendimento desativados para otimizar o painel.
    -- Mantido somente o fechamento local do atendimento.
    -- lua_thread.create(function()
    --     requests.post(WEBHOOKS.LOG_ATENDIMENTO, {data = '{"content":"'..logGeral..'"}', headers = {["Content-Type"] = "application/json"}})
    --     wait(1100)
    --     requests.post(WEBHOOKS.FORM_ATENDIMENTO, {data = '{"content":"'..corpoForm..'"}', headers = {["Content-Type"] = "application/json"}})
    -- end)
    -- Encerra tambem qualquer estado visual residual do painel.
    emAtendimento = false
    jogadorCaiu = false
    tempoExibicaoAviso = 0
    painelAtendimentoArrastando = false
end

-- ============================================================
-- EVENTOS DE SAÍDA E VISUAL (SETOR SEGURANÇA)
-- ============================================================
local function setor_onPlayerQuit(id, reason)
    local nickQueSaiu = ""
    if type(sampGetPlayerNickname) == "function" then
        local okNick, nickSaida = pcall(sampGetPlayerNickname, id)
        if okNick then nickQueSaiu = tostring(nickSaida or "") end
    end
    local saiuJogadorAtendido = tostring(id) == idJogadorAtendido
        or (nickQueSaiu ~= "" and nickQueSaiu:lower() == tostring(nickJogadorAtendido):lower())
    if emAtendimento and saiuJogadorAtendido then
        local dur = os.difftime(os.time(), tempoInicio)
        tempoFinalCongelado = string.format("%02d:%02d", math.floor(dur / 60), dur % 60)
        table.insert(historicoConversa, "[" .. os.date("%H:%M:%S") .. "] O jogador saiu do servidor.")
        finalizarTudo("Atendimento finalizado — jogador desconectou.")
        jogadorCaiu, tempoExibicaoAviso = true, os.time() + 30
    end
end


local function mouseDentroArea(mx, my, x, y, w, h)
    return mx >= x and mx <= (x + w) and my >= y and my <= (y + h)
end

local function atualizarArrastePainelAtendimento(x, y, w, h)
    if not getCursorPos or not isKeyDown then
        return x, y
    end

    local mx, my = getCursorPos()
    if not mx or not my then
        return x, y
    end

    local mouseDown = isKeyDown(1)

    if mouseDown and not painelAtendimentoArrastando and mouseDentroArea(mx, my, x, y, w, 24) then
        painelAtendimentoArrastando = true
        painelAtendimentoOffsetX = mx - x
        painelAtendimentoOffsetY = my - y
    elseif not mouseDown and painelAtendimentoArrastando then
        painelAtendimentoArrastando = false
        salvarConfigSistema(true)
    end

    if painelAtendimentoArrastando then
        x = math.floor(mx - painelAtendimentoOffsetX)
        y = math.floor(my - painelAtendimentoOffsetY)

        if x < 0 then x = 0 end
        if y < 0 then y = 0 end

        configSistema.painelAtendimentoX = x
        configSistema.painelAtendimentoY = y
        salvarConfigSistema(false)
    end

    return x, y
end

function desenharPainelVisual()
    local x = tonumber(configSistema.painelAtendimentoX) or 20
    local y = tonumber(configSistema.painelAtendimentoY) or 630

    -- Painel visual redesenhado no tema Horizonte.
    -- Apenas renderizacao; nao altera nenhuma regra de atendimento.
    local w, h = 235, 96
    x, y = atualizarArrastePainelAtendimento(x, y, w, h)
    local bg = 0xDD11151D
    local bg2 = 0xAA1A1F2B
    local cyan = 0xFF016FAA
    local cyanGlow = 0xFF48C6FF
    local red = 0xFFE74C5B
    local green = 0xFF3EDC81
    local yellow = 0xFFFFC857

    renderDrawBox(x, y, w, h, bg)
    renderDrawBox(x, y, 4, h, jogadorCaiu and red or cyanGlow)
    renderDrawBox(x, y, w, 22, bg2)
    renderDrawBox(x, y + 22, w, 1, jogadorCaiu and red or cyan)
    renderDrawBox(x + 8, y + h - 8, w - 16, 2, jogadorCaiu and red or cyan)

    if jogadorCaiu then
        renderFontDrawText(fonteTitulo, "{E74C5B}SETOR SEGURANCA", x + 12, y + 5, 0xFFFFFFFF)
        renderFontDrawText(fonteAvisoSaida, "{FFFFFF}JOGADOR DESCONECTADO", x + 12, y + 30, 0xFFFFFFFF)
        renderFontDrawText(fontePrincipal, "{A8B5C8}Nick: {FFFFFF}" .. nickJogadorAtendido, x + 12, y + 50, 0xFFFFFFFF)
        renderFontDrawText(fontePrincipal, "{A8B5C8}Tempo: {FFC857}" .. tempoFinalCongelado, x + 12, y + 68, 0xFFFFFFFF)
    else
        local dur = os.difftime(os.time(), tempoInicio)
        local tempo = string.format("%02d:%02d", math.floor(dur / 60), dur % 60)

        renderFontDrawText(fonteTitulo, "{48C6FF}SUPORTE", x + 12, y + 5, 0xFFFFFFFF)
        renderFontDrawText(fontePrincipal, "{3EDC81}ATIVO", x + 132, y + 6, 0xFFFFFFFF)

        renderFontDrawText(fontePrincipal, "{A8B5C8}Jogador", x + 12, y + 31, 0xFFFFFFFF)
        renderFontDrawText(fontePrincipal, "{FFFFFF}" .. nickJogadorAtendido, x + 72, y + 31, 0xFFFFFFFF)

        renderFontDrawText(fontePrincipal, "{A8B5C8}RG", x + 12, y + 50, 0xFFFFFFFF)
        renderFontDrawText(fontePrincipal, "{FFFFFF}" .. idJogadorAtendido, x + 72, y + 50, 0xFFFFFFFF)

        renderFontDrawText(fontePrincipal, "{A8B5C8}Tempo", x + 12, y + 69, 0xFFFFFFFF)
        renderFontDrawText(fontePrincipal, "{FFC857}" .. tempo, x + 72, y + 69, 0xFFFFFFFF)
    end
end

-- ============================================================
-- FUNÇÃO AUXILIAR DE STRING
-- ============================================================
function string.trim(s) 
    return s:match("^%s*(.-)%s*$") 
end

-- ============================================================
-- ATUALIZADOR AUTOMATICO - PC
-- Arquivos esperados no GitHub:
--   pc/versao.txt
--   pc/SETOR_SEG.lua
-- ============================================================
_G.HZUpdaterPC = _G.HZUpdaterPC or {
    versao = "1.41",
    urlVersao = "https://raw.githubusercontent.com/YagoBMF/setor-advanced/main/SETOR/PC/versao.txt",
    urlScript = "https://raw.githubusercontent.com/YagoBMF/setor-advanced/main/SETOR/PC/SETOR_SEG.lua",
    consultando = false
}

function _G.HZUpdaterPC.corpoResposta(res)
    if type(res) ~= "table" then return nil end
    return res.text or res.body or res.data
end

function _G.HZUpdaterPC.remotaMaior(remota, instalada)
    local r, l = {}, {}
    for n in tostring(remota or ""):gmatch("%d+") do r[#r + 1] = tonumber(n) or 0 end
    for n in tostring(instalada or ""):gmatch("%d+") do l[#l + 1] = tonumber(n) or 0 end
    for i = 1, math.max(#r, #l) do
        local rv, lv = r[i] or 0, l[i] or 0
        if rv > lv then return true end
        if rv < lv then return false end
    end
    return false
end

function _G.HZUpdaterPC.obterVersao()
    local ok, res = pcall(requests.get, _G.HZUpdaterPC.urlVersao)
    if not ok then return nil end
    local corpo = _G.HZUpdaterPC.corpoResposta(res)
    return corpo and tostring(corpo):match("([%d%.]+)") or nil
end

function _G.HZUpdaterPC.caminhoAtual()
    if type(thisScript) ~= "function" then return nil end
    local ok, script = pcall(thisScript)
    if ok and script and script.path then return script.path end
    return nil
end

function _G.HZUpdaterPC.verificar(silencioso)
    if _G.HZUpdaterPC.consultando then return end
    _G.HZUpdaterPC.consultando = true
    lua_thread.create(function()
        local remota = _G.HZUpdaterPC.obterVersao()
        _G.HZUpdaterPC.consultando = false
        if not remota then
            if not silencioso then
                sampAddChatMessage("{FF5555}[SETOR UPDATE]: Nao foi possivel consultar o GitHub.", -1)
            end
            return
        end
        if _G.HZUpdaterPC.remotaMaior(remota, _G.HZUpdaterPC.versao) then
            if silencioso then
                -- Na verificacao automatica da inicializacao, instala sem exigir comando.
                _G.HZUpdaterPC.instalar(true)
            else
                sampAddChatMessage("{FFFF00}[SETOR UPDATE]: Nova versao " .. remota .. " disponivel. Use /setoratualizar.", -1)
            end
        elseif not silencioso then
            sampAddChatMessage("{00FF7F}[SETOR UPDATE]: Versao " .. _G.HZUpdaterPC.versao .. " ja esta atualizada.", -1)
        end
    end)
end

function _G.HZUpdaterPC.instalar(silencioso)
    if _G.HZUpdaterPC.consultando then
        sampAddChatMessage("{FFFF00}[SETOR UPDATE]: Aguarde a consulta atual terminar.", -1)
        return
    end
    _G.HZUpdaterPC.consultando = true
    lua_thread.create(function()
        if not silencioso then
            sampAddChatMessage("{48C6FF}[SETOR UPDATE]: Baixando atualizacao...", -1)
        end
        local remota = _G.HZUpdaterPC.obterVersao()
        if not remota then
            _G.HZUpdaterPC.consultando = false
            return sampAddChatMessage("{FF5555}[SETOR UPDATE]: Falha ao consultar a versao remota.", -1)
        end
        if not _G.HZUpdaterPC.remotaMaior(remota, _G.HZUpdaterPC.versao) then
            _G.HZUpdaterPC.consultando = false
            if not silencioso then
                sampAddChatMessage("{00FF7F}[SETOR UPDATE]: Nenhuma atualizacao disponivel.", -1)
            end
            return
        end

        local ok, res = pcall(requests.get, _G.HZUpdaterPC.urlScript)
        local novo = ok and _G.HZUpdaterPC.corpoResposta(res) or nil
        if not novo or #novo < 50000 or not tostring(novo):find("SETOR") then
            _G.HZUpdaterPC.consultando = false
            return sampAddChatMessage("{FF5555}[SETOR UPDATE]: Arquivo remoto invalido. Operacao cancelada.", -1)
        end

        local path = _G.HZUpdaterPC.caminhoAtual()
        if not path then
            _G.HZUpdaterPC.consultando = false
            return sampAddChatMessage("{FF5555}[SETOR UPDATE]: Caminho do script nao localizado.", -1)
        end
        local atual = io.open(path, "r")
        if not atual then
            _G.HZUpdaterPC.consultando = false
            return sampAddChatMessage("{FF5555}[SETOR UPDATE]: Nao foi possivel abrir o script atual.", -1)
        end
        local conteudoAtual = atual:read("*a")
        atual:close()

        local backup = io.open(path .. ".bak", "w+")
        if not backup then
            _G.HZUpdaterPC.consultando = false
            return sampAddChatMessage("{FF5555}[SETOR UPDATE]: Nao foi possivel criar o backup.", -1)
        end
        backup:write(conteudoAtual)
        backup:close()

        local destino = io.open(path, "w+")
        if not destino then
            _G.HZUpdaterPC.consultando = false
            return sampAddChatMessage("{FF5555}[SETOR UPDATE]: Nao foi possivel substituir o script.", -1)
        end
        destino:write(novo)
        destino:close()
        _G.HZUpdaterPC.consultando = false
        sampAddChatMessage("{00FF7F}[SETOR UPDATE]: Atualizado para " .. remota .. ". Reinicie o jogo. Backup: " .. path .. ".bak", -1)
    end)
end

-- ============================================================
-- FIM DO SISTEMA INTEGRADO DE SEGURANÇA
-- ============================================================


-- ============================================================
-- CALLBACKS UNIFICADOS (PainelTV + Setor)
-- ============================================================
function imgui.OnInitialize()
    if _G.PainelTVModule and _G.PainelTVModule.OnInitialize then
        _G.PainelTVModule.OnInitialize()
    end
end

function imgui.OnDrawFrame()
    if _G.HZModuloAtivo("painel_tv") and _G.PainelTVModule and _G.PainelTVModule.OnDrawFrame then
        _G.PainelTVModule.OnDrawFrame()
    end
    if setor_OnDrawFrame then
        setor_OnDrawFrame()
    end
    if _G.HZModuloAtivo("monitoramento") and _G.HZMonitorPanel and _G.HZMonitorPanel.desenhar then
        _G.HZMonitorPanel.desenhar()
    end
end

function onWindowMessage(msg, wparam, lparam)
    if setor_onWindowMessage then
        local r = setor_onWindowMessage(msg, wparam, lparam)
        if r == false then return false end
    end
end

function main()
    -- O script nunca presume que voce ja esta em modo admin ao iniciar.
    _G.HZStaffLogada = false
    cargoAdmin, nomeAdmin = "Desconhecido", ""
    _G.HZModsJanela.v = false
    _G.HZMonitorEtapa1.adminAtivo = false
    _G.HZMonitorEtapa1.adminPendenteAte = 0
    _G.HZMonitorEtapa1.onlinePorRG = {}
    _G.HZMonitorEtapa1.inicializadoOnline = false
    if _G.PainelTVModule and _G.PainelTVModule.main then
        lua_thread.create(_G.PainelTVModule.main)
    end
    setor_main()
end

function samp.onSendCommand(cmd)
    local r1
    if setor_onSendCommand then r1 = setor_onSendCommand(cmd) end
    if _G.PainelTVModule and _G.PainelTVModule.onSendCommand then
        local r2 = _G.PainelTVModule.onSendCommand(cmd)
        if r2 == false then return false end
    end
    if r1 == false then return false end
    return r1
end

function samp.onShowDialog(id, style, title, button1, button2, text)
    if _G.HZAvisosAC and _G.HZAvisosAC.registrarDialogo then
        _G.HZAvisosAC.registrarDialogo(id, title, text)
    end
end

function samp.onSendDialogResponse(id, button, listboxId, input)
    if _G.HZAvisosAC and _G.HZAvisosAC.responderDialogo then
        _G.HZAvisosAC.responderDialogo(id, button)
    end
end

function samp.onServerMessage(color, text)
    if setor_onServerMessage then
        return setor_onServerMessage(color, text)
    end
end

function sampev.onShowTextDraw(id, data)
    if _G.HZModuloAtivo("painel_tv") and _G.PainelTVModule and _G.PainelTVModule.onShowTextDraw then _G.PainelTVModule.onShowTextDraw(id, data) end
    if setor_onShowTextDraw then return setor_onShowTextDraw(id, data) end
end

function sampev.onTextDrawSetString(id, text)
    if _G.HZModuloAtivo("painel_tv") and _G.PainelTVModule and _G.PainelTVModule.onTextDrawSetString then _G.PainelTVModule.onTextDrawSetString(id, text) end
    if setor_onTextDrawSetString then return setor_onTextDrawSetString(id, text) end
end

function sampev.onShowPlayerTextDraw(playerId, data)
    if _G.HZModuloAtivo("painel_tv") and _G.PainelTVModule and _G.PainelTVModule.onShowPlayerTextDraw then _G.PainelTVModule.onShowPlayerTextDraw(playerId, data) end
    if setor_onShowPlayerTextDraw then return setor_onShowPlayerTextDraw(playerId, data) end
end

function sampev.onPlayerTextDrawSetString(playerId, id, text)
    if _G.HZModuloAtivo("painel_tv") and _G.PainelTVModule and _G.PainelTVModule.onPlayerTextDrawSetString then _G.PainelTVModule.onPlayerTextDrawSetString(playerId, id, text) end
    if setor_onPlayerTextDrawSetString then return setor_onPlayerTextDrawSetString(playerId, id, text) end
end

function samp.onPlayerQuit(id, reason)
    if setor_onPlayerQuit then return setor_onPlayerQuit(id, reason) end
end
