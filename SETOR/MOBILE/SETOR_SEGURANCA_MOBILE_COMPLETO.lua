-- SETOR SEGURANCA - MOBILE
-- Baseado na versao mobile validada e nas funcoes da versao PC.

local samp = require 'samp.events'
local requests = require 'requests'
local inicfg = require 'inicfg'
local MIMGUI_OK, mimgui = pcall(require, 'mimgui')
if not MIMGUI_OK or type(mimgui) ~= 'table' then MIMGUI_OK, mimgui = false, nil end

local VERSION = '3.46'
local CONFIG_FILE = 'SetorSeguranca.ini'
local CACHE_FILE = 'hz_rg_cache_mobile.txt'
local MONITOR_FILE = 'hz_monitorados_mobile.txt'
local UPDATE_API_BASE = 'https://api.github.com/repos/YagoBMF/setor-advanced/contents/SETOR/MOBILE/'
local UPDATE_VERSION_URL = UPDATE_API_BASE .. 'versao.txt?ref=main'
local UPDATE_SCRIPT_URL = UPDATE_API_BASE .. 'SETOR_SEGURANCA_MOBILE_COMPLETO.lua?ref=main'
local UPDATE_GITHUB_OPTIONS = {headers = {
    ['Accept'] = 'application/vnd.github.raw+json',
    ['User-Agent'] = 'Setor-Mobile-Updater',
    ['X-GitHub-Api-Version'] = '2022-11-28'
}}
local EXTERNAL_UPDATER_PATH = (type(getWorkingDirectory) == 'function' and getWorkingDirectory() or '.') .. '/SETOR_MOBILE_UPDATER.lua'
local HAS_EXTERNAL_UPDATER = type(doesFileExist) == 'function' and doesFileExist(EXTERNAL_UPDATER_PATH)

local WEBHOOKS = {
    LOG = 'https://discord.com/api/webhooks/1472343208477593822/AsrnjXuzTjPhPZM_W9QDmGylJ6uPL5mJZJyheDwFB1FzAYO82jrrV1VBor4Xkh1d0KO0',
    BAN = 'https://discord.com/api/webhooks/1472343861719339212/BbCTngmkr9YZH5W7PiCVx_IjhC6eboyI072MlddFaGUzQ39i1g9FXI0AcgIJavP3dzdo',
    CADEIA = 'https://discord.com/api/webhooks/1472343962797998090/0zYDFcEW_q7pfrtMYmwk2_hijr33Bb_tS-GyXktfwg3Uvj1ZzAlMtgXk-VX5S5uBlGVU',
    MUTE = 'https://discord.com/api/webhooks/1472344170520907939/BTLBSNDhp054jKOLU7_3Q-eXunG4SM3g2K7uhRKv_3wIaKgp997daaLxwvLh2sYbJfUV',
    TAPA = 'https://discord.com/api/webhooks/1519098721806192697/bah3dfhfZD29fJQeOf21awLF9WkcN8pkf1wITxFXDMjl2KXB2fjGg3fs7DoOyZjd2VU5',
    TRAZER = 'https://discord.com/api/webhooks/1519098792794656979/5xs6w4tv_CYyw0UN4BgjH1HBie9VgNuHUZMc_cfJFkXzJl5a-Fjfr3vaEzZMMBGG4AY1',
    IR = 'https://discord.com/api/webhooks/1519098786343817501/mmohOhvvFt8HtM8oFCDC7v4PzvEAh9yQCQ8sdVeOVsrrrGZyPTTJzVtHB6Wrdj_DknHT',
    CONGELAR = 'https://discord.com/api/webhooks/1519123580041035849/-HJzL4KKnS6sYqL3wssbAvsU54kCcSbaHrAfdZIJSJ2WfzoUz325I4bLdi-N1RQCX8sP',
    DESCONGELAR = 'https://discord.com/api/webhooks/1519123575108272268/Wj1tYTA4RQmpt_jIx8HtlNzuzed3DgQyAEVaYY94otiCTR9IfhWnMHqO_K9laLwAFYIe',
    PRENDERARMAS = 'https://discord.com/api/webhooks/1519149792872108062/Nfnx7YOtGbBcDYvAbV3K9Uns6yiwZEWmgWWfLqXt0u68ejT4FOYG8HvjLxgIYFu_n6xB',
    SETVIDA = 'https://discord.com/api/webhooks/1519338573218840728/eiMlWVsK_0FqTHL-AwDNDFj0tICtgbkmqOlSN1dyaFCh-VOfQlvWfKCfDP49Kh-_iGjN',
    SETCOLETE = 'https://discord.com/api/webhooks/1519341309121269921/Jeb-TRF1I2zj3rrfwqx3pGSTGEdKYiHWHhFKW-dBf2hwiXZRtFmQZjusZjwFu2LsOFfJ',
    REVIVER = 'https://discord.com/api/webhooks/1519353929492860968/FjWWaoy1g2F3Jf05XzRFCe84L4ZZOczEsvD9FAAtR_ZhTclMxp14agsXIhgZG3dudTGH'
}

local cfg = inicfg.load({
    dados = { nome = 'Vazio', cargo = 'Vazio' },
    interface = {
        painel_tv_x = 18, painel_tv_y = 250, painel_tv_visivel = true,
        painel_tv_escala = 1.0,
        atendimento_x = 18, atendimento_y = 170,
        atendimento_escala = 1.0,
        suporte_x = 18, suporte_y = 280, suporte_escala = 1.0
    },
    modulos = {
        painel_tv = true, navegacao_tv = true,
        monitoramento = true, acoes_staff = true, atendimento = true, logs = true
    }
}, CONFIG_FILE)

-- Migra configuracoes das primeiras versoes sem perder escolhas do usuario.
cfg.modulos = cfg.modulos or {}
cfg.interface = cfg.interface or {}
if cfg.interface.painel_tv_x == nil then cfg.interface.painel_tv_x = 18 end
if cfg.interface.painel_tv_y == nil then cfg.interface.painel_tv_y = 250 end
if cfg.interface.painel_tv_visivel == nil then cfg.interface.painel_tv_visivel = true end
if cfg.interface.painel_tv_escala == nil then cfg.interface.painel_tv_escala = 1.0 end
if cfg.interface.atendimento_x == nil then cfg.interface.atendimento_x = 18 end
if cfg.interface.atendimento_y == nil then cfg.interface.atendimento_y = 170 end
if cfg.interface.atendimento_escala == nil then cfg.interface.atendimento_escala = 1.0 end
if cfg.interface.suporte_x == nil then cfg.interface.suporte_x = 18 end
if cfg.interface.suporte_y == nil then cfg.interface.suporte_y = 280 end
if cfg.interface.suporte_escala == nil then cfg.interface.suporte_escala = 1.0 end
-- A versao 3.41 podia salvar (0,0) quando o Android informava resolucao 0x0.
if cfg.interface.correcao_posicao_342 ~= true then
    if tonumber(cfg.interface.painel_tv_x) == 0 and tonumber(cfg.interface.painel_tv_y) == 0 then
        cfg.interface.painel_tv_x, cfg.interface.painel_tv_y = 18, 250
    end
    if tonumber(cfg.interface.atendimento_x) == 0 and tonumber(cfg.interface.atendimento_y) == 0 then
        cfg.interface.atendimento_x, cfg.interface.atendimento_y = 18, 170
    end
    if tonumber(cfg.interface.suporte_x) == 0 and tonumber(cfg.interface.suporte_y) == 0 then
        cfg.interface.suporte_x, cfg.interface.suporte_y = 18, 280
    end
    cfg.interface.correcao_posicao_342 = true
end
-- Restaura uma unica vez o layout afetado pela leitura de resolucao das
-- versoes 3.40/3.42. Depois disso, posicao e tamanho voltam a ser livres.
if cfg.interface.restauracao_layout_343 ~= true then
    cfg.interface.painel_tv_x, cfg.interface.painel_tv_y = 18, 250
    cfg.interface.atendimento_x, cfg.interface.atendimento_y = 18, 170
    cfg.interface.suporte_x, cfg.interface.suporte_y = 18, 280
    cfg.interface.painel_tv_escala = 1.0
    cfg.interface.atendimento_escala = 1.0
    cfg.interface.suporte_escala = 1.0
    cfg.interface.restauracao_layout_343 = true
end
if cfg.modulos.navegacao_tv == nil then cfg.modulos.navegacao_tv = cfg.modulos.navegacao ~= false end
if cfg.modulos.acoes_staff == nil then cfg.modulos.acoes_staff = cfg.modulos.atalhos ~= false end
if cfg.modulos.painel_tv == nil then cfg.modulos.painel_tv = true end
if cfg.modulos.monitoramento == nil then cfg.modulos.monitoramento = true end
if cfg.modulos.atendimento == nil then cfg.modulos.atendimento = true end
-- Logs sao obrigatorios para toda a staff e nao podem ser desativados.
cfg.modulos.logs = true
inicfg.save(cfg, CONFIG_FILE)

local cache, monitorados = {}, {}
local rgAtual, nickAtual = nil, nil
-- O MonetLoader pode devolver score 0 antes de sincronizar o TAB. Esse valor
-- so deve valer como Level 0 quando for confirmado nas informacoes do servidor.
local levelAtualConfirmado = nil
local pendente = nil
local navNovato, navTodos = 0, 0
local staffLogada = false
local loginStaffPendenteAte = 0
local reportDialogId, aguardandoReport, reportAte = -1, false, 0
local reportDialogTexto = ''
local reportAlvoNick = nil
local reportAlvoRg = nil
local reportSelecaoEm = 0
local ultimoAvisoReport, ultimoAvisoReportEm = '', 0
local horarioServidor, horarioServidorEm = '--:--:--', 0
local dataServidor = '--/--/--'
local painelTvFlutuante = false
local painelTvFonte, painelTvFonteTitulo = nil, nil
local painelTvArrastando, painelTvOffsetX, painelTvOffsetY = false, 0, 0
local painelTvToqueAnterior, painelTvAcaoPendente = false, nil
local painelTvMimguiPosCarregada, painelTvMimguiUltimoSave = false, 0
local monitorSsAberto = false
local novatoTelagemPendenteId = nil
local atendimentoPosCarregada, atendimentoUltimoSave = false, 0
local suportePosCarregada, suporteUltimoSave = false, 0
local emAtendimento, atendimentoNick, atendimentoRg = false, '', ''
local atendimentoInicio = 0
local atendimentoOffAte, atendimentoTempoFinal = 0, 0

local function relogioAtendimento()
    if type(getGameTimer) == 'function' then
        local ok, valor = pcall(getGameTimer)
        if ok and tonumber(valor) then return tonumber(valor) / 1000 end
    end
    if type(os.clock) == 'function' then return os.clock() end
    return os.time()
end

local SACIARME_INTERVALO = 15 * 60
local SACIARME_PRIMEIRO_ATRASO = 30
local saciarmeProximo = 0

local function prepararAberturaReports()
    reportDialogId, aguardandoReport = -2, false
    reportDialogTexto = ''
    reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
    levelAtualConfirmado = nil
    reportAte = (os.clock and os.clock() or 0) + 60
end

local CARGOS = {
    ['1'] = 'Ajudante', ['2'] = 'Moderador', ['3'] = 'Administrador',
    ['4'] = 'Coordenador', ['5'] = 'Diretor'
}

-- Dialogos locais (faixa alta para evitar conflito com dialogos comuns do servidor)
local D_MAIN = 28000
local D_TV = 28001
local D_ACOES = 28002
local D_RG = 28003
local D_MONITOR = 28004
local D_MODULOS = 28005
local D_INPUT_ACAO = 28010
local D_INPUT_RG_BUSCA = 28011
local D_INPUT_RG_DEL = 28012
local D_INPUT_MONITOR = 28013
local D_INPUT_DESMONITOR = 28014
local D_PUNICOES = 28015
local D_INPUT_PUNICAO = 28016
local D_TABELA_PUNICAO = 28017
local D_INPUT_ALVO_TABELA = 28018
local D_CONFIRMAR_TABELA = 28019
local D_SELETOR_TV = 28020
local D_MOD_CATEGORIA = 28021
local dialogAction = nil
local punicaoTabelaSelecionada = nil
local jogadoresSeletorTV = {}
local modsCategoriaAtual = nil

-- Texto visual pode manter a sigla; o comando envia somente o motivo real.
local PUNICOES_CADEIA = {
    {'NRA - Uso de arma em safe', 'Uso de arma em safe', 100},
    {'ASM - Agressao sem motivo', 'Agressao sem motivo', 100},
    {'DM - Matar/Ferir sem motivo', 'Matar/Ferir sem motivo', 200},
    {'Assalto loja irregular', 'Assalto loja irregular', 150},
    {'Assalto banco irregular', 'Assalto banco irregular', 150},
    {'Anti RP', 'Anti RP', 200},
    {'Anti-RP - Assalto em veiculo', 'Assalto em veiculo', 200},
    {'Anti-RP - Uso indevido de profissao', 'Uso indevido de profissao', 200},
    {'Anti-RP - Algemar/taser durante trocacao', 'Algemar ou usar taser durante trocacao', 200},
    {'Anti-RP - Abuso de safe', 'Abuso de safe', 200},
    {'PTR solo - Policial solo em acao', 'Policial solo em acao', 250},
    {'VDM - Matar/Ferir com veiculo', 'Matar/Ferir com veiculo', 250},
    {'DB - Atirando de dentro do veiculo', 'Atirando de dentro do veiculo', 250},
    {'AB Desmanche - Abordagem no Desmanche', 'Abordagem no Desmanche', 250},
    {'KOS - Matar por identificacao', 'Matar por identificacao', 250},
    {'PG - Acao fora da realidade', 'Acao fora da realidade', 250},
    {'TK - Matar aliado sem motivo', 'Matar aliado sem motivo', 250},
    {'HK - Matar com helicoptero', 'Matar com helicoptero', 250},
    {'SLP - Sniper em local proibido', 'Sniper em local proibido', 250},
    {'Invasao sem autorizacao', 'Invasao sem autorizacao', 250},
    {'RDM - Multiplas mortes sem motivo', 'Multiplas mortes sem motivo', 250},
    {'RK - Vinganca apos morte', 'Vinganca apos morte', 250},
    {'Spam Kill - Abuso de interior para matar', 'Abuso de interior para matar', 250},
    {'CB - Forcar perseguicao', 'Forcar perseguicao', 250},
    {'SAAV - Sem Amor a Vida', 'Sem Amor a Vida', 250},
    {'PK - Ignorar perda de memoria', 'Ignorar perda de memoria', 250},
    {'CL - Combat Log', 'Desconectou durante acao', 300},
    {'Corrupcao', 'Corrupcao', 300},
    {'Dark RP', 'Dark RP', 300}
}

-- Tabelas do Painel TV. Estrutura: texto visual, motivo enviado, duracao em dias.
_G.HZMobileTabelasPunicao = {
    ban_permanente = {
        {'Cheat', 'Cheat', 0}, {'Mod proibido', 'Mod proibido', 0},
        {'Abuso de bug', 'Abuso de bug', 0},
        {'Comercio ilegal', 'Comercio ilegal', 0}, {'Divulgacao', 'Divulgacao', 0},
        {'Nick improprio', 'Nick improprio', 0}, {'Money farm', 'Money farm', 0},
        {'Racismo', 'Racismo', 0}, {'Gordofobia', 'Gordofobia', 0}
    },
    ban_temporario = {
        {'Cortar animacao | 15 dias', 'Cortar animacao', 15},
        {'Handling | 5 dias', 'Handling', 5},
        {'Animacao vantajosa | 5 dias', 'Animacao vantajosa', 5},
        {'Anti-RP extremo | 10 dias', 'Anti-RP extremo', 10},
        {'Anti-RP extremo | 15 dias', 'Anti-RP extremo', 15},
        {'Anti-RP extremo | 20 dias', 'Anti-RP extremo', 20}
    },
    mute = {
        {'MUCS - Restricao | 3 dias', 'MUCS - Restricao', 3},
        {'MUC Atendimento | 3 dias', 'MUC Atendimento', 3},
        {'MUC Duvida | 3 dias', 'MUC Duvida', 3},
        {'MUC Missa | 3 dias', 'MUC Missa', 3},
        {'MUC News | 3 dias', 'MUC News', 3},
        {'MUC OLX | 3 dias', 'MUC OLX', 3},
        {'MUC /Reportar | 3 dias', 'MUC /Reportar', 3},
        {'MUC Anorg | 3 dias', 'MUC Anorg', 3},
        {'MUC An | 3 dias', 'MUC An', 3},
        {'Ofensa Staff/Servidor | 30 dias', 'Ofensa Staff/Servidor', 30},
        {'Desrespeito | 3 dias', 'Desrespeito', 3},
        {'Conteudo sexual | 3 dias', 'Conteudo sexual', 3},
        {'Flood | 1 dia', 'Flood', 1}
    },
    kick = {
        {'RT / Jogador bugado', 'RT / Jogador bugado', 0},
        {'Bugando evento', 'Bugando evento', 0}
    }
}
_G.HZMobileTipoTabelaPunicao = 'cadeia'
_G.HZMobileListaTabelaPunicao = PUNICOES_CADEIA

local function chat(cor, texto)
    sampAddChatMessage(cor .. '[SETOR]: {FFFFFF}' .. tostring(texto), -1)
end

local function trim(s)
    return tostring(s or ''):match('^%s*(.-)%s*$')
end

local function clean(s)
    return tostring(s or ''):gsub('{%x%x%x%x%x%x}', ''):gsub('~.-~', '')
end

local function jsonEscape(s)
    return tostring(s or ''):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r', '\\r'):gsub('\n', '\\n')
end

local function perfilOk()
    if cfg.dados.nome ~= 'Vazio' then return true end
    chat('{FF5555}', 'Perfil nao configurado. Use /configadm Nome 1-5.')
    return false
end

local function exigirStaff(recurso)
    if staffLogada == true then return true end
    sampAddChatMessage('{FF6B6B}[SETOR] Entre na staff com /la antes de usar ' .. tostring(recurso or 'esta funcao') .. '.', -1)
    return false
end

local function nivelCargo(cargo)
    cargo = clean(cargo):lower()
    if cargo:find('diretor', 1, true) then return 5 end
    if cargo:find('coorden', 1, true) then return 4 end
    if cargo:find('admin', 1, true) then return 3 end
    if cargo:find('moder', 1, true) then return 2 end
    if cargo:find('ajud', 1, true) then return 1 end
    return 0
end

local MODULOS_INFO = {
    atendimento = {'ATENDIMENTO RAPIDO', 'Botoes flutuantes de fila e reports.', 1},
    painel_tv = {'PAINEL TV', 'Telagem, status e menu TV.', 2},
    navegacao_tv = {'NAVEGACAO TV', 'Selecao e atalhos entre jogadores.', 2},
    monitoramento = {'MONITORAMENTO', 'Alertas e jogadores monitorados.', 3},
    acoes_staff = {'ACOES STAFF', 'Comandos administrativos e atalhos.', 3}
}

local MODULOS_CATEGORIAS = {
    {'PAINEIS', 'Atendimento rapido, Painel TV e punicoes.', {'atendimento', 'painel_tv'}},
    {'NAVEGACAO', 'Selecao e navegacao de jogadores.', {'navegacao_tv'}},
    {'FERRAMENTAS', 'Monitoramento e acoes administrativas.', {'monitoramento', 'acoes_staff'}}
}

local function moduloPermitido(id)
    local info = MODULOS_INFO[id]
    return staffLogada and info and nivelCargo(cfg.dados.cargo) >= tonumber(info[3] or 99)
end

local function moduloAtivo(id)
    if id == 'logs' then return staffLogada == true end
    return moduloPermitido(id) and cfg.modulos[id] ~= false
end

local function definirPerfil(nome, cargo, logado)
    nome, cargo = trim(nome), trim(cargo)
    if nome == '' or nivelCargo(cargo) == 0 then return false end
    cfg.dados.nome, cfg.dados.cargo = nome, cargo
    staffLogada = logado ~= false
    saciarmeProximo = staffLogada
        and (relogioAtendimento() + SACIARME_PRIMEIRO_ATRASO) or 0
    inicfg.save(cfg, CONFIG_FILE)
    return true
end

local function responseBody(res)
    if type(res) ~= 'table' then return nil end
    return res.text or res.body or res.data
end

local function versaoMaior(remota, localAtual)
    local r, l = {}, {}
    for n in tostring(remota or ''):gmatch('%d+') do r[#r + 1] = tonumber(n) or 0 end
    for n in tostring(localAtual or ''):gmatch('%d+') do l[#l + 1] = tonumber(n) or 0 end
    for i = 1, math.max(#r, #l) do
        local rv, lv = r[i] or 0, l[i] or 0
        if rv > lv then return true end
        if rv < lv then return false end
    end
    return false
end

local function obterVersaoRemota()
    local ok, res = pcall(requests.get, UPDATE_VERSION_URL, UPDATE_GITHUB_OPTIONS)
    if not ok then return nil end
    local body = responseBody(res)
    return body and trim(body):match('([%d%.]+)') or nil
end

local function caminhoDoScript()
    if type(thisScript) == 'function' then
        local ok, script = pcall(thisScript)
        if ok and script and script.path then return script.path end
    end
    return nil
end

local function verificarAtualizacao(silencioso)
    lua_thread.create(function()
        local remota = obterVersaoRemota()
        if not remota then
            if not silencioso then chat('{FF5555}', 'Nao foi possivel consultar o GitHub.') end
            return
        end
        if versaoMaior(remota, VERSION) then
            chat('{FFFF00}', 'Nova versao disponivel: ' .. remota .. '. Use /setoratualizar.')
        elseif not silencioso then
            chat('{3EDC81}', 'Voce ja esta na versao mais recente (' .. VERSION .. ').')
        end
    end)
end


local function instalarAtualizacao()
    lua_thread.create(function()
        chat('{48C6FF}', 'Baixando atualizacao do GitHub...')
        local remota = obterVersaoRemota()
        if not remota then return chat('{FF5555}', 'Falha ao consultar a versao remota.') end
        if not versaoMaior(remota, VERSION) then return chat('{3EDC81}', 'Nenhuma atualizacao disponivel.') end

        local ok, res = pcall(requests.get, UPDATE_SCRIPT_URL, UPDATE_GITHUB_OPTIONS)
        local novo = ok and responseBody(res) or nil
        if not novo or #novo < 5000 or not novo:find('SETOR SEGURANCA %- MOBILE') then
            return chat('{FF5555}', 'Arquivo remoto invalido. Atualizacao cancelada.')
        end

        local path = caminhoDoScript()
        if not path then return chat('{FF5555}', 'O MoonLoader nao informou o caminho deste script.') end
        local atual = io.open(path, 'r')
        if not atual then return chat('{FF5555}', 'Nao foi possivel abrir o script atual.') end
        local conteudoAtual = atual:read('*a')
        atual:close()

        local backup = io.open(path .. '.bak', 'w')
        if not backup then return chat('{FF5555}', 'Nao foi possivel criar o backup. Atualizacao cancelada.') end
        backup:write(conteudoAtual)
        backup:close()

        local destino = io.open(path, 'w')
        if not destino then return chat('{FF5555}', 'Nao foi possivel substituir o script.') end
        destino:write(novo)
        destino:close()
        chat('{3EDC81}', 'Atualizado para ' .. remota .. '. Reinicie o jogo. Backup salvo em .bak.')
    end)
end

local function salvarTabela(path, dados)
    local f = io.open(path, 'w')
    if not f then return false end
    for chave, info in pairs(dados) do
        local nick, motivo = '', ''
        if type(info) == 'table' then nick, motivo = info.nick or '', info.motivo or '' else nick = tostring(info) end
        f:write(tostring(chave), '\t', nick:gsub('[\r\n\t]', ' '), '\t', motivo:gsub('[\r\n\t]', ' '), '\n')
    end
    f:close()
    return true
end

local function carregarTabela(path)
    local dados, f = {}, io.open(path, 'r')
    if not f then return dados end
    for line in f:lines() do
        local chave, nick, motivo = line:match('^([^\t]+)\t([^\t]*)\t?(.*)$')
        if chave then dados[chave] = { nick = nick or '', motivo = motivo or '' } end
    end
    f:close()
    return dados
end

local function salvarRG(rg, nick)
    rg, nick = tostring(rg or ''):match('(%d+)'), trim(nick)
    if not rg or nick == '' then return end
    cache[rg] = { nick = nick }
    salvarTabela(CACHE_FILE, cache)
end

local function acharRG(valor)
    valor = trim(valor)
    if valor:match('^%d+$') and cache[valor] then return valor, cache[valor].nick end
    local busca = valor:lower()
    local achados = {}
    for rg, info in pairs(cache) do
        if tostring(info.nick):lower():find(busca, 1, true) then achados[#achados + 1] = {rg, info.nick} end
    end
    if #achados == 1 then return achados[1][1], achados[1][2] end
    return nil, nil, #achados
end

local function post(url, mensagem, retorno)
    if not moduloAtivo('logs') then return end
    lua_thread.create(function()
        local ok, res = pcall(requests.post, url, {
            data = '{"content":"' .. jsonEscape(mensagem) .. '"}',
            headers = {['Content-Type'] = 'application/json'}
        })
        if retorno then
            if ok and res then chat('{3EDC81}', retorno) else chat('{FF5555}', 'Falha ao enviar o registro ao Discord.') end
        end
    end)
end

local function logPunicao(nick, rg, tempo, motivo, acao, url, tipo)
    local data = os.date('%d/%m/%Y - %H:%M:%S')
    local geral = string.format('[%s] HZ-ADMIN: %s %s %s o(a) jogador(a) %s %s por %s (Motivo: %s)',
        data, cfg.dados.cargo, cfg.dados.nome, acao, nick, rg, tempo, motivo)
    local form = string.format('```\nADM: %s\nNICK: %s\nRG: %s\nTEMPO: %s\nMOTIVO: %s\nPROVAS: \n```',
        cfg.dados.nome, nick, rg, tempo, motivo)
    post(WEBHOOKS.LOG, geral)
    lua_thread.create(function()
        wait(1100)
        post(url, '[' .. data .. ']')
        wait(1100)
        post(url, form, 'Registro de ' .. tipo .. ' enviado.')
    end)
end

local function logAcao(tipo, rg, extra)
    local url = WEBHOOKS[tipo]
    if not url then return end
    local nick = cache[tostring(rg)] and cache[tostring(rg)].nick or ('RG ' .. tostring(rg))
    local msg = string.format('[%s] %s %s executou %s em %s [RG %s]%s', os.date('%d/%m/%Y - %H:%M:%S'),
        cfg.dados.cargo, cfg.dados.nome, tipo, nick, rg, extra and (' (' .. extra .. ')') or '')
    post(url, msg)
end

local function listaJogadores(somenteNovatos)
    -- Algumas builds do MonetLoader so atualizam os levels depois desta
    -- requisicao, embora os jogadores ja aparecam normalmente no TAB.
    if type(sampRequestScoresAndPings) == 'function' then
        pcall(sampRequestScoresAndPings)
    elseif type(sampSendRequestScoresAndPings) == 'function' then
        pcall(sampSendRequestScoresAndPings)
    end
    local lista = {}
    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then
            local level = tonumber(sampGetPlayerScore(id))
            if not somenteNovatos or (level and level >= 0 and level <= 30) then
                lista[#lista + 1] = { id = id, nick = sampGetPlayerNickname(id), level = level or 0 }
            end
        end
    end
    table.sort(lista, function(a, b) return a.id < b.id end)
    return lista
end

local function jogadorOnlinePorNick(nick)
    local busca = tostring(nick or ''):lower()
    if busca == '' then return nil end
    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) then
            local nickTab = tostring(sampGetPlayerNickname(id) or '')
            if nickTab:lower() == busca then return nickTab, id end
        end
    end
    return nil
end

local function telarJogadorPelaTab(jogador)
    if not jogador or not jogador.id or not sampIsPlayerConnected(tonumber(jogador.id)) then
        return chat('{FF5555}', 'Jogador nao esta mais conectado no TAB.')
    end
    if type(sampSendClickPlayer) ~= 'function' then
        return chat('{FF5555}', 'Este MonetLoader nao oferece clique de jogador pelo TAB.')
    end

    nickAtual = tostring(jogador.nick or sampGetPlayerNickname(tonumber(jogador.id)) or '?')
    -- Nao envia cache historico ao servidor: IDs podem ser reutilizados.
    -- O RG correto sera capturado da resposta/textdraw desta telagem.
    rgAtual = nil
    levelAtualConfirmado = nil
    painelTvFlutuante = true
    aguardandoReport, reportDialogId, reportAte = false, -1, 0
    sampSendClickPlayer(tonumber(jogador.id), 0)
    chat('{48C6FF}', 'Telando ' .. nickAtual .. ' [ID ' .. tostring(jogador.id) .. '] pelo TAB.')
    return true
end
-- Ponte global evita estourar o limite de 60 upvalues do LuaJIT no callback
-- central de dialogos, que ja concentra todas as janelas do mobile.
_G.HZMobileTelarPelaTab = telarJogadorPelaTab

local function copiarResumoTelagem(rg, info)
    info = type(info) == 'table' and info or {}
    local texto = 'Nome: ' .. tostring(info.nick or 'Desconhecido')
        .. '\nRG: ' .. tostring(rg)
        .. '\nMotivo: ' .. tostring(info.motivo or 'Nao informado')
    local copiado = false
    if type(setClipboardText) == 'function' then copiado = pcall(setClipboardText, texto) end
    if not copiado and MIMGUI_OK and type(mimgui.SetClipboardText) == 'function' then
        copiado = pcall(mimgui.SetClipboardText, texto)
    end
    if copiado then
        chat('{3EDC81}', 'Resumo da telagem copiado.')
    else
        chat('{48C6FF}', texto:gsub('\n', ' | '))
    end
end
_G.HZMobileCopiarResumoTelagem = copiarResumoTelagem

local function enviarAvisoTelagemReport(nick, rg)
    local agora = os.clock and os.clock() or 0
    if not aguardandoReport or agora > reportAte then return false end
    nick, rg = tostring(nick or ''), tostring(rg or '')
    if nick == '' or nick == '?' or rg == '' then return false end
    local chave = nick:lower() .. '|' .. rg
    if chave ~= ultimoAvisoReport or agora - ultimoAvisoReportEm > 6 then
        ultimoAvisoReport, ultimoAvisoReportEm = chave, agora
        lua_thread.create(function()
            wait(350)
            sampSendChat('/ac Estou telando o Player ' .. nick)
        end)
    end
    aguardandoReport, reportAte = false, 0
    reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
    return true
end

local function navegar(novatos, direcao)
    if not exigirStaff('a navegacao TV') then return end
    if not moduloAtivo('navegacao_tv') then return chat('{FF5555}', 'Modulo de navegacao desativado ou bloqueado para o cargo.') end
    local lista = listaJogadores(novatos)
    if #lista == 0 then return chat('{FFFF00}', 'Nenhum jogador disponivel nessa lista.') end
    if novatos then
        navNovato = ((navNovato - 1 + direcao) % #lista) + 1
        -- No Horizonte, o clique do TAB descobre o RG. Em seguida a telagem
        -- definitiva precisa ser feita com /tv RG.
        novatoTelagemPendenteId = tonumber(lista[navNovato].id)
        telarJogadorPelaTab(lista[navNovato])
    else
        novatoTelagemPendenteId = nil
        navTodos = ((navTodos - 1 + direcao) % #lista) + 1
        telarJogadorPelaTab(lista[navTodos])
    end
end

local function dadosJogadorAtual()
    local idAtual, levelAtual = -1, '?'
    if nickAtual then
        for id = 0, sampGetMaxPlayerId(false) do
            if sampIsPlayerConnected(id) and tostring(sampGetPlayerNickname(id)):lower() == tostring(nickAtual):lower() then
                local score = tonumber(sampGetPlayerScore(id))
                local levelSeguro = levelAtualConfirmado
                if levelSeguro == nil and score and score > 0 then levelSeguro = score end
                idAtual, levelAtual = id, tostring(levelSeguro ~= nil and levelSeguro or '?')
                break
            end
        end
    end
    return idAtual, levelAtual
end

local function desenharPainelTvFlutuante()
    if MIMGUI_OK then return end
    if not painelTvFlutuante or not staffLogada or not moduloAtivo('painel_tv')
        or cfg.interface.painel_tv_visivel == false then return end
    if type(renderDrawBox) ~= 'function' or type(renderFontDrawText) ~= 'function' then return end

    if not painelTvFonte then
        -- MonetLoader mobile usa renderCreateFont; algumas builds de MoonLoader
        -- expõem o mesmo recurso como renderFontCreate.
        local criarFonte = type(renderCreateFont) == 'function' and renderCreateFont
            or (type(renderFontCreate) == 'function' and renderFontCreate)
        if criarFonte then
            painelTvFonte = criarFonte('Arial', 9, 5)
            painelTvFonteTitulo = criarFonte('Arial', 10, 5)
        end
    end
    if not painelTvFonte then return end

    local x = tonumber(cfg.interface.painel_tv_x) or 18
    local y = tonumber(cfg.interface.painel_tv_y) or 250
    local w, h = 268, 108
    local idAtual, levelAtual = dadosJogadorAtual()

    -- Arraste pela faixa superior quando o cursor do jogo estiver disponível.
    if type(getCursorPos) == 'function' and type(isKeyDown) == 'function' then
        local mx, my = getCursorPos()
        local pressionado = isKeyDown(1)
        if pressionado and not painelTvArrastando and mx >= x and mx <= x + w and my >= y and my <= y + 24 then
            painelTvArrastando, painelTvOffsetX, painelTvOffsetY = true, mx - x, my - y
        elseif painelTvArrastando and pressionado then
            cfg.interface.painel_tv_x = math.max(0, math.floor(mx - painelTvOffsetX))
            cfg.interface.painel_tv_y = math.max(0, math.floor(my - painelTvOffsetY))
            x, y = cfg.interface.painel_tv_x, cfg.interface.painel_tv_y
        elseif painelTvArrastando and not pressionado then
            painelTvArrastando = false
            inicfg.save(cfg, CONFIG_FILE)
        end

        -- No mobile, um toque nos botoes executa a acao sem exigir comandos.
        if pressionado and not painelTvToqueAnterior and not painelTvArrastando
            and my >= y + 76 and my <= y + 101 then
            if mx >= x + 9 and mx <= x + 67 then
                painelTvAcaoPendente = 'menu'
            elseif mx >= x + 72 and mx <= x + 130 then
                painelTvAcaoPendente = 'punir'
            elseif mx >= x + 135 and mx <= x + 202 then
                painelTvAcaoPendente = 'acoes'
            elseif mx >= x + 207 and mx <= x + 259 then
                painelTvAcaoPendente = 'off'
            end
        end
        painelTvToqueAnterior = pressionado
    end

    renderDrawBox(x + 3, y + 4, w, h, 0x66000000)
    renderDrawBox(x, y, w, h, 0xDD07101A)
    renderDrawBox(x, y, 4, h, 0xFF19AEEA)
    renderDrawBox(x, y, w, 24, 0xF0122635)
    renderDrawBox(x, y + 23, w, 1, 0xFF1588B8)
    renderFontDrawText(painelTvFonteTitulo or painelTvFonte, '{48C6FF}SETOR TV  {A8B5C8}| arraste aqui', x + 11, y + 5, 0xFFFFFFFF)
    renderFontDrawText(painelTvFonte, '{A8B5C8}NICK: {FFFFFF}' .. tostring(nickAtual or '?'), x + 11, y + 30, 0xFFFFFFFF)
    renderFontDrawText(painelTvFonte,
        '{A8B5C8}ID: {FFFFFF}' .. tostring(idAtual) .. '  {A8B5C8}| RG: {FFFFFF}' .. tostring(rgAtual or 'aguardando')
            .. '  {A8B5C8}| LEVEL: {FFFFFF}' .. tostring(levelAtual),
        x + 11, y + 46, 0xFFFFFFFF)
    renderDrawBox(x + 9, y + 76, 58, 25, 0xEE126A91)
    renderDrawBox(x + 72, y + 76, 58, 25, 0xEE8E2633)
    renderDrawBox(x + 135, y + 76, 67, 25, 0xEE126A91)
    renderDrawBox(x + 207, y + 76, 52, 25, 0xEE751D2B)
    renderFontDrawText(painelTvFonte, '{FFFFFF}MENU', x + 20, y + 82, 0xFFFFFFFF)
    renderFontDrawText(painelTvFonte, '{FFFFFF}PUNIR', x + 81, y + 82, 0xFFFFFFFF)
    renderFontDrawText(painelTvFonte, '{FFFFFF}ACOES', x + 146, y + 82, 0xFFFFFFFF)
    renderFontDrawText(painelTvFonte, '{FFFFFF}OFF', x + 221, y + 82, 0xFFFFFFFF)
end

local function instalarPainelTvMimgui()
    if not MIMGUI_OK or type(mimgui.OnFrame) ~= 'function' then return false end
    local function dimensoesResponsivas(baseW, baseH, escalaEscolhida)
        local desejada = tonumber(escalaEscolhida) or 1
        local escala = math.max(0.8, math.min(1.2, desejada))
        return escala, math.floor(baseW * escala + 0.5),
            math.floor(baseH * escala + 0.5)
    end

    local function prepararJanelaResponsiva(baseW, baseH, posX, posY, carregarPosicao, escalaEscolhida)
        local escala, largura, altura =
            dimensoesResponsivas(baseW, baseH, escalaEscolhida)
        local x, y = tonumber(posX) or 0, tonumber(posY) or 0
        if carregarPosicao and type(mimgui.SetNextWindowPos) == 'function' then
            mimgui.SetNextWindowPos(mimgui.ImVec2(x, y),
                mimgui.Cond and (mimgui.Cond.Always or 0) or 0)
        end
        -- Margem adicional evita recortes de fontes/densidades diferentes,
        -- mantendo dimensoes explicitas para a troca 80/100/120 funcionar.
        if type(mimgui.SetNextWindowSize) == 'function' then
            mimgui.SetNextWindowSize(mimgui.ImVec2(largura + 30, altura + 25),
                mimgui.Cond and (mimgui.Cond.Always or 0) or 0)
        end
        return escala, x, y, largura + 30, altura + 25
    end

    local function escalarFonteJanela(escala)
        if type(mimgui.SetWindowFontScale) == 'function' then
            pcall(mimgui.SetWindowFontScale, escala)
        end
    end

    local ultimoToquePainel = {}
    local function alternarEscalaPainel(chave)
        if type(mimgui.IsWindowHovered) ~= 'function'
            or type(mimgui.IsMouseClicked) ~= 'function' then return end
        local sobreItem = type(mimgui.IsAnyItemHovered) == 'function'
            and mimgui.IsAnyItemHovered()
        if mimgui.IsWindowHovered() and not sobreItem and mimgui.IsMouseClicked(0) then
            local agora = relogioAtendimento()
            local anterior = tonumber(ultimoToquePainel[chave]) or 0
            ultimoToquePainel[chave] = agora
            if anterior <= 0 or agora - anterior > 0.55 then return end
            ultimoToquePainel[chave] = 0
            local atual = tonumber(cfg.interface[chave]) or 1
            local nova = atual < 0.9 and 1.0 or (atual < 1.1 and 1.2 or 0.8)
            cfg.interface[chave] = nova
            inicfg.save(cfg, CONFIG_FILE)
            chat('{48C6FF}', 'Tamanho do painel: ' .. tostring(math.floor(nova * 100)) .. '%.')
        end
    end

    local ok, erro = pcall(function()
        mimgui.OnFrame(
            function()
                return painelTvFlutuante and staffLogada and moduloAtivo('painel_tv')
                    and cfg.interface.painel_tv_visivel ~= false
            end,
            function()
                local flags = 0
                if mimgui.WindowFlags then
                    flags = (mimgui.WindowFlags.NoCollapse or 0)
                        + (mimgui.WindowFlags.NoResize or 0)
                        + (mimgui.WindowFlags.NoScrollbar or 0)
                end
                local escala, posIgnoradaX, posIgnoradaY, janelaW, janelaH = prepararJanelaResponsiva(345, 190,
                    tonumber(cfg.interface.painel_tv_x) or 18,
                    tonumber(cfg.interface.painel_tv_y) or 250,
                    not painelTvMimguiPosCarregada,
                    cfg.interface.painel_tv_escala)
                if not painelTvMimguiPosCarregada then
                    painelTvMimguiPosCarregada = true
                end

                mimgui.Begin('SETOR TV##setor_mobile_tv', nil, flags)
                if type(mimgui.SetWindowSize) == 'function' then
                    pcall(mimgui.SetWindowSize, mimgui.ImVec2(janelaW, janelaH),
                        mimgui.Cond and (mimgui.Cond.Always or 0) or 0)
                end
                escalarFonteJanela(escala)
                local idAtual, levelAtual = dadosJogadorAtual()
                mimgui.Text('NICK: ' .. tostring(nickAtual or 'Aguardando servidor'))
                mimgui.Text('ID: ' .. tostring(idAtual)
                    .. '  |  RG: ' .. tostring(rgAtual or 'aguardando')
                    .. '  |  LEVEL: ' .. tostring(levelAtual))
                local monitorInfo = rgAtual and monitorados[tostring(rgAtual)] or nil
                mimgui.Text(monitorInfo and ('MONITORADO: ' .. tostring(monitorInfo.motivo))
                    or 'MONITORAMENTO: nao monitorado')
                if type(mimgui.Separator) == 'function' then mimgui.Separator() end

                if mimgui.Button('MENU', mimgui.ImVec2(72 * escala, 34 * escala)) then painelTvAcaoPendente = 'menu' end
                mimgui.SameLine(0, 3 * escala)
                if mimgui.Button('PUNIR', mimgui.ImVec2(72 * escala, 34 * escala)) then painelTvAcaoPendente = 'punir' end
                mimgui.SameLine(0, 3 * escala)
                if mimgui.Button('ACOES', mimgui.ImVec2(78 * escala, 34 * escala)) then painelTvAcaoPendente = 'acoes' end
                mimgui.SameLine(0, 3 * escala)
                if mimgui.Button('TV OFF', mimgui.ImVec2(82 * escala, 34 * escala)) then painelTvAcaoPendente = 'off' end
                if mimgui.Button('MONITORAMENTO', mimgui.ImVec2(330 * escala, 32 * escala)) then
                    painelTvAcaoPendente = 'monitor'
                end

                if type(mimgui.GetWindowPos) == 'function' then
                    local pos = mimgui.GetWindowPos()
                    local px, py = math.floor(pos.x or 0), math.floor(pos.y or 0)
                    if px ~= tonumber(cfg.interface.painel_tv_x) or py ~= tonumber(cfg.interface.painel_tv_y) then
                        cfg.interface.painel_tv_x, cfg.interface.painel_tv_y = px, py
                        local agora = os.clock and os.clock() or 0
                        if agora - painelTvMimguiUltimoSave >= 1 then
                            painelTvMimguiUltimoSave = agora
                            inicfg.save(cfg, CONFIG_FILE)
                        end
                    end
                end
                alternarEscalaPainel('painel_tv_escala')
                mimgui.End()
            end
        )

        mimgui.OnFrame(
            function()
                return staffLogada and moduloAtivo('atendimento')
            end,
            function()
                local flags = 0
                if mimgui.WindowFlags then
                    flags = (mimgui.WindowFlags.NoCollapse or 0)
                        + (mimgui.WindowFlags.NoResize or 0)
                        + (mimgui.WindowFlags.NoScrollbar or 0)
                end
                local escala, posIgnoradaX, posIgnoradaY, janelaW, janelaH = prepararJanelaResponsiva(265, 92,
                    tonumber(cfg.interface.atendimento_x) or 18,
                    tonumber(cfg.interface.atendimento_y) or 170,
                    not atendimentoPosCarregada,
                    cfg.interface.atendimento_escala)
                if not atendimentoPosCarregada then
                    atendimentoPosCarregada = true
                end

                mimgui.Begin('ATENDIMENTO RAPIDO##setor_mobile_atendimento', nil, flags)
                if type(mimgui.SetWindowSize) == 'function' then
                    pcall(mimgui.SetWindowSize, mimgui.ImVec2(janelaW, janelaH),
                        mimgui.Cond and (mimgui.Cond.Always or 0) or 0)
                end
                escalarFonteJanela(escala)
                local nivel = nivelCargo(cfg.dados.cargo)
                if nivel >= 2 then
                    if mimgui.Button('/REPORTS', mimgui.ImVec2(112 * escala, 38 * escala)) then
                        prepararAberturaReports()
                        sampSendChat('/reports')
                    end
                    mimgui.SameLine(0, 3 * escala)
                    if mimgui.Button('/FILA', mimgui.ImVec2(112 * escala, 38 * escala)) then
                        sampSendChat('/fila')
                    end
                else
                    if mimgui.Button('/FILA', mimgui.ImVec2(235 * escala, 38 * escala)) then
                        sampSendChat('/fila')
                    end
                end

                if type(mimgui.GetWindowPos) == 'function' then
                    local pos = mimgui.GetWindowPos()
                    local px, py = math.floor(pos.x or 0), math.floor(pos.y or 0)
                    if px ~= tonumber(cfg.interface.atendimento_x)
                        or py ~= tonumber(cfg.interface.atendimento_y) then
                        cfg.interface.atendimento_x, cfg.interface.atendimento_y = px, py
                        local agora = os.clock and os.clock() or 0
                        if agora - atendimentoUltimoSave >= 1 then
                            atendimentoUltimoSave = agora
                            inicfg.save(cfg, CONFIG_FILE)
                        end
                    end
                end
                alternarEscalaPainel('atendimento_escala')
                mimgui.End()
            end
        )

        mimgui.OnFrame(
            function()
                if atendimentoOffAte > 0 and relogioAtendimento() > atendimentoOffAte then
                    atendimentoOffAte, atendimentoTempoFinal = 0, 0
                    atendimentoNick, atendimentoRg, atendimentoInicio = '', '', 0
                end
                return staffLogada and moduloAtivo('atendimento')
                    and (emAtendimento or atendimentoOffAte > 0)
            end,
            function()
                local flags = 0
                if mimgui.WindowFlags then
                    flags = (mimgui.WindowFlags.NoCollapse or 0)
                        + (mimgui.WindowFlags.NoResize or 0)
                        + (mimgui.WindowFlags.NoScrollbar or 0)
                end
                local escala, posIgnoradaX, posIgnoradaY, janelaW, janelaH = prepararJanelaResponsiva(315, 150,
                    tonumber(cfg.interface.suporte_x) or 18,
                    tonumber(cfg.interface.suporte_y) or 280,
                    not suportePosCarregada,
                    cfg.interface.suporte_escala)
                if not suportePosCarregada then
                    suportePosCarregada = true
                end

                mimgui.Begin('SUPORTE ATIVO##setor_mobile_suporte', nil, flags)
                if type(mimgui.SetWindowSize) == 'function' then
                    pcall(mimgui.SetWindowSize, mimgui.ImVec2(janelaW, janelaH),
                        mimgui.Cond and (mimgui.Cond.Always or 0) or 0)
                end
                escalarFonteJanela(escala)
                mimgui.Text('STATUS: ' .. (emAtendimento and 'ON' or 'OFF'))
                if type(mimgui.Separator) == 'function' then mimgui.Separator() end
                mimgui.Text('JOGADOR: ' .. tostring(atendimentoNick ~= '' and atendimentoNick or '?'))
                mimgui.Text('RG: ' .. tostring(atendimentoRg ~= '' and atendimentoRg or '?'))
                if type(mimgui.Separator) == 'function' then mimgui.Separator() end
                if emAtendimento then
                    if mimgui.Button('FINALIZAR /FA', mimgui.ImVec2(285 * escala, 38 * escala)) then
                        sampSendChat('/fa')
                        emAtendimento = false
                    end
                else
                    mimgui.Text('Jogador desconectado. Fechando em 5 segundos...')
                end

                if type(mimgui.GetWindowPos) == 'function' then
                    local pos = mimgui.GetWindowPos()
                    local px, py = math.floor(pos.x or 0), math.floor(pos.y or 0)
                    if px ~= tonumber(cfg.interface.suporte_x)
                        or py ~= tonumber(cfg.interface.suporte_y) then
                        cfg.interface.suporte_x, cfg.interface.suporte_y = px, py
                        local agora = os.clock and os.clock() or 0
                        if agora - suporteUltimoSave >= 1 then
                            suporteUltimoSave = agora
                            inicfg.save(cfg, CONFIG_FILE)
                        end
                    end
                end
                alternarEscalaPainel('suporte_escala')
                mimgui.End()
            end
        )

        mimgui.OnFrame(
            function()
                return monitorSsAberto and staffLogada and moduloAtivo('monitoramento')
            end,
            function()
                local flags = 0
                if mimgui.WindowFlags then
                    flags = (mimgui.WindowFlags.NoCollapse or 0)
                        + (mimgui.WindowFlags.NoResize or 0)
                end
                mimgui.SetNextWindowSize(mimgui.ImVec2(470, 410),
                    mimgui.Cond and (mimgui.Cond.Always or 0) or 0)
                mimgui.Begin('SETOR - MONITORADOS /SS##setor_mobile_ss', nil, flags)
                mimgui.Text('JOGADORES MONITORADOS')
                if type(mimgui.Separator) == 'function' then mimgui.Separator() end

                local lista = {}
                for rg, info in pairs(monitorados) do
                    local jogador = nil
                    for id = 0, sampGetMaxPlayerId(false) do
                        if sampIsPlayerConnected(id)
                            and tostring(sampGetPlayerNickname(id) or ''):lower() == tostring(info.nick or ''):lower() then
                            jogador = {id=id, nick=sampGetPlayerNickname(id), level=sampGetPlayerScore(id) or 0}
                            break
                        end
                    end
                    lista[#lista + 1] = {rg=tostring(rg), info=info, jogador=jogador}
                end
                table.sort(lista, function(a, b)
                    if (a.jogador ~= nil) ~= (b.jogador ~= nil) then return a.jogador ~= nil end
                    return tostring(a.info.nick) < tostring(b.info.nick)
                end)

                if type(mimgui.BeginChild) == 'function' then
                    mimgui.BeginChild('##ss_lista', mimgui.ImVec2(0, 315), true)
                end
                if #lista == 0 then
                    mimgui.Text('Nenhum jogador monitorado.')
                else
                    for i, item in ipairs(lista) do
                        local status = item.jogador and 'ONLINE' or 'OFFLINE'
                        mimgui.Text(tostring(item.info.nick) .. ' | ' .. status
                            .. ' | RG ' .. item.rg)
                        mimgui.Text('Motivo: ' .. tostring(item.info.motivo or 'Nao informado'))
                        if item.jogador then
                            if mimgui.Button('TELAR##ss_tv_' .. i, mimgui.ImVec2(120, 30)) then
                                _G.HZMobileTelarPelaTab(item.jogador)
                                monitorSsAberto = false
                            end
                            mimgui.SameLine()
                        end
                        if mimgui.Button('TELAGEM##ss_copy_' .. i, mimgui.ImVec2(140, 30)) then
                            _G.HZMobileCopiarResumoTelagem(item.rg, item.info)
                        end
                        mimgui.SameLine()
                        if mimgui.Button('REMOVER##ss_rm_' .. i, mimgui.ImVec2(140, 30)) then
                            monitorados[item.rg] = nil
                            salvarTabela(MONITOR_FILE, monitorados)
                            chat('{3EDC81}', tostring(item.info.nick) .. ' removido do monitoramento.')
                        end
                        if type(mimgui.Separator) == 'function' then mimgui.Separator() end
                    end
                end
                if type(mimgui.EndChild) == 'function' then mimgui.EndChild() end
                if mimgui.Button('FECHAR', mimgui.ImVec2(150, 32)) then monitorSsAberto = false end
                mimgui.End()
            end
        )
    end)
    if not ok then
        MIMGUI_OK = false
        print('[SETOR MOBILE] mimgui indisponivel; usando painel visual: ' .. tostring(erro))
        return false
    end
    return true
end

local function mostrarAjuda()
    chat('{48C6FF}', 'Mobile ' .. VERSION .. ' | Perfil: /configadm Nome 1-5')
    chat('{48C6FF}', '/rgnome nome | /rgatual | /rgcache | /rgdel RG')
    chat('{48C6FF}', '/monitor RG motivo | /desmonitor RG | /ss (painel de monitorados)')
    chat('{48C6FF}', '/tvn /tvnvoltar (novatos) | /tva /tavoltar (todos) | /tvoff')
    chat('{48C6FF}', '/setorir RG | /setortrazer RG | /setorvida RG valor | /setorcolete RG valor')
    chat('{48C6FF}', '/setorreviver RG | /setorcongelar RG | /setordescongelar RG | /setorarmas RG')
    chat('{48C6FF}', '/mods | /modulo atendimento|painel_tv|navegacao_tv|monitoramento|acoes_staff on|off')
end

local function dialogo(id, titulo, texto, botao1, botao2, estilo)
    local hora = horarioServidor ~= '' and horarioServidor or '--:--:--'
    sampShowDialog(id, titulo .. ' | ' .. dataServidor .. ' ' .. hora, texto, botao1 or 'Selecionar', botao2 or 'Voltar', estilo or 2)
    -- Igual ao PC: permite que dialogos locais entreguem a escolha ao callback.
    -- O onSendDialogResponse retorna false e impede o RPC de chegar ao servidor.
    if type(sampSetDialogClientside) == 'function' then
        sampSetDialogClientside(false)
    end
end

local function dialogoMods(id, titulo, texto, botao1, botao2)
    sampShowDialog(id, titulo, texto, botao1, botao2, 2)
    if type(sampSetDialogClientside) == 'function' then
        sampSetDialogClientside(false)
    end
end

local function abrirSeletorTV(busca)
    if not staffLogada then return chat('{FF5555}', 'Entre na staff com /la antes de usar a telagem.') end
    if not moduloAtivo('navegacao_tv') then return chat('{FF5555}', 'Navegacao TV desativada ou bloqueada para o cargo.') end
    busca = trim(busca):lower()
    if busca == 'a' or busca == 'all' or busca == 'todos' or busca == '*' then busca = '' end
    jogadoresSeletorTV = {}
    local linhas = {}
    for _, jogador in ipairs(listaJogadores(false)) do
        local nick = tostring(jogador.nick or '')
        if busca == '' or nick:lower():find(busca, 1, true) then
            local nickBaixo = nick:lower()
            jogador.prioridadeBusca = busca == '' and 3
                or (nickBaixo == busca and 1)
                or (nickBaixo:sub(1, #busca) == busca and 2)
                or 3
            jogadoresSeletorTV[#jogadoresSeletorTV + 1] = jogador
        end
    end
    if #jogadoresSeletorTV == 0 then
        return chat('{FFFF00}', 'Nenhum jogador encontrado para: ' .. busca)
    end
    table.sort(jogadoresSeletorTV, function(a, b)
        if a.prioridadeBusca ~= b.prioridadeBusca then return a.prioridadeBusca < b.prioridadeBusca end
        return a.id < b.id
    end)
    for _, jogador in ipairs(jogadoresSeletorTV) do
        linhas[#linhas + 1] = string.format('%s\tID: %d\tLevel: %d', jogador.nick, jogador.id, jogador.level)
    end
    -- Nome ou abreviacao que encontrou somente uma pessoa: tela imediatamente.
    if busca ~= '' and #jogadoresSeletorTV == 1 then
        local jogador = jogadoresSeletorTV[1]
        telarJogadorPelaTab(jogador)
        return
    end
    dialogo(D_SELETOR_TV, 'SETOR - SELECIONAR PLAYER', table.concat(linhas, '\n'), 'Telar', 'Cancelar', 2)
end

local function capturarHorarioServidor(texto)
    texto = clean(texto):gsub('_', ' '):gsub('%s+', ' ')
    local baixo = texto:lower()
    local levelServidor = texto:match('[Ll][Ee][Vv][Ee][Ll][:%s]+(%d+)')
        or texto:match('[Nn][Ii][Vv][Ee][Ll][:%s]+(%d+)')
    if levelServidor and (painelTvFlutuante or aguardandoReport) then
        levelAtualConfirmado = tonumber(levelServidor)
    end
    -- No /reports, os dados do alvo podem chegar separados em varios
    -- textdraws. Guarda o nick online e so confirma quando o RG tambem chegar.
    if aguardandoReport then
        for id = 0, sampGetMaxPlayerId(false) do
            if sampIsPlayerConnected(id) then
                local nickTab = tostring(sampGetPlayerNickname(id) or '')
                if nickTab ~= '' and baixo:find(nickTab:lower():gsub('_', ' '), 1, true) then
                    reportAlvoNick = nickTab
                    break
                end
            end
        end
        local rgReport = texto:match('[Rr][Gg][:%s]+(%d+)')
        if rgReport then reportAlvoRg = rgReport end
        if reportAlvoRg and reportAlvoNick then
            nickAtual, rgAtual = reportAlvoNick, reportAlvoRg
            salvarRG(reportAlvoRg, reportAlvoNick)
            painelTvFlutuante = true
            enviarAvisoTelagemReport(reportAlvoNick, reportAlvoRg)
            reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
        end
    end
    -- Durante a telagem pela TAB, o RG chega pelos textdraws do servidor.
    -- Vincula esse RG ao nick online selecionado para todas as acoes do painel.
    if painelTvFlutuante then
        local rgTv = texto:match('[Rr][Gg][:%s]+(%d+)')
        if rgTv then
            rgAtual = rgTv
            local nickValido = nickAtual and nickAtual ~= ''
                and nickAtual ~= '?' and nickAtual ~= 'Aguardando servidor'
            if nickValido then
                salvarRG(rgTv, nickAtual)
                enviarAvisoTelagemReport(nickAtual, rgTv)
            end
            if novatoTelagemPendenteId then
                novatoTelagemPendenteId = nil
                local rgNovato = tostring(rgTv)
                lua_thread.create(function()
                    wait(150)
                    sampSendChat('/tv ' .. rgNovato)
                end)
            end
        end
    end
    local temMes = baixo:match('jan') or baixo:match('fev') or baixo:match('mar') or baixo:match('abr')
        or baixo:match('mai') or baixo:match('jun') or baixo:match('jul') or baixo:match('ago')
        or baixo:match('set') or baixo:match('out') or baixo:match('nov') or baixo:match('dez')
    local hora = texto:match('(%d%d?:%d%d:%d%d)')
    if hora and texto:find(',', 1, true) and texto:match('%d%d%d%d') and temMes then
        local meses = {jan=1, fev=2, mar=3, abr=4, mai=5, jun=6, jul=7, ago=8, set=9, out=10, nov=11, dez=12}
        local dia, mesTxt, ano = baixo:match('(%d%d?)%s+([%a]+)%s+(%d%d%d%d)')
        local mes = mesTxt and meses[mesTxt:sub(1, 3)] or nil
        if dia and mes and ano then
            dataServidor = string.format('%02d/%02d/%02d', tonumber(dia), mes, tonumber(ano) % 100)
        end
        horarioServidor = hora
        horarioServidorEm = os.clock and os.clock() or 0
    end
end

local function abrirPrincipal()
    local itens = {}
    local linhas = {}
    local function adicionar(id, titulo, modulo)
        if not modulo or moduloPermitido(modulo) then
            itens[#itens + 1] = id
            linhas[#linhas + 1] = titulo
        end
    end
    adicionar('punicoes', 'Punicoes do jogador', 'painel_tv')
    adicionar('acoes', 'Acoes administrativas', 'acoes_staff')
    adicionar('monitoramento', 'Monitoramento', 'monitoramento')
    adicionar('auto_telagem', 'Auto Telagem', 'navegacao_tv')
    adicionar('cache', 'Cache de RG')
    local temModuloConfiguravel = false
    for id in pairs(MODULOS_INFO) do
        if moduloPermitido(id) then temModuloConfiguravel = true break end
    end
    if temModuloConfiguravel then adicionar('modulos', 'Modulos') end
    adicionar('ajuda', 'Ajuda no chat')
    _G.HZMobileMenuPrincipalItens = itens
    dialogo(D_MAIN, 'SETOR SEGURANCA - MOBILE',
        table.concat(linhas, '\n'),
        'Abrir', 'Fechar', 2)
end

local function abrirTV()
    if not moduloAtivo('navegacao_tv') then return chat('{FF5555}', 'Navegacao TV desativada ou bloqueada para o cargo.') end
    dialogo(D_TV, 'SETOR - AUTO TELAGEM',
        '<  NOVATOS\nNOVATOS  >\n<  JOGADORES\nJOGADORES  >\nMostrar jogador e RG\nDesligar TV',
        'Selecionar', 'Voltar', 2)
end

local function abrirPunicoes()
    if not moduloAtivo('painel_tv') then return chat('{FF5555}', 'Painel TV desativado ou bloqueado para o cargo.') end
    dialogo(D_PUNICOES, 'SETOR - PUNICOES',
        'Tabela de cadeia\nTabela de ban permanente\nTabela de ban temporario\nTabela de mute\nTabela de kick',
        'Continuar', 'Voltar', 2)
end

local function abrirTabelaPunicoes(tipo)
    tipo = tipo or 'cadeia'
    _G.HZMobileTipoTabelaPunicao = tipo
    _G.HZMobileListaTabelaPunicao = tipo == 'cadeia' and PUNICOES_CADEIA
        or (_G.HZMobileTabelasPunicao[tipo] or {})
    local linhas = {}
    for i, item in ipairs(_G.HZMobileListaTabelaPunicao) do
        if tipo == 'cadeia' then
            linhas[i] = item[1] .. ' | ' .. tostring(item[3]) .. ' min'
        else
            linhas[i] = item[1]
        end
    end
    local titulos = {
        cadeia='CADEIA', ban_permanente='BAN PERMANENTE',
        ban_temporario='BAN TEMPORARIO', mute='MUTE', kick='KICK'
    }
    dialogo(D_TABELA_PUNICAO, 'SETOR - TABELA ' .. (titulos[tipo] or 'PUNICAO'),
        table.concat(linhas, '\n'), 'Selecionar', 'Voltar', 2)
end

local function levelDoRG(rg)
    if tostring(rg or '') == tostring(rgAtual or '') and levelAtualConfirmado ~= nil then
        return tonumber(levelAtualConfirmado)
    end
    local info = cache[tostring(rg)]
    local nick = info and tostring(info.nick or ''):lower() or ''
    if nick == '' then return nil end
    for id = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(id) and tostring(sampGetPlayerNickname(id) or ''):lower() == nick then
            local score = tonumber(sampGetPlayerScore(id))
            -- Zero sem confirmacao pode ser apenas o placar ainda nao sincronizado.
            if score and score > 0 then return score end
            return nil
        end
    end
    return nil
end

local function confirmarPunicaoTabela(rg)
    if not moduloAtivo('painel_tv') then return chat('{FF5555}', 'Painel TV desativado ou bloqueado para o cargo.') end
    rg = acharRG(rg) or trim(rg)
    if not rg:match('^%d+$') or not punicaoTabelaSelecionada then
        return chat('{FFFF00}', 'Informe um RG ou nome salvo no cache.')
    end
    local item = punicaoTabelaSelecionada
    local tipoTabela = _G.HZMobileTipoTabelaPunicao or 'cadeia'
    if tipoTabela ~= 'cadeia' then
        local nomes = {
            ban_permanente='BAN PERMANENTE', ban_temporario='BAN TEMPORARIO',
            mute='MUTE', kick='KICK'
        }
        dialogAction = {
            tipo='tabela_' .. tipoTabela, rg=rg,
            nick=nickAtual, motivo=item[2], tempo=tonumber(item[3]) or 0,
            confirmacaoNick=false
        }
        local tempoTexto = (tipoTabela == 'ban_permanente' and 'Permanente')
            or (tipoTabela == 'kick' and 'Imediato')
            or (tostring(item[3]) .. ' dia(s)')
        dialogo(D_CONFIRMAR_TABELA, 'CONFIRMAR ' .. (nomes[tipoTabela] or 'PUNICAO'),
            'Jogador: ' .. tostring(nickAtual or '?') .. '\nRG: ' .. rg
                .. '\nMotivo: ' .. item[2] .. '\nTempo: ' .. tempoTexto,
            'Aplicar', 'Cancelar', 0)
        return
    end
    local level = levelDoRG(rg)
    if level == nil then
        return chat('{FFFF00}', 'Level ainda nao confirmado. Aguarde as informacoes do jogador e tente novamente.')
    end
    local tempo = tonumber(item[3]) or 0
    if level and level >= 0 and level <= 30 then
        tempo = item[2]:lower():find('dark rp', 1, true) and 150 or 50
    end
    dialogAction = {tipo='tabela', rg=rg, motivo=item[2], tempo=tempo, level=level}
    local regra = level and level <= 30 and ('\nREGRA NOVATO LEVEL ' .. level .. ' APLICADA') or ''
    dialogo(D_CONFIRMAR_TABELA, 'CONFIRMAR PUNICAO',
        'RG: ' .. rg .. '\nMotivo: ' .. item[2] .. '\nTempo: ' .. tempo .. ' minutos' .. regra,
        'Aplicar', 'Cancelar', 0)
end

local function abrirAcoes()
    if not moduloAtivo('acoes_staff') then return chat('{FF5555}', 'Acoes Staff desativadas ou bloqueadas para o cargo.') end
    dialogo(D_ACOES, 'SETOR - ACOES',
        'Ir ate jogador\nTrazer jogador\nReviver jogador\nCongelar jogador\nDescongelar jogador\nPrender armas\nChecar jogador\nDefinir vida\nDefinir colete',
        'Continuar', 'Voltar', 2)
end

local function abrirRG()
    dialogo(D_RG, 'SETOR - CACHE DE RG',
        'Buscar por nome ou RG\nMostrar RG atual\nQuantidade no cache\nRemover RG',
        'Abrir', 'Voltar', 2)
end

local function abrirMonitor()
    if not moduloAtivo('monitoramento') then return chat('{FF5555}', 'Monitoramento desativado ou bloqueado para o cargo.') end
    local status = rgAtual and monitorados[tostring(rgAtual)] or nil
    dialogo(D_MONITOR, 'SETOR - MONITORAMENTO',
        'Monitorar jogador atual' .. (status and ' [JA MONITORADO]' or '')
            .. '\nRemover jogador atual do monitoramento\nLista de monitorados',
        'Abrir', 'Voltar', 2)
end

local function abrirListaMonitorados()
    _G.HZMobileMonitorLista = {}
    local linhas = {}
    for rg, info in pairs(monitorados) do
        local jogadorOnline = nil
        for id = 0, sampGetMaxPlayerId(false) do
            if sampIsPlayerConnected(id)
                and tostring(sampGetPlayerNickname(id) or ''):lower() == tostring(info.nick or ''):lower() then
                jogadorOnline = {id=id, nick=sampGetPlayerNickname(id), level=sampGetPlayerScore(id) or 0}
                break
            end
        end
        _G.HZMobileMonitorLista[#_G.HZMobileMonitorLista + 1] = {
            rg=tostring(rg), info=info, jogador=jogadorOnline
        }
    end
    table.sort(_G.HZMobileMonitorLista, function(a, b)
        if (a.jogador ~= nil) ~= (b.jogador ~= nil) then return a.jogador ~= nil end
        return tostring(a.info.nick) < tostring(b.info.nick)
    end)
    for i, item in ipairs(_G.HZMobileMonitorLista) do
        linhas[i] = string.format('%s | RG %s | %s | %s',
            tostring(item.info.nick), item.rg, item.jogador and 'ONLINE' or 'OFFLINE',
            tostring(item.info.motivo))
    end
    if #linhas == 0 then
        return chat('{FFFF00}', 'Lista de monitorados vazia.')
    end
    dialogo(28022, 'SETOR - JOGADORES MONITORADOS', table.concat(linhas, '\n'),
        'Telar', 'Voltar', 2)
end
_G.HZMobileAbrirListaMonitorados = abrirListaMonitorados

local function abrirModulos(categoriaNome)
    if not exigirStaff('/mods') then return end
    local linhas = {}
    modsCategoriaAtual = categoriaNome
    if not categoriaNome then
        _G.HZMobileModsCategoriasVisiveis = {}
        for _, categoria in ipairs(MODULOS_CATEGORIAS) do
            local ativos, permitidos = 0, 0
            for _, id in ipairs(categoria[3]) do
                if moduloPermitido(id) then
                    permitidos = permitidos + 1
                    if moduloAtivo(id) then ativos = ativos + 1 end
                end
            end
            if permitidos > 0 then
                _G.HZMobileModsCategoriasVisiveis[#_G.HZMobileModsCategoriasVisiveis + 1] = categoria
                linhas[#linhas + 1] = string.format('{48C6FF}%s {A8B5C8}[%d/%d ativos] - %s',
                    categoria[1], ativos, permitidos, categoria[2])
            end
        end
        if #linhas == 0 then linhas[1] = '{A8B5C8}Nenhum modulo configuravel para este cargo.' end
        dialogoMods(D_MODULOS,
            'SETOR ADVANCED | CATEGORIAS | ' .. tostring(cfg.dados.nome) .. ' - ' .. tostring(cfg.dados.cargo),
            table.concat(linhas, '\n'), 'ABRIR', 'FECHAR')
        return
    end
    local ids = {}
    for _, categoria in ipairs(MODULOS_CATEGORIAS) do
        if categoria[1] == categoriaNome then ids = categoria[3] break end
    end
    _G.HZMobileModsIdsVisiveis = {}
    for _, id in ipairs(ids) do
        if moduloPermitido(id) then
            _G.HZMobileModsIdsVisiveis[#_G.HZMobileModsIdsVisiveis + 1] = id
            local info = MODULOS_INFO[id]
            local estado, cor
            if cfg.modulos[id] ~= false then estado, cor = 'ATIVO', '{3EDC81}'
            else estado, cor = 'DESATIVADO', '{FFB347}' end
            linhas[#linhas + 1] = string.format('{FFFFFF}%s  %s[%s]{A8B5C8} - %s',
                info[1], cor, estado, info[2])
        end
    end
    dialogoMods(D_MOD_CATEGORIA,
        'SETOR ADVANCED | ' .. categoriaNome .. ' | ' .. tostring(cfg.dados.nome) .. ' - ' .. tostring(cfg.dados.cargo),
        table.concat(linhas, '\n'), 'ALTERAR', 'VOLTAR')
end

local function pedirAcao(acao, instrucao)
    if rgAtual and rgAtual:match('^%d+$') then
        dialogAction = {tipo='acao_atual', acao=acao, rg=rgAtual}
        dialogo(D_INPUT_ACAO, 'SETOR - ' .. tostring(nickAtual or 'JOGADOR'),
            instrucao or ('Alvo: ' .. tostring(nickAtual or '?') .. ' | RG ' .. rgAtual),
            'Executar', 'Cancelar', 1)
    else
        dialogAction = acao
        dialogo(D_INPUT_ACAO, 'SETOR - INFORME O ALVO', instrucao or 'Digite o RG ou nome salvo no cache:', 'Executar', 'Cancelar', 1)
    end
end

local function executarAcaoDialogo(valor)
    if not exigirStaff('as acoes administrativas') then return end
    if not moduloAtivo('acoes_staff') then return chat('{FF5555}', 'Acoes Staff desativadas ou bloqueadas para o cargo.') end
    local acao = dialogAction
    dialogAction = nil
    if not acao then return end
    if type(acao) == 'table' and acao.tipo == 'acao_atual' then
        local quantidade = trim(valor):match('^(%d+)$')
        if not quantidade then return chat('{FFFF00}', 'Digite somente o valor. Exemplo: 100') end
        local comando = acao.acao == 'vida' and 'setvida' or 'setcolete'
        sampSendChat('/' .. comando .. ' ' .. acao.rg .. ' ' .. quantidade)
        logAcao(comando:upper(), acao.rg, quantidade)
        return
    end
    if acao == 'vida' or acao == 'colete' then
        local alvo, quantidade = trim(valor):match('^(%S+)%s+(%d+)$')
        local rg = alvo and (acharRG(alvo) or alvo)
        if not rg or not rg:match('^%d+$') then return chat('{FFFF00}', 'Formato invalido. Informe: RG-ou-nome valor') end
        local comando = acao == 'vida' and 'setvida' or 'setcolete'
        sampSendChat('/' .. comando .. ' ' .. rg .. ' ' .. quantidade)
        logAcao(comando:upper(), rg, quantidade)
        return
    end
    local mapa = {
        ir={'ir','IR'}, trazer={'trazer','TRAZER'}, reviver={'reviver','REVIVER'},
        congelar={'congelar','CONGELAR'}, descongelar={'descongelar','DESCONGELAR'},
        armas={'prenderarmas','PRENDERARMAS'}, checar={'checar','CHECAR'}
    }
    local dados = mapa[acao]
    local rg = acharRG(valor) or trim(valor)
    if not dados or not rg:match('^%d+$') then return chat('{FFFF00}', 'Informe um RG ou nome salvo no cache.') end
    sampSendChat('/' .. dados[1] .. ' ' .. rg)
    logAcao(dados[2], rg)
end

local function executarAcaoNoTelado(acao)
    if not exigirStaff('as acoes administrativas') then return end
    if not moduloAtivo('acoes_staff') then return chat('{FF5555}', 'Acoes Staff desativadas ou bloqueadas para o cargo.') end
    if not rgAtual or not tostring(rgAtual):match('^%d+$') then
        return chat('{FFFF00}', 'Aguarde o RG do jogador aparecer no Painel TV.')
    end
    local mapa = {
        ir={'ir','IR'}, trazer={'trazer','TRAZER'}, reviver={'reviver','REVIVER'},
        congelar={'congelar','CONGELAR'}, descongelar={'descongelar','DESCONGELAR'},
        armas={'prenderarmas','PRENDERARMAS'}, checar={'checar','CHECAR'}
    }
    local dados = mapa[acao]
    if not dados then return end
    sampSendChat('/' .. dados[1] .. ' ' .. rgAtual)
    logAcao(dados[2], rgAtual)
end
_G.HZMobileExecutarAcaoNoTelado = executarAcaoNoTelado

local function pedirPunicao(tipo)
    local alvoAtual = rgAtual and tostring(rgAtual):match('^%d+$')
    dialogAction = alvoAtual and {tipo=tipo, rg=rgAtual, nick=nickAtual} or tipo
    local instrucoes = alvoAtual and {
        ban='Digite somente o motivo',
        bantemp='Formato: dias motivo',
        cadeia='Formato: minutos motivo',
        mute='Formato: dias motivo'
    } or {
        ban='Formato: RG motivo', bantemp='Formato: RG dias motivo',
        cadeia='Formato: RG minutos motivo', mute='Formato: Nick RG dias motivo'
    }
    dialogo(D_INPUT_PUNICAO, 'SETOR - PUNICAO', instrucoes[tipo], 'Enviar', 'Cancelar', 1)
end

local function executarPunicaoDialogo(valor)
    if not exigirStaff('as punicoes') then return end
    if not moduloAtivo('painel_tv') then return chat('{FF5555}', 'Painel TV desativado ou bloqueado para o cargo.') end
    local tipo = dialogAction
    dialogAction = nil
    valor = trim(valor)
    if type(tipo) == 'table' then
        local dados = tipo
        tipo = dados.tipo
        if tipo == 'ban' then
            if valor == '' then return chat('{FFFF00}', 'Digite o motivo.') end
            sampSendChat('/ban ' .. dados.rg .. ' ' .. valor)
        elseif tipo == 'bantemp' then
            local dias, motivo = valor:match('^(%d+)%s+(.+)$')
            if not dias then return chat('{FFFF00}', 'Formato: dias motivo') end
            sampSendChat('/bantemp ' .. dados.rg .. ' ' .. dias .. ' ' .. motivo)
        elseif tipo == 'cadeia' then
            local minutos, motivo = valor:match('^(%d+)%s+(.+)$')
            if not minutos then return chat('{FFFF00}', 'Formato: minutos motivo') end
            sampSendChat('/punicao ' .. dados.rg .. ' ' .. minutos .. ' ' .. motivo)
        elseif tipo == 'mute' then
            local dias, motivo = valor:match('^(%d+)%s+(.+)$')
            if not dias then return chat('{FFFF00}', 'Formato: dias motivo') end
            logPunicao(tostring(dados.nick or '?'), dados.rg, dias .. ' dias', motivo, 'mutou', WEBHOOKS.MUTE, 'MUTE')
        end
        return
    end
    if tipo == 'ban' then
        local rg, motivo = valor:match('^(%d+)%s+(.+)$')
        if not rg then return chat('{FFFF00}', 'Formato: RG motivo') end
        sampSendChat('/ban ' .. rg .. ' ' .. motivo)
    elseif tipo == 'bantemp' then
        local rg, dias, motivo = valor:match('^(%d+)%s+(%d+)%s+(.+)$')
        if not rg then return chat('{FFFF00}', 'Formato: RG dias motivo') end
        sampSendChat('/bantemp ' .. rg .. ' ' .. dias .. ' ' .. motivo)
    elseif tipo == 'cadeia' then
        local rg, minutos, motivo = valor:match('^(%d+)%s+(%d+)%s+(.+)$')
        if not rg then return chat('{FFFF00}', 'Formato: RG minutos motivo') end
        sampSendChat('/punicao ' .. rg .. ' ' .. minutos .. ' ' .. motivo)
    elseif tipo == 'mute' then
        local nick, rg, dias, motivo = valor:match('^(%S+)%s+(%d+)%s+(%d+)%s+(.+)$')
        if not nick then return chat('{FFFF00}', 'Formato: Nick RG dias motivo') end
        logPunicao(nick, rg, dias .. ' dias', motivo, 'mutou', WEBHOOKS.MUTE, 'MUTE')
    end
end

local function registrarComandos()
    sampRegisterChatCommand('setor', function()
        if not staffLogada then return chat('{FF5555}', 'Entre na staff com /la antes de abrir o painel.') end
        abrirPrincipal()
    end)
    if not HAS_EXTERNAL_UPDATER then
        sampRegisterChatCommand('setorversao', function()
            chat('{48C6FF}', 'Versao instalada: ' .. VERSION)
            verificarAtualizacao(false)
        end)
        sampRegisterChatCommand('setoratualizar', instalarAtualizacao)
    end
    sampRegisterChatCommand('configadm', function(arg)
        local nome, id = trim(arg):match('^(%S+)%s+([1-5])$')
        if not nome then return chat('{FF5555}', 'Use /configadm Nome 1-5: Ajudante, Moderador, Administrador, Coordenador ou Diretor.') end
        definirPerfil(nome, CARGOS[id], false)
        chat('{3EDC81}', 'Perfil definido: ' .. cfg.dados.cargo .. ' ' .. nome)
    end)
    sampRegisterChatCommand('mods', function()
        if not staffLogada then
            return sampAddChatMessage('{FF6B6B}[MODS] Entre na staff para acessar os modulos.', -1)
        end
        abrirModulos()
    end)
    sampRegisterChatCommand('tvpainel', function()
        if not exigirStaff('/tvpainel') then return end
        if not painelTvFlutuante then return chat('{FFFF00}', 'Tele um jogador antes de abrir o Painel TV.') end
        abrirTV()
    end)
    sampRegisterChatCommand('tvhud', function()
        if not exigirStaff('/tvhud') then return end
        cfg.interface.painel_tv_visivel = cfg.interface.painel_tv_visivel == false
        inicfg.save(cfg, CONFIG_FILE)
        chat('{48C6FF}', 'Painel flutuante ' .. (cfg.interface.painel_tv_visivel and 'ativado.' or 'ocultado.'))
    end)
    sampRegisterChatCommand('tvpos', function(arg)
        if not exigirStaff('/tvpos') then return end
        local x, y = trim(arg):match('^(%d+)%s+(%d+)$')
        if not x then return chat('{FFFF00}', 'Use /tvpos X Y. Exemplo: /tvpos 20 250') end
        cfg.interface.painel_tv_x, cfg.interface.painel_tv_y = tonumber(x), tonumber(y)
        inicfg.save(cfg, CONFIG_FILE)
        chat('{48C6FF}', 'Posicao do Painel TV salva.')
    end)
    sampRegisterChatCommand('modulo', function(arg)
        if not exigirStaff('/modulo') then return end
        local nome, estado = trim(arg):match('^(%S+)%s+(on|off)$')
        if nome == 'navegacao' then nome = 'navegacao_tv' end
        if nome == 'atalhos' then nome = 'acoes_staff' end
        if nome == 'logs' then return chat('{FF5555}', 'Logs sao obrigatorios e permanecem sempre ativos.') end
        if not nome or not MODULOS_INFO[nome] then
            return chat('{FFFF00}', 'Use /modulo atendimento|painel_tv|navegacao_tv|monitoramento|acoes_staff on|off')
        end
        if not moduloPermitido(nome) then return chat('{FF5555}', 'Modulo bloqueado para o seu cargo.') end
        cfg.modulos[nome] = estado == 'on'
        inicfg.save(cfg, CONFIG_FILE)
        chat('{3EDC81}', nome .. ' = ' .. estado)
    end)
    sampRegisterChatCommand('rgnome', function(arg)
        if not exigirStaff('/rgnome') then return end
        local rg, nick, total = acharRG(arg)
        if rg then chat('{3EDC81}', nick .. ' - RG ' .. rg) elseif total and total > 1 then chat('{FFFF00}', 'Mais de um resultado; refine o nome.') else chat('{FF5555}', 'Nao encontrado no cache.') end
    end)
    sampRegisterChatCommand('rgatual', function()
        if not exigirStaff('/rgatual') then return end
        if rgAtual then chat('{3EDC81}', (nickAtual or '?') .. ' - RG ' .. rgAtual) else chat('{FFFF00}', 'Nenhum jogador telado foi identificado.') end
    end)
    sampRegisterChatCommand('rgcache', function()
        if not exigirStaff('/rgcache') then return end
        local n = 0 for _ in pairs(cache) do n = n + 1 end
        chat('{3EDC81}', n .. ' RG(s) no cache mobile.')
    end)
    sampRegisterChatCommand('rgdel', function(arg)
        if not exigirStaff('/rgdel') then return end
        local rg = trim(arg)
        if cache[rg] then cache[rg] = nil salvarTabela(CACHE_FILE, cache) chat('{3EDC81}', 'RG ' .. rg .. ' removido.') else chat('{FF5555}', 'RG inexistente.') end
    end)
    sampRegisterChatCommand('monitor', function(arg)
        if not exigirStaff('/monitor') then return end
        if not moduloAtivo('monitoramento') then return chat('{FF5555}', 'Monitoramento desativado ou bloqueado para o cargo.') end
        local alvo, motivo = trim(arg):match('^(%S+)%s+(.+)$')
        if not alvo then return chat('{FFFF00}', 'Use /monitor RG-ou-nome motivo') end
        local rg, nick = acharRG(alvo)
        if not rg and alvo:match('^%d+$') then rg, nick = alvo, 'Desconhecido' end
        if not rg then return chat('{FF5555}', 'Jogador nao localizado no cache.') end
        monitorados[rg] = { nick = nick, motivo = motivo }
        salvarTabela(MONITOR_FILE, monitorados)
        chat('{3EDC81}', nick .. ' [RG ' .. rg .. '] monitorado: ' .. motivo)
    end)
    sampRegisterChatCommand('desmonitor', function(arg)
        if not exigirStaff('/desmonitor') then return end
        local rg = acharRG(arg) or trim(arg)
        if monitorados[rg] then monitorados[rg] = nil salvarTabela(MONITOR_FILE, monitorados) chat('{3EDC81}', 'RG ' .. rg .. ' removido dos monitorados.') else chat('{FFFF00}', 'RG nao monitorado.') end
    end)
    sampRegisterChatCommand('monitorados', function()
        if not exigirStaff('/monitorados') then return end
        local n = 0
        for rg, info in pairs(monitorados) do n = n + 1 chat('{48C6FF}', info.nick .. ' [RG ' .. rg .. '] - ' .. info.motivo) end
        if n == 0 then chat('{FFFF00}', 'Lista de monitorados vazia.') end
    end)
    sampRegisterChatCommand('ss', function()
        if not exigirStaff('/ss') then return end
        if not moduloAtivo('monitoramento') then
            return chat('{FF5555}', 'Monitoramento desativado ou bloqueado para o cargo.')
        end
        if MIMGUI_OK then
            monitorSsAberto = true
        else
            _G.HZMobileAbrirListaMonitorados()
        end
    end)
    sampRegisterChatCommand('tvn', function() navegar(true, 1) end)
    sampRegisterChatCommand('tvnvoltar', function() navegar(true, -1) end)
    sampRegisterChatCommand('tva', function() navegar(false, 1) end)
    sampRegisterChatCommand('tavoltar', function() navegar(false, -1) end)

    local atalhos = {
        setorir = {'ir', 'IR'}, setortrazer = {'trazer', 'TRAZER'}, setorreviver = {'reviver', 'REVIVER'},
        setorcongelar = {'congelar', 'CONGELAR'}, setordescongelar = {'descongelar', 'DESCONGELAR'},
        setorarmas = {'prenderarmas', 'PRENDERARMAS'}
    }
    for nome, dados in pairs(atalhos) do
        sampRegisterChatCommand(nome, function(arg)
            if not exigirStaff('/' .. nome) then return end
            if not moduloAtivo('acoes_staff') then return chat('{FF5555}', 'Acoes Staff desativadas ou bloqueadas para o cargo.') end
            local rg = acharRG(arg) or trim(arg)
            if not rg:match('^%d+$') then return chat('{FFFF00}', 'Informe um RG ou nome salvo no cache.') end
            sampSendChat('/' .. dados[1] .. ' ' .. rg)
            logAcao(dados[2], rg)
        end)
    end
    sampRegisterChatCommand('setorvida', function(arg)
        if not exigirStaff('/setorvida') then return end
        if not moduloAtivo('acoes_staff') then return chat('{FF5555}', 'Acoes Staff desativadas ou bloqueadas para o cargo.') end
        local alvo, valor = trim(arg):match('^(%S+)%s+(%d+)$'); local rg = alvo and (acharRG(alvo) or alvo)
        if not rg or not rg:match('^%d+$') then return chat('{FFFF00}', 'Use /setorvida RG-ou-nome valor') end
        sampSendChat('/setvida ' .. rg .. ' ' .. valor); logAcao('SETVIDA', rg, valor)
    end)
    sampRegisterChatCommand('setorcolete', function(arg)
        if not exigirStaff('/setorcolete') then return end
        if not moduloAtivo('acoes_staff') then return chat('{FF5555}', 'Acoes Staff desativadas ou bloqueadas para o cargo.') end
        local alvo, valor = trim(arg):match('^(%S+)%s+(%d+)$'); local rg = alvo and (acharRG(alvo) or alvo)
        if not rg or not rg:match('^%d+$') then return chat('{FFFF00}', 'Use /setorcolete RG-ou-nome valor') end
        sampSendChat('/setcolete ' .. rg .. ' ' .. valor); logAcao('SETCOLETE', rg, valor)
    end)
    sampRegisterChatCommand('mu', function(arg)
        if not exigirStaff('/mu') then return end
        if not moduloAtivo('painel_tv') then return chat('{FF5555}', 'Painel TV desativado ou bloqueado para o cargo.') end
        local nick, rg, dias, motivo = trim(arg):match('^(%S+)%s+(%d+)%s+(%d+)%s+(.+)$')
        if not nick then return chat('{FFFF00}', 'Use /mu Nick RG dias motivo') end
        logPunicao(nick, rg, dias .. ' dias', motivo, 'mutou', WEBHOOKS.MUTE, 'MUTE')
    end)
end

-- Captura tanto o clique manual no TAB quanto o clique enviado pela nossa
-- lista de nomes. Assim o Painel TV nao depende do comando /tv para abrir.
function samp.onSendClickPlayer(playerId, source)
    if not staffLogada or not moduloAtivo('painel_tv') then return end
    local id = tonumber(playerId)
    if not id or not sampIsPlayerConnected(id) then return end
    nickAtual = tostring(sampGetPlayerNickname(id) or '?')
    rgAtual = nil
    levelAtualConfirmado = nil
    painelTvFlutuante = true
    -- O servidor pode concluir a escolha do /reports simulando o mesmo clique
    -- usado pelo TAB. Nesse caso, preserva a autorizacao temporaria para que a
    -- confirmacao da telagem envie o aviso no /ac.
    local agora = os.clock and os.clock() or 0
    local cliqueImediatoDoReport = aguardandoReport and reportSelecaoEm > 0
        and agora - reportSelecaoEm <= 2 and agora <= reportAte
    if not cliqueImediatoDoReport then
        aguardandoReport, reportDialogId, reportAte = false, -1, 0
        reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
    end
end

function samp.onPlayerQuit(playerId, reason)
    if not emAtendimento then return end
    local nickSaida = ''
    if type(sampGetPlayerNickname) == 'function' then
        local ok, valor = pcall(sampGetPlayerNickname, tonumber(playerId))
        if ok then nickSaida = tostring(valor or '') end
    end
    local saiuAtendido = tostring(playerId) == tostring(atendimentoRg)
        or (nickSaida ~= '' and nickSaida:lower() == tostring(atendimentoNick):lower())
    if saiuAtendido then
        atendimentoTempoFinal = math.max(0, relogioAtendimento()
            - (tonumber(atendimentoInicio) or relogioAtendimento()))
        emAtendimento, atendimentoOffAte = false, relogioAtendimento() + 5
        chat('{FF5555}', 'Atendimento encerrado: ' .. atendimentoNick .. ' desconectou.')
    end
end

function samp.onShowTextDraw(id, data)
    if type(data) == 'table' then capturarHorarioServidor(data.text) end
end

function samp.onTextDrawSetString(id, text)
    capturarHorarioServidor(text)
end

function samp.onShowPlayerTextDraw(playerId, id, data)
    if type(data) == 'table' then capturarHorarioServidor(data.text) end
end

function samp.onPlayerTextDrawSetString(playerId, id, text)
    capturarHorarioServidor(text)
end

function samp.onShowDialog(dialogId, style, title, button1, button2, text)
    local agora = os.clock and os.clock() or 0
    local tituloLimpo = clean(title):lower()
    local ehListaReports = tituloLimpo:find('report', 1, true)
        or tituloLimpo:find('denuncia', 1, true)
    if (reportDialogId == -2 and agora <= reportAte)
        or (staffLogada and ehListaReports) then
        reportDialogId = tonumber(dialogId) or -1
        reportDialogTexto = tostring(text or '')
        reportAte = agora + 60
    end
end

local function processarRespostaReport(dialogId, button, listboxId, input)
    if tonumber(dialogId) == tonumber(reportDialogId) then
        reportDialogId = -1
        aguardandoReport = tonumber(button) == 1
        reportAte = aguardandoReport and ((os.clock and os.clock() or 0) + 15) or 0
        if aguardandoReport then
            -- A linha da lista pertence ao reportador. O alvo correto so sera
            -- definido quando o servidor responder com as informacoes da telagem.
            painelTvFlutuante, nickAtual, rgAtual, levelAtualConfirmado = false, nil, nil, nil
            reportAlvoNick, reportAlvoRg = nil, nil
            reportSelecaoEm = os.clock and os.clock() or 0
        end
        reportDialogTexto = ''
        return true
    end
    return false
end
_G.HZMobileProcessarRespostaReport = processarRespostaReport

function samp.onSendDialogResponse(dialogId, button, listboxId, input)
    if _G.HZMobileProcessarRespostaReport(dialogId, button, listboxId, input) then return end
    -- Retorna false para impedir que respostas dos nossos dialogos locais sejam enviadas ao servidor.
    if dialogId < D_MAIN or dialogId > 28022 then return end
    if not staffLogada then
        sampAddChatMessage('{FF6B6B}[SETOR] Sessao da staff encerrada. Use /la para acessar as ferramentas.', -1)
        return false
    end

    if button == 0 then
        if dialogId == D_MAIN then return false end
        if dialogId == D_TV then
            lua_thread.create(function() wait(150) abrirPrincipal() end)
            return false
        end
        if dialogId == D_SELETOR_TV then return false end
        if dialogId == D_MODULOS then return false end
        if dialogId == D_TABELA_PUNICAO then
            lua_thread.create(function() wait(150) abrirPunicoes() end)
            return false
        end
        if dialogId == D_CONFIRMAR_TABELA or dialogId == D_INPUT_ALVO_TABELA then
            dialogAction = nil
            lua_thread.create(function()
                wait(150)
                abrirTabelaPunicoes(_G.HZMobileTipoTabelaPunicao or 'cadeia')
            end)
            return false
        end
        if dialogId == D_PUNICOES then
            lua_thread.create(function() wait(150) abrirPrincipal() end)
            return false
        end
        if dialogId == D_INPUT_MONITOR or dialogId == D_INPUT_DESMONITOR then
            lua_thread.create(function() wait(150) abrirMonitor() end)
            return false
        end
        if dialogId == 28022 then
            lua_thread.create(function() wait(150) abrirMonitor() end)
            return false
        end
        if dialogId == D_MOD_CATEGORIA then
            lua_thread.create(function() wait(150) abrirModulos() end)
            return false
        end
        if dialogId == D_INPUT_ACAO or dialogId == D_INPUT_PUNICAO or
           dialogId == D_INPUT_RG_BUSCA or dialogId == D_INPUT_RG_DEL then
            abrirPrincipal()
        elseif dialogId == D_TV or dialogId == D_ACOES or
               dialogId == D_RG or dialogId == D_MONITOR or dialogId == D_SELETOR_TV then
            abrirPrincipal()
        end
        return false
    end

    if dialogId == D_MODULOS then
        local categoria = (_G.HZMobileModsCategoriasVisiveis or {})[(tonumber(listboxId) or -1) + 1]
        if categoria then
            local nomeCategoria = categoria[1]
            lua_thread.create(function() wait(150) abrirModulos(nomeCategoria) end)
        end
    elseif dialogId == D_MOD_CATEGORIA then
        local id = (_G.HZMobileModsIdsVisiveis or {})[(tonumber(listboxId) or -1) + 1]
        if id then
            if not moduloPermitido(id) then
                chat('{FF5555}', 'Funcao bloqueada para o cargo ' .. tostring(cfg.dados.cargo) .. '.')
            else
                cfg.modulos[id] = cfg.modulos[id] == false
                inicfg.save(cfg, CONFIG_FILE)
            end
            lua_thread.create(function() wait(150) abrirModulos(modsCategoriaAtual) end)
        end
    elseif dialogId == D_SELETOR_TV then
        local jogador = jogadoresSeletorTV[(tonumber(listboxId) or -1) + 1]
        if jogador then
            _G.HZMobileTelarPelaTab(jogador)
        end
    elseif dialogId == D_MAIN then
        local itemMenu = (_G.HZMobileMenuPrincipalItens or {})[(tonumber(listboxId) or -1) + 1]
        if itemMenu == 'punicoes' then abrirPunicoes()
        elseif itemMenu == 'acoes' then abrirAcoes()
        elseif itemMenu == 'monitoramento' then abrirMonitor()
        elseif itemMenu == 'auto_telagem' then abrirTV()
        elseif itemMenu == 'cache' then abrirRG()
        elseif itemMenu == 'modulos' then abrirModulos()
        elseif itemMenu == 'ajuda' then mostrarAjuda() abrirPrincipal() end
    elseif dialogId == D_TV then
        if listboxId == 0 then navegar(true, -1)
        elseif listboxId == 1 then navegar(true, 1)
        elseif listboxId == 2 then navegar(false, -1)
        elseif listboxId == 3 then navegar(false, 1)
        elseif listboxId == 4 then
            if rgAtual then chat('{3EDC81}', (nickAtual or '?') .. ' - RG ' .. rgAtual) else chat('{FFFF00}', 'Nenhum RG atual identificado.') end
        elseif listboxId == 5 then
            sampSendChat('/tvoff')
            painelTvFlutuante, rgAtual, nickAtual, novatoTelagemPendenteId = false, nil, nil, nil
        end
        if listboxId >= 0 and listboxId <= 4 then
            lua_thread.create(function()
                wait(250)
                abrirTV()
            end)
        end
    elseif dialogId == D_PUNICOES then
        local tiposTabela = {'cadeia', 'ban_permanente', 'ban_temporario', 'mute', 'kick'}
        local tipoTabela = tiposTabela[listboxId + 1]
        if tipoTabela then abrirTabelaPunicoes(tipoTabela) end
    elseif dialogId == D_TABELA_PUNICAO then
        punicaoTabelaSelecionada = (_G.HZMobileListaTabelaPunicao or {})[listboxId + 1]
        if punicaoTabelaSelecionada then
            if rgAtual and tostring(rgAtual):match('^%d+$') then
                confirmarPunicaoTabela(rgAtual)
            else
                dialogo(D_INPUT_ALVO_TABELA, 'SETOR - ALVO DA PUNICAO', 'Digite o RG ou nome salvo no cache:', 'Continuar', 'Cancelar', 1)
            end
        end
    elseif dialogId == D_INPUT_ALVO_TABELA then
        confirmarPunicaoTabela(input)
    elseif dialogId == D_CONFIRMAR_TABELA then
        if not moduloAtivo('painel_tv') then
            chat('{FF5555}', 'Painel TV desativado ou bloqueado para o cargo.')
            dialogAction = nil
        elseif type(dialogAction) == 'table' then
            if dialogAction.tipo == 'tabela' then
                sampSendChat('/punicao ' .. dialogAction.rg .. ' ' .. dialogAction.tempo .. ' ' .. dialogAction.motivo)
            elseif dialogAction.tipo == 'tabela_ban_permanente' then
                if tostring(dialogAction.motivo):lower() == 'nick improprio' then
                    if not dialogAction.confirmacaoNick then
                        dialogAction.confirmacaoNick = true
                        dialogo(D_CONFIRMAR_TABELA, 'CONFIRMACAO FINAL - NICK IMPROPRIO',
                            'Jogador: ' .. tostring(dialogAction.nick or '?')
                                .. '\nRG: ' .. tostring(dialogAction.rg)
                                .. '\n\nSera aplicado KICK e depois BAN PERMANENTE.',
                            'CONFIRMAR', 'CANCELAR', 0)
                        return false
                    end
                    local rgNick = tostring(dialogAction.rg)
                    lua_thread.create(function()
                        sampSendChat('/kick ' .. rgNick .. ' Nick improprio')
                        wait(1000)
                        sampSendChat('/ban ' .. rgNick .. ' Nick improprio')
                    end)
                else
                    sampSendChat('/ban ' .. dialogAction.rg .. ' ' .. dialogAction.motivo)
                end
            elseif dialogAction.tipo == 'tabela_ban_temporario' then
                sampSendChat('/bantemp ' .. dialogAction.rg .. ' ' .. dialogAction.tempo .. ' ' .. dialogAction.motivo)
            elseif dialogAction.tipo == 'tabela_mute' then
                sampSendChat('/mute ' .. dialogAction.rg .. ' ' .. dialogAction.tempo .. ' ' .. dialogAction.motivo)
            elseif dialogAction.tipo == 'tabela_kick' then
                sampSendChat('/kick ' .. dialogAction.rg .. ' ' .. dialogAction.motivo)
            end
            dialogAction, punicaoTabelaSelecionada = nil, nil
        end
    elseif dialogId == D_ACOES then
        local acoes = {'ir', 'trazer', 'reviver', 'congelar', 'descongelar', 'armas', 'checar', 'vida', 'colete'}
        local acao = acoes[listboxId + 1]
        if acao == 'vida' or acao == 'colete' then
            pedirAcao(acao, rgAtual and 'Digite somente o valor\nExemplo: 100' or 'Digite: RG-ou-nome valor\nExemplo: 12345 100')
        elseif acao then _G.HZMobileExecutarAcaoNoTelado(acao) end
    elseif dialogId == D_INPUT_ACAO then
        executarAcaoDialogo(input)
    elseif dialogId == D_INPUT_PUNICAO then
        executarPunicaoDialogo(input)
    elseif dialogId == D_RG then
        if listboxId == 0 then dialogo(D_INPUT_RG_BUSCA, 'BUSCAR RG', 'Digite o nome ou RG:', 'Buscar', 'Cancelar', 1)
        elseif listboxId == 1 then
            if rgAtual then chat('{3EDC81}', (nickAtual or '?') .. ' - RG ' .. rgAtual) else chat('{FFFF00}', 'Nenhum RG atual identificado.') end
            lua_thread.create(function() wait(150) abrirRG() end)
        elseif listboxId == 2 then
            local n = 0 for _ in pairs(cache) do n = n + 1 end
            chat('{3EDC81}', n .. ' RG(s) no cache mobile.')
            lua_thread.create(function() wait(150) abrirRG() end)
        elseif listboxId == 3 then dialogo(D_INPUT_RG_DEL, 'REMOVER RG', 'Digite o RG que deseja remover:', 'Remover', 'Cancelar', 1) end
    elseif dialogId == D_INPUT_RG_BUSCA then
        local rg, nick, total = acharRG(input)
        if rg then chat('{3EDC81}', nick .. ' - RG ' .. rg) elseif total and total > 1 then chat('{FFFF00}', 'Mais de um resultado; refine o nome.') else chat('{FF5555}', 'Nao encontrado no cache.') end
    elseif dialogId == D_INPUT_RG_DEL then
        local rg = trim(input)
        if cache[rg] then cache[rg] = nil salvarTabela(CACHE_FILE, cache) chat('{3EDC81}', 'RG ' .. rg .. ' removido.') else chat('{FF5555}', 'RG inexistente.') end
    elseif dialogId == D_MONITOR then
        if listboxId == 0 then
            if not rgAtual then return chat('{FFFF00}', 'Aguarde o RG do jogador telado aparecer.') end
            dialogo(D_INPUT_MONITOR, 'MONITORAR JOGADOR',
                'Alvo: ' .. tostring(nickAtual or '?') .. ' | RG ' .. rgAtual .. '\nDigite somente o motivo',
                monitorados[tostring(rgAtual)] and 'Atualizar' or 'Adicionar', 'Cancelar', 1)
        elseif listboxId == 1 then
            local rg = rgAtual and tostring(rgAtual) or nil
            if not rg then
                chat('{FFFF00}', 'Aguarde o RG do jogador telado aparecer.')
            elseif monitorados[rg] then
                monitorados[rg] = nil
                salvarTabela(MONITOR_FILE, monitorados)
                chat('{3EDC81}', tostring(nickAtual or rg) .. ' removido do monitoramento.')
            else
                chat('{FFFF00}', 'O jogador atual nao esta monitorado.')
            end
            lua_thread.create(function() wait(150) abrirMonitor() end)
        elseif listboxId == 2 then _G.HZMobileAbrirListaMonitorados() end
    elseif dialogId == 28022 then
        local item = (_G.HZMobileMonitorLista or {})[(tonumber(listboxId) or -1) + 1]
        if item then
            if item.jogador then
                _G.HZMobileTelarPelaTab(item.jogador)
            else
                chat('{FFFF00}', tostring(item.info.nick) .. ' esta offline.')
                lua_thread.create(function() wait(150) _G.HZMobileAbrirListaMonitorados() end)
            end
        end
    elseif dialogId == D_INPUT_MONITOR then
        local rg, nick, motivo
        if rgAtual and tostring(rgAtual):match('^%d+$') then
            rg, nick, motivo = rgAtual, nickAtual or 'Desconhecido', trim(input)
        else
            local alvo
            alvo, motivo = trim(input):match('^(%S+)%s+(.+)$')
            rg, nick = alvo and acharRG(alvo)
            if not rg and alvo and alvo:match('^%d+$') then rg, nick = alvo, 'Desconhecido' end
        end
        if not rg then chat('{FF5555}', 'Jogador nao localizado no cache.')
        else monitorados[rg] = {nick=nick, motivo=motivo} salvarTabela(MONITOR_FILE, monitorados) chat('{3EDC81}', nick .. ' [RG ' .. rg .. '] adicionado.') end
    elseif dialogId == D_INPUT_DESMONITOR then
        local rg = acharRG(input) or trim(input)
        if monitorados[rg] then monitorados[rg] = nil salvarTabela(MONITOR_FILE, monitorados) chat('{3EDC81}', 'RG ' .. rg .. ' removido.') else chat('{FFFF00}', 'RG nao monitorado.') end
    end
    return false
end

function samp.onSendCommand(command)
    local cmdLimpo = trim(command):lower()
    if cmdLimpo == '/la' or cmdLimpo:match('^/la%s+')
        or cmdLimpo == '/logaradm' or cmdLimpo:match('^/logaradm%s+') then
        loginStaffPendenteAte = (os.clock and os.clock() or 0) + 20
        return
    end
    if cmdLimpo == '/da' or cmdLimpo == '/sairadm' or cmdLimpo == '/deslogaradm' then
        staffLogada = false
        loginStaffPendenteAte = 0
        dialogAction = nil
        aguardandoReport, reportDialogId, reportAte = false, -1, 0
        reportDialogTexto = ''
        reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
        painelTvFlutuante, rgAtual, nickAtual, levelAtualConfirmado = false, nil, nil, nil
        emAtendimento, atendimentoNick, atendimentoRg, atendimentoInicio = false, '', '', 0
        atendimentoOffAte, atendimentoTempoFinal = 0, 0
        saciarmeProximo = 0
        return
    end
    -- Fora da staff, o mod nao intercepta, registra ou automatiza comandos do servidor.
    -- /la continua passando normalmente para que o servidor confirme o login.
    if not staffLogada then return end
    if cmdLimpo == '/tv' or cmdLimpo:match('^/tv%s+') then
        aguardandoReport, reportDialogId, reportAte = false, -1, 0
        reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
    end
    if cmdLimpo == '/tv' then
        abrirSeletorTV('')
        return false
    end
    local buscaTv = trim(command):match('^/tv%s+(.+)$')
    if buscaTv and not trim(buscaTv):match('^%d+$') then
        abrirSeletorTV(buscaTv)
        return false
    end
    if buscaTv and trim(buscaTv):match('^%d+$') then
        painelTvFlutuante = true
        -- No Horizonte, numero digitado em /tv e RG, nunca o ID do TAB.
        rgAtual = trim(buscaTv)
        nickAtual = cache[rgAtual] and cache[rgAtual].nick or 'Aguardando servidor'
        levelAtualConfirmado = nil
    end
    if cmdLimpo == '/reports' or cmdLimpo:match('^/reports%s+') then
        prepararAberturaReports()
    elseif cmdLimpo:match('^/tv%s+') then
        aguardandoReport, reportDialogId, reportAte = false, -1, 0
        reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
    elseif cmdLimpo == '/tvoff' then
        painelTvFlutuante, rgAtual, nickAtual, levelAtualConfirmado = false, nil, nil, nil
    end
    if cmdLimpo == '/fa' then
        emAtendimento, atendimentoNick, atendimentoRg, atendimentoInicio = false, '', '', 0
        atendimentoOffAte, atendimentoTempoFinal = 0, 0
    end
    local rg, motivo = command:match('^/ban%s+(%d+)%s+(.+)')
    if rg then pendente = {rg=rg, tempo='Permanente', motivo=motivo, tipo='BAN'} return end
    local tempo
    rg, tempo, motivo = command:match('^/bantemp%s+(%d+)%s+(%d+)%s+(.+)')
    if rg then pendente = {rg=rg, tempo=tempo .. ' dias', motivo=motivo, tipo='BAN'} return end
    rg, tempo, motivo = command:match('^/cadeia%s+(%d+)%s+(%d+)%s+(.+)')
    if not rg then rg, tempo, motivo = command:match('^/punicao%s+(%d+)%s+(%d+)%s+(.+)') end
    if rg then pendente = {rg=rg, tempo=tempo .. ' minutos', motivo=motivo, tipo='CADEIA'} return end

    local comandos = { ir='IR', trazer='TRAZER', reviver='REVIVER', congelar='CONGELAR', descongelar='DESCONGELAR', prenderarmas='PRENDERARMAS' }
    local cmd, alvo = command:match('^/(%S+)%s+(%d+)%s*$')
    if cmd and comandos[cmd:lower()] then logAcao(comandos[cmd:lower()], alvo) end
    local q
    cmd, alvo, q = command:match('^/(%a+)%s+(%d+)%s+(%d+)')
    if cmd and (cmd:lower() == 'setvida' or cmd:lower() == 'setcolete') then
        logAcao(cmd:upper(), alvo, q)
    end
    alvo, q = command:match('^/tapa%s+(%d+)%s+(%d+)')
    if alvo then logAcao('TAPA', alvo, q) end
end

function samp.onServerMessage(color, text)
    local ct = clean(text)
    local baixo = ct:lower()

    if aguardandoReport and (baixo:find('jogador%(a%) desconectou%-se')
        or baixo:find('jogador desconectou', 1, true)
        or baixo:find('jogador offline', 1, true)) then
        aguardandoReport, reportAte = false, 0
        reportAlvoNick, reportAlvoRg, reportSelecaoEm = nil, nil, 0
        painelTvFlutuante, nickAtual, rgAtual, levelAtualConfirmado = false, nil, nil, nil
    end

    local nomeAtendimento, rgAtendimento =
        ct:match('[Aa]tendendo o%(a%) jogador%(a%)%s+([%w_]+)%[(%d+)%]')
    if not nomeAtendimento then
        nomeAtendimento, rgAtendimento =
            ct:match('[Aa]tendendo.-jogador.-([%w_]+)%s*%[(%d+)%]')
    end
    if nomeAtendimento and rgAtendimento and staffLogada and moduloAtivo('atendimento') then
        local atendimentoNovo = not emAtendimento
            or tostring(atendimentoRg) ~= tostring(rgAtendimento)
            or tostring(atendimentoNick):lower() ~= tostring(nomeAtendimento):lower()
        atendimentoNick, atendimentoRg = nomeAtendimento, rgAtendimento
        atendimentoInicio, emAtendimento = relogioAtendimento(), true
        atendimentoOffAte, atendimentoTempoFinal = 0, 0
        -- A confirmacao do servidor garante que o jogador esta ON e que o
        -- painel de atendimento acabou de ser aberto. Envia uma unica saudacao.
        if atendimentoNovo then
            lua_thread.create(function()
                wait(150)
                if emAtendimento and tostring(atendimentoRg) == tostring(rgAtendimento) then
                    sampSendChat('Ola, como posso ajudar?')
                end
            end)
        end
    end
    if emAtendimento and (baixo:find('atendimento finalizado', 1, true)
        or baixo:find('finalizou o atendimento', 1, true)) then
        emAtendimento, atendimentoNick, atendimentoRg, atendimentoInicio = false, '', '', 0
        atendimentoOffAte, atendimentoTempoFinal = 0, 0
    end

    -- Identificacao automatica segura: mensagens globais de login de outros
    -- staffs nunca podem alterar o cargo desta instalacao.
    local meuNick = ''
    if type(sampGetPlayerIdByCharHandle) == 'function' and type(sampGetPlayerNickname) == 'function' then
        local ok, encontrado, meuId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
        if ok and encontrado then meuNick = tostring(sampGetPlayerNickname(meuId) or '') end
    end
    local agoraLogin = os.clock and os.clock() or 0
    local loginPendente = loginStaffPendenteAte > agoraLogin
    local confirmouLogin = baixo:find('logou', 1, true)
        and (baixo:find('staff', 1, true) or baixo:find('administra', 1, true))
    local nomeLoginMensagem = ct:match(
        '[Aa][Dd][Mm][Ii][Nn]:%s*[Oo]%(A%)%s+.-%s+([%w_]+)%[%d+%]%s+logou')
        or ct:match('[Oo]la%s+.-%s+([%w_]+),%s+voce%s+logou')
    local loginEhMeu = loginPendente and meuNick ~= ''
        and nomeLoginMensagem ~= nil
        and tostring(nomeLoginMensagem):lower() == meuNick:lower()
    if confirmouLogin and loginEhMeu then
        local cargoLogin
        if baixo:find('diretor', 1, true) then cargoLogin = 'Diretor'
        elseif baixo:find('coorden', 1, true) then cargoLogin = 'Coordenador'
        elseif baixo:find('moder', 1, true) then cargoLogin = 'Moderador'
        elseif baixo:find('ajud', 1, true) then cargoLogin = 'Ajudante'
        elseif baixo:find('administrador', 1, true) then cargoLogin = 'Administrador' end
        if cargoLogin and meuNick ~= '' then
            local jaIdentificado = staffLogada
                and tostring(cfg.dados.nome or ''):lower() == meuNick:lower()
                and nivelCargo(cfg.dados.cargo) == nivelCargo(cargoLogin)
            if not jaIdentificado then
                definirPerfil(meuNick, cargoLogin, true)
                sampAddChatMessage('{3EDC81}[CARGO] Identificado como ' .. cargoLogin .. '. Acesso ao /mods liberado conforme o cargo.', -1)
            end
            loginStaffPendenteAte = 0
        end
    end
    if not staffLogada then return end
    local nick, rg = ct:match('[Nn]ome[:%s]+([%w_]+).-RG[:%s]+(%d+)')
    if not nick then nick, rg = ct:match('[Nn]ick[:%s]+([%w_]+).-RG[:%s]+(%d+)') end
    if not nick then rg, nick = ct:match('RG[:%s]+(%d+).-Nome[:%s]+([%w_]+)') end
    if not nick then rg, nick = ct:match('RG[:%s]+(%d+).-Nick[:%s]+([%w_]+)') end
    if nick and rg then
        local nickOnline = jogadorOnlinePorNick(nick)
        if nickOnline then
            nick = nickOnline
            salvarRG(rg, nickOnline)
            local mesmoAlvo = tostring(rgAtual or '') == tostring(rg)
                or tostring(nickAtual or ''):lower() == tostring(nickOnline):lower()
                or nickAtual == 'Aguardando servidor'
            if aguardandoReport or (painelTvFlutuante and mesmoAlvo) then
                rgAtual, nickAtual = rg, nickOnline
            end
            if aguardandoReport then
                painelTvFlutuante = true
                enviarAvisoTelagemReport(nickAtual, rgAtual)
            end
        end
    end
    local tvNick, tvRg = ct:match('[Tt]elando.-([%w_]+).-RG[:%s]+(%d+)')
    if tvNick and tvRg then
        local tvNickOnline = jogadorOnlinePorNick(tvNick)
        if tvNickOnline then
            local alvoMudou = tostring(rgAtual or '') ~= tostring(tvRg)
                and tostring(nickAtual or ''):lower() ~= tostring(tvNickOnline):lower()
            if alvoMudou then levelAtualConfirmado = nil end
            salvarRG(tvRg, tvNickOnline); rgAtual, nickAtual = tvRg, tvNickOnline
            painelTvFlutuante = true
            enviarAvisoTelagemReport(tvNickOnline, tvRg)
        end
    end

    if pendente and ct:find('HZ%-ADMIN') then
        local alvoNick = ct:match('[Jj]ogador%(a%)%s+([%w_]+)') or (cache[pendente.rg] and cache[pendente.rg].nick)
        if alvoNick and alvoNick:lower() ~= tostring(cfg.dados.nome):lower() then
            local acao = pendente.tipo == 'BAN' and 'baniu' or 'prendeu'
            local url = pendente.tipo == 'BAN' and WEBHOOKS.BAN or WEBHOOKS.CADEIA
            logPunicao(alvoNick, pendente.rg, pendente.tempo, pendente.motivo, acao, url, pendente.tipo)
            pendente = nil
        end
    end

    for mrg, info in pairs(monitorados) do
        if ct:lower():find(tostring(info.nick):lower(), 1, true) and (ct:lower():find('entrou', 1, true) or ct:lower():find('conect', 1, true)) then
            chat('{FFAA00}', 'MONITORADO ONLINE: ' .. info.nick .. ' [RG ' .. mrg .. '] - ' .. info.motivo)
        end
    end
end

function main()
    while not isSampAvailable() do wait(100) end
    cache = carregarTabela(CACHE_FILE)
    monitorados = carregarTabela(MONITOR_FILE)
    registrarComandos()
    instalarPainelTvMimgui()
    chat('{3EDC81}', 'Mobile ' .. VERSION .. ' ativo. Use /la para identificar automaticamente nome e cargo.')
    chat('{A8B5C8}', '/configadm fica disponivel somente como configuracao de emergencia.')
    -- No Android, algumas builds do MonetLoader fecham o processo durante
    -- requisicoes automaticas na inicializacao. A atualizacao fica somente
    -- sob comando explicito: /setoratualizar.
    while true do
        wait(0)
        if staffLogada and saciarmeProximo > 0
            and relogioAtendimento() >= saciarmeProximo then
            sampSendChat('/saciarme')
            saciarmeProximo = relogioAtendimento() + SACIARME_INTERVALO
        end
        local ok, erro = pcall(desenharPainelTvFlutuante)
        if not ok then
            painelTvFlutuante = false
            print('[SETOR MOBILE] Painel TV flutuante desativado por incompatibilidade: ' .. tostring(erro))
        end
        if painelTvAcaoPendente then
            local acao = painelTvAcaoPendente
            painelTvAcaoPendente = nil
            if acao == 'menu' then
                abrirPrincipal()
            elseif acao == 'punir' then
                abrirPunicoes()
            elseif acao == 'acoes' then
                abrirAcoes()
            elseif acao == 'monitor' then
                abrirMonitor()
            elseif acao == 'off' then
                sampSendChat('/tvoff')
                painelTvFlutuante, rgAtual, nickAtual, levelAtualConfirmado = false, nil, nil, nil
            end
        end
    end
end
