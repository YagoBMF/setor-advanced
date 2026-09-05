script_name('HZ Atendimento IA')
script_author('HZ')
script_version('2.0.1')

require 'moonloader'
local sampev = require 'lib.samp.events'
local json = require 'dkjson'
local imgui = require 'mimgui'
local dlstatus = require 'moonloader'.download_status

local API = 'https://ia.fretesja.com.br/api.php'
local CONFIG_PATH = getWorkingDirectory() .. '\\config\\hz_ai_config.lua'
local function load_private_config()
    local chunk = loadfile(CONFIG_PATH)
    if not chunk then return {} end
    local ok, data = pcall(chunk)
    return ok and type(data) == 'table' and data or {}
end
local private_config = load_private_config()
local STAFF_KEY = tostring(private_config.staff_key or '')
local STAFF_ID = 'identificando'
local STAFF_ROLE = 'Desconhecido'
local POLL_SECONDS = 10.0
local TEMP_FILE = 'C:\\Games\\HZ MINHA DATA\\HZ\\HZ\\MoonLoader\\config\\hz_ai_bridge.json'
local incoming, seen = {}, {}
local dialog_queue = {}
local deferred_dialogs = {}
local active_dialog = nil
local active_dialog_since = 0
local pending_dialog = nil
local notice_visible = false
local notice_opened_at = 0
local notice_item = nil
local support_target_name = nil
local support_target_rg = nil
local DIALOG_APPROVE, DIALOG_OPTIONS, DIALOG_TEACH = 31941, 31942, 31943
local bridge_online = false
local download_busy = false
local download_done = false
local download_kind = nil
local download_started = 0
local download_item = nil

local function strip_colors(text)
    return tostring(text or ''):gsub('{%x%x%x%x%x%x}', '')
end

local function urlencode(value)
    return tostring(value or ''):gsub('\n', '\r\n'):gsub('([^%w%-_%.~])', function(char)
        return string.format('%%%02X', string.byte(char))
    end)
end

local function refresh_staff_identity()
    if type(sampGetPlayerIdByCharHandle) ~= 'function' or type(sampGetPlayerNickname) ~= 'function' then return end
    local ok, player_id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if ok then
        local nickname = tostring(sampGetPlayerNickname(player_id) or '')
        if nickname ~= '' then STAFF_ID = nickname end
    end
end

local function detect_staff_role(text)
    refresh_staff_identity()
    local clean = tostring(text or ''):gsub('{%x%x%x%x%x%x}', ''):gsub('%s+', ' ')
    local cargo, nome = clean:match('ADMIN:%s+O%(A%)%s+([^%s]+)%s+([%a%d_]+)%[%d+%]%s+logou na staff!')
    if not cargo then cargo, nome = clean:match('[Oo]la%s+([^%s]+)%s+([%a%d_]+),.-logou.-administra') end
    if nome and tostring(nome):lower() == tostring(STAFF_ID):lower() then STAFF_ROLE = tostring(cargo or 'Staff') end
end

local function sanitize_game_text(value)
    local clean = tostring(value or ''):gsub('[^%w%s%.,%!%?/%-]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    return clean:sub(1, 85):match('^%s*(.-)%s*$')
end

local function queue_dialog(item)
    table.insert(dialog_queue, item)
end

local function clear_old_support(preserve_incoming)
    notice_visible = false
    notice_opened_at = 0
    notice_item = nil
    pending_dialog = nil
    if download_item and (download_item.type == 'support_start' or download_item.type == 'support_message') then
        download_item.discard = true
    end
    if not preserve_incoming then
        for index = #incoming, 1, -1 do
            if incoming[index].type == 'support_start' or incoming[index].type == 'support_message' or incoming[index].type == 'support_staff_message' then
                table.remove(incoming, index)
            end
        end
    end
    for index = #dialog_queue, 1, -1 do
        if dialog_queue[index].type == 'support_message' then
            table.remove(dialog_queue, index)
        end
    end
    for index = #deferred_dialogs, 1, -1 do
        if deferred_dialogs[index].type == 'support_message' then
            table.remove(deferred_dialogs, index)
        end
    end
    if active_dialog and active_dialog.type == 'support_message' then
        active_dialog = nil
    end
end

local function show_answer_dialog()
    if not active_dialog then return end
    local state = active_dialog.ai_state or 'answering'
    local title = state == 'clarifying' and 'HZ IA - ESCLARECER' or (state == 'escalating' and 'HZ IA - ESCALAR' or (active_dialog.type == 'question' and 'HZ IA - DUVIDA' or 'HZ IA - ATENDIMENTO'))
    local result_label = state == 'clarifying' and 'Pergunta sugerida' or (state == 'escalating' and 'Orientacao segura' or 'Resposta sugerida')
    local confidence = tonumber(active_dialog.confidence or 0) or 0
    local text
    if active_dialog.type == 'question' then
        text = string.format('{38D8E8}Jogador:{FFFFFF} %s\n{38D8E8}RG:{FFFFFF} %s\n{38D8E8}Confianca:{FFFFFF} %d%%\n\n{38D8E8}Pergunta:{FFFFFF}\n%s\n\n{62E6A7}%s:{FFFFFF}\n%s', active_dialog.player, active_dialog.rg, confidence, active_dialog.question, result_label, active_dialog.suggestion)
    else
        text = string.format('{38D8E8}Jogador:{FFFFFF} %s\n{38D8E8}Confianca:{FFFFFF} %d%%\n\n{38D8E8}Mensagem:{FFFFFF}\n%s\n\n{62E6A7}%s:{FFFFFF}\n%s', active_dialog.player, confidence, active_dialog.message, result_label, active_dialog.suggestion)
    end
    local dialog_style = state == 'clarifying' and 1 or 0
    sampShowDialog(DIALOG_APPROVE, title, text, state == 'clarifying' and 'PERGUNTAR' or 'APROVAR', 'OPCOES', dialog_style)
    if state == 'clarifying' and type(sampSetCurrentDialogEditboxText) == 'function' then
        sampSetCurrentDialogEditboxText(tostring(active_dialog.suggestion or ''))
    end
    if type(sampSetDialogClientside) == 'function' then sampSetDialogClientside(false) end
end

local function show_next_dialog()
    if active_dialog or #dialog_queue == 0 or sampIsDialogActive() then return end
    active_dialog = table.remove(dialog_queue, 1)
    active_dialog_since = os.clock()
    if active_dialog.open_direct then
        active_dialog.open_direct = nil
        show_answer_dialog()
        return
    end
    notice_item = active_dialog
    notice_visible = true
    notice_opened_at = os.clock()
end

local function recover_stale_dialog()
    if active_dialog and not notice_visible and not pending_dialog and not sampIsDialogActive() and os.clock() - active_dialog_since > 1.0 then
        active_dialog = nil
        active_dialog_since = 0
        sampAddChatMessage('[HZ IA] Fila de dialogos liberada.', 0xAAB7C4)
    end
end

local function close_notice(open_answer)
    notice_visible = false
    notice_opened_at = 0
    notice_item = nil
    if sampIsChatInputActive() then sampSetChatInputEnabled(false) end
    if not active_dialog then return end
    if open_answer then
        pending_dialog = 'answer'
    else
        table.insert(deferred_dialogs, active_dialog)
        sampAddChatMessage('[HZ IA] Sugestao guardada. Use /hzai para abrir depois.', 0xFFCC66)
        active_dialog = nil
        active_dialog_since = 0
    end
end

local notice_flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoMove
    + imgui.WindowFlags.NoSavedSettings + imgui.WindowFlags.NoFocusOnAppearing
    + imgui.WindowFlags.NoBringToFrontOnFocus + imgui.WindowFlags.NoNav + imgui.WindowFlags.NoResize

local notification_frame = imgui.OnFrame(
    function() return notice_visible and notice_item ~= nil and not isPauseMenuActive() end,
    function()
        -- Copia local independente: finalizar o atendimento nao invalida o desenho atual.
        local item = notice_item
        if not item then return end
        local screen_x = getScreenResolution()
        local chat_open = sampIsChatInputActive()
        local flags = notice_flags + (chat_open and 0 or imgui.WindowFlags.NoInputs)
        imgui.SetNextWindowPos(imgui.ImVec2((screen_x - 365) / 2, 105), imgui.Cond.Always)
        imgui.SetNextWindowSize(imgui.ImVec2(365, 130), imgui.Cond.Always)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 10))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.055, 0.06, 0.075, 0.96))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.20, 0.75, 0.95, 0.95))
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.11, 0.12, 0.16, 0.96))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20, 0.60, 0.75, 1.00))
        imgui.Begin('##hz_ai_notification_safe', nil, flags)
        local kind = item.ai_state == 'clarifying' and 'Contexto incompleto - pergunta sugerida' or (item.ai_state == 'escalating' and 'Caso precisa de decisao superior' or (item.type == 'question' and 'Nova duvida recebida' or 'Nova mensagem no atendimento'))
        imgui.TextColored(imgui.ImVec4(0.93, 0.95, 1.00, 1.00), 'HZ IA - NOVA MENSAGEM')
        imgui.SameLine(); imgui.SetCursorPosX(310)
        imgui.TextColored(imgui.ImVec4(0.60, 0.63, 0.70, 1.00), os.date('%H:%M'))
        imgui.Text(kind)
        local rg = tostring(item.rg or support_target_rg or '')
        imgui.Text(string.format('Jogador: %s%s', tostring(item.player or ''), rg ~= '' and ' - RG ' .. rg or ''))
        imgui.Spacing()
        if imgui.Button('VER MAIS', imgui.ImVec2(158, 28)) and chat_open then close_notice(true) end
        imgui.SameLine()
        if imgui.Button('FECHAR', imgui.ImVec2(158, 28)) and chat_open then close_notice(false) end
        imgui.End(); imgui.PopStyleColor(4); imgui.PopStyleVar(2)
    end
)
notification_frame.HideCursor = true

local function show_pending_dialog()
    if not pending_dialog or sampIsDialogActive() then return end
    local next_dialog = pending_dialog
    pending_dialog = nil
    if next_dialog == 'options' then
        sampShowDialog(DIALOG_OPTIONS, 'HZ IA - OPCOES', 'ENSINAR UMA RESPOSTA\nIGNORAR ESTA MENSAGEM\nIR ATE O JOGADOR\nTELAR O JOGADOR\nPARAR DE TELAR', 'SELECIONAR', 'VOLTAR', 2)
    elseif next_dialog == 'answer' then
        show_answer_dialog()
    elseif next_dialog == 'teach' then
        sampShowDialog(DIALOG_TEACH, 'HZ IA - ENSINAR', 'Digite a resposta correta. Ela sera salva e enviada ao jogador.', 'SALVAR E ENVIAR', 'CANCELAR', 1)
    end
    if type(sampSetDialogClientside) == 'function' then sampSetDialogClientside(false) end
end

local function begin_download(kind, url)
    if download_busy then return end
    download_busy, download_done, download_kind = true, false, kind
    download_started = os.clock()
    os.remove(TEMP_FILE)
    downloadUrlToFile(url, TEMP_FILE, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            download_done = true
        end
    end)
end

local function send_question(item)
    local url = API .. '?source=lua&type=' .. urlencode(item.type or 'question')
        .. '&key=' .. urlencode(STAFF_KEY) .. '&staff=' .. urlencode(STAFF_ID) .. '&staff_role=' .. urlencode(STAFF_ROLE)
        .. '&player=' .. urlencode(item.player) .. '&rg=' .. urlencode(item.rg or '')
    if item.type == 'question' then url = url .. '&question=' .. urlencode(item.question) end
    if item.type == 'resolve_question' then url = url .. '&question=' .. urlencode(item.question) .. '&action=' .. urlencode(item.action or 'resolved') end
    if item.type == 'support_message' then url = url .. '&message=' .. urlencode(item.message) end
    if item.type == 'support_staff_message' then url = url .. '&message=' .. urlencode(item.message) .. '&role=' .. urlencode(item.role) end
    if item.type == 'teach' then url = url .. '&question=' .. urlencode(item.question) .. '&answer=' .. urlencode(item.answer) end
    if item.type == 'memory_feedback' then url = url .. '&question=' .. urlencode(item.question) .. '&answer=' .. urlencode(item.answer) .. '&action=' .. urlencode(item.action or 'approved') end
    if item.scope then url = url .. '&scope=' .. urlencode(item.scope) end
    url = url .. '&t=' .. tostring(os.time())
    download_item = table.remove(incoming, 1)
    begin_download('question', url)
end

local function poll_command()
    begin_download('poll', API .. '?source=lua&type=commands&key=' .. urlencode(STAFF_KEY) .. '&staff=' .. urlencode(STAFF_ID) .. '&staff_role=' .. urlencode(STAFF_ROLE) .. '&t=' .. tostring(os.time()))
end

local function finish_download()
    if not download_busy then return end
    if not download_done then
        if os.clock() - download_started > 60.0 then
            download_busy, download_kind = false, nil
            bridge_online = false
            if download_item and not download_item.discard then table.insert(incoming, 1, download_item) end
            download_item = nil
        end
        return
    end

    local kind = download_kind
    local file = io.open(TEMP_FILE, 'rb')
    if not file then
        if os.clock() - download_started > 60.0 then
            download_busy, download_done, download_kind = false, false, nil
            bridge_online = false
            if download_item and not download_item.discard then table.insert(incoming, 1, download_item) end
            download_item = nil
            sampAddChatMessage('[HZ IA] Nao foi possivel ler o retorno do painel.', 0xFF6666)
        end
        return
    end
    local body = file:read('*a')
    file:close()
    local data = json.decode(body or '')
    if not data then
        if os.clock() - download_started > 30.0 then
            download_busy, download_done, download_kind = false, false, nil
            bridge_online = false
            os.remove(TEMP_FILE)
            if download_item and not download_item.discard then table.insert(incoming, 1, download_item) end
            download_item = nil
            sampAddChatMessage('[HZ IA] O painel devolveu uma resposta invalida.', 0xFF6666)
        end
        return
    end
    download_busy, download_done, download_kind = false, false, nil
    bridge_online = true
    os.remove(TEMP_FILE)

    if kind == 'question' then
        local item = download_item
        download_item = nil
        if data.ok and item then
            if item.type == 'support_finish_from_lua' then
                if data.memory_saved then
                    sampAddChatMessage('[HZ IA] Caso completo enviado para revisao no painel.', 0x62E6A7)
                else
                    sampAddChatMessage('[HZ IA] Atendimento encerrado sem caso suficiente para aprender.', 0xAAB7C4)
                end
            end
            if item.type == 'support_staff_message' and data.as_player then item.type = 'support_message' end
            if not item.discard and not data.skip and (item.type == 'question' or item.type == 'support_message') then
                item.ai_state = data.state or 'answering'
                item.confidence = tonumber(data.confidence or 0) or 0
                item.missing_info = data.missing_info
                item.suggestion = sanitize_game_text(data.suggestion or 'Nao encontrei uma resposta segura. Ensine a resposta correta.')
                queue_dialog(item)
            elseif data.skip and (item.type == 'support_message' or item.type == 'question') then
                if data.reason == 'awaiting_context' then
                    sampAddChatMessage('[HZ IA] Aguardando o jogador explicar melhor o problema.', 0xAAB7C4)
                else
                    sampAddChatMessage('[HZ IA] Mensagem casual ignorada sem abrir dialogo.', 0xAAB7C4)
                end
            end
        end
        return
    end
    if data.command and type(data.command.command) == 'string' then
        local command = data.command.command
        if data.command.mode == 'chat' and not command:match('^/') then
            sampSendChat(command)
        elseif data.command.mode == 'command' and (command:match('^/d%s+%d+%s+.+') or command == '/FinalizarAtendimento') then
            sampSendChat(command)
        end
    end
end

function sampev.onServerMessage(color, text)
    detect_staff_role(text)
    local clean = strip_colors(text)
    local lower = clean:lower()
    if lower:find('atendimento finalizado', 1, true) or lower:find('finalizou o atendimento', 1, true) then
        clear_old_support(true)
        support_target_name = nil
        support_target_rg = nil
        table.insert(incoming, {type = 'support_finish_from_lua', player = 'staff'})
        sampAddChatMessage('[HZ IA] Atendimento removido do painel.', 0x62E6A7)
    end
    local player, rg, question = clean:match('^DUVIDA:%s+Duvida de%s+(.-)%[(%d+)%]:%s+(.+)$')
    if not player then
        player, rg, question = clean:match('^DUVIDA VIP:%s+Duvida de%s+(.-)%[(%d+)%]:%s+(.+)$')
    end
    if player and rg and question then
        local key = rg .. ':' .. question
        if not seen[key] then
            seen[key] = os.clock()
            table.insert(incoming, {type = 'question', player = player, rg = rg, question = question})
            sampAddChatMessage('[HZ IA] Verificando se a duvida esta clara.', 0x38D8E8)
        end
    end
    local support_player, support_rg = clean:match('^INFO:.-jogador%(a%)%s+(.-)%[(%d+)%]')
    if support_player and support_rg and clean:find('atendendo', 1, true) then
        clear_old_support()
        support_target_name = support_player:lower():gsub('%s+', '')
        support_target_rg = support_rg
        table.insert(incoming, {type = 'support_start', player = support_player, rg = support_rg})
        sampAddChatMessage('[HZ IA] Atendimento conectado ao painel.', 0x38D8E8)
    end
    local chat_player, message = clean:match('^Chat%-Suporte:%s+Jogador%(a%)%s+([^:]+):%s+(.+)$')
    if chat_player and message then
        table.insert(incoming, {type = 'support_message', player = chat_player, rg = support_target_rg, message = message})
        sampAddChatMessage('[HZ IA] Analisando o contexto do atendimento.', 0x38D8E8)
    end
    local role_label, staff_name, staff_message = clean:match('^Chat%-Suporte:%s+([^%s]+)%s+([^:]+):%s+(.+)$')
    if role_label and staff_name and staff_message and role_label ~= 'Jogador(a)' then
        local role = role_label:gsub('%(a%)', ''):lower()
        local allowed_roles = {ajudante = true, moderador = true, administrador = true, coordenador = true, diretor = true, owner = true, onwer = true}
        if allowed_roles[role] then
            local normalized_name = staff_name:lower():gsub('%s+', '')
            if support_target_name and normalized_name == support_target_name then
                table.insert(incoming, {type = 'support_message', player = staff_name, rg = support_target_rg, role = role_label, message = staff_message})
                sampAddChatMessage('[HZ IA] Analisando o contexto do atendimento.', 0x38D8E8)
            else
                table.insert(incoming, {type = 'support_staff_message', player = staff_name, role = role_label, message = staff_message})
            end
        end
    end
end

function sampev.onSendDialogResponse(id, button, listboxId, input)
    id = tonumber(id)
    if id ~= DIALOG_APPROVE and id ~= DIALOG_OPTIONS and id ~= DIALOG_TEACH then return end
    local confirmed = button == true or button == 1 or tostring(button) == '1'
    if id == DIALOG_APPROVE and active_dialog then
        if confirmed then
            local answer_source = active_dialog.suggestion
            if active_dialog.ai_state == 'clarifying' and tostring(input or ''):match('%S') then
                answer_source = input
            end
            local answer = sanitize_game_text(answer_source)
            if active_dialog.ai_state == 'clarifying' and answer == '' then
                sampAddChatMessage('[HZ IA] Escreva a pergunta antes de enviar.', 0xFF6666)
                pending_dialog = 'answer'
                return false
            end
            if active_dialog.ai_state == 'clarifying' then
                active_dialog.suggestion = answer
            end
            if active_dialog.type == 'question' then sampSendChat('/d ' .. active_dialog.rg .. ' ' .. answer) else sampSendChat(answer) end
            if active_dialog.type == 'support_message' then table.insert(incoming, {type = 'support_staff_message', player = STAFF_ID, role = STAFF_ROLE, message = answer}) end
            if active_dialog.type == 'question' and active_dialog.ai_state ~= 'clarifying' then table.insert(incoming, {type = 'resolve_question', player = active_dialog.player, rg = active_dialog.rg, question = active_dialog.question, action = 'approved'}) end
            if active_dialog.ai_state == 'clarifying' then
                sampAddChatMessage('[HZ IA] Pergunta de esclarecimento enviada. Aguardando resposta.', 0x38D8E8)
            elseif active_dialog.type == 'support_message' then
                sampAddChatMessage('[HZ IA] Orientacao enviada. O caso sera consolidado ao finalizar.', 0x62E6A7)
            end
            active_dialog = nil
            active_dialog_since = 0
        else
            pending_dialog = 'options'
        end
    elseif id == DIALOG_OPTIONS and active_dialog then
        if not confirmed then
            local item = active_dialog
            item.open_direct = true
            active_dialog = nil
            active_dialog_since = 0
            queue_dialog(item)
        elseif tonumber(listboxId) == 0 then
            if active_dialog.ai_state == 'clarifying' then
                sampAddChatMessage('[HZ IA] Uma pergunta de esclarecimento nao vira ensinamento.', 0xFFCC66)
                local item = active_dialog
                item.open_direct = true
                active_dialog = nil
                active_dialog_since = 0
                queue_dialog(item)
            else
                pending_dialog = 'teach'
            end
        elseif tonumber(listboxId) == 1 then
            sampAddChatMessage('[HZ IA] Mensagem ignorada.', 0xFFCC66)
            if active_dialog.type == 'question' then table.insert(incoming, {type = 'resolve_question', player = active_dialog.player, rg = active_dialog.rg, question = active_dialog.question, action = 'ignored'}) end
            active_dialog = nil
            active_dialog_since = 0
        elseif tonumber(listboxId) == 2 or tonumber(listboxId) == 3 then
            local item = active_dialog
            item.open_direct = true
            local target_rg = tostring(item.rg or support_target_rg or ''):match('%d+')
            if target_rg then
                local command = tonumber(listboxId) == 2 and '/ir ' or '/tv '
                sampSendChat(command .. target_rg)
                sampAddChatMessage('[HZ IA] Acao executada no RG ' .. target_rg .. '.', 0x62E6A7)
            else
                sampAddChatMessage('[HZ IA] Nao foi possivel identificar o RG atendido.', 0xFF6666)
            end
            active_dialog = nil
            active_dialog_since = 0
            queue_dialog(item)
        elseif tonumber(listboxId) == 4 then
            local item = active_dialog
            item.open_direct = true
            sampSendChat('/tvoff')
            sampAddChatMessage('[HZ IA] Modo de tela encerrado.', 0x62E6A7)
            active_dialog = nil
            active_dialog_since = 0
            queue_dialog(item)
        end
    elseif id == DIALOG_TEACH and active_dialog then
        if confirmed then
            local answer = sanitize_game_text(input)
            if answer and #answer > 0 then
                local original = active_dialog.question or active_dialog.message
                if active_dialog.type == 'question' then sampSendChat('/d ' .. active_dialog.rg .. ' ' .. answer) else sampSendChat(answer) end
                if active_dialog.type == 'question' then
                    table.insert(incoming, {type = 'teach', scope = 'question', player = active_dialog.player, rg = active_dialog.rg or '', question = original, answer = answer})
                end
                sampAddChatMessage('[HZ IA] Correcao salva e enviada.', 0x62E6A7)
            end
        end
        active_dialog = nil
        active_dialog_since = 0
    end
    return false
end

function main()
    repeat wait(100) until isSampAvailable()
    refresh_staff_identity()
    if STAFF_KEY == '' then
        sampAddChatMessage('[HZ IA] Configuracao ausente. Verifique config/hz_ai_config.lua.', 0xFF6666)
    end
    sampRegisterChatCommand('hzai', function()
        if not active_dialog and #deferred_dialogs > 0 then
            local item = table.remove(deferred_dialogs, 1)
            item.open_direct = true
            table.insert(dialog_queue, 1, item)
            sampAddChatMessage('[HZ IA] Abrindo a sugestao guardada.', 0x38D8E8)
            return
        end
        sampAddChatMessage(
            string.format('[HZ IA] %s - %s | Painel: %s | Rede: %s | Entrada: %d | Fila: %d | Guardadas: %d', STAFF_ID, STAFF_ROLE, bridge_online and 'CONECTADO' or 'AGUARDANDO', download_busy and 'CONSULTANDO' or 'LIVRE', #incoming, #dialog_queue, #deferred_dialogs),
            bridge_online and 0x62E6A7 or 0xFFCC66
        )
    end)

    local next_poll, next_cleanup = 0, 0
    while true do
        wait(100)
        finish_download()
        recover_stale_dialog()
        show_pending_dialog()
        show_next_dialog()
        if notice_visible and notice_opened_at > 0 and os.clock() - notice_opened_at >= 60.0 then close_notice(false) end
        if STAFF_KEY ~= '' and not download_busy and #incoming > 0 then
            send_question(incoming[1])
        elseif STAFF_KEY ~= '' and not download_busy and os.clock() >= next_poll then
            next_poll = os.clock() + POLL_SECONDS
            poll_command()
        end
        if os.clock() >= next_cleanup then
            next_cleanup = os.clock() + 10.0
            for key, created in pairs(seen) do if os.clock() - created > 300 then seen[key] = nil end end
        end
    end
end
