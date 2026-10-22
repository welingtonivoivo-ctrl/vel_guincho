-- Etapa 3: o cabo. Opções do mri_Qinteract no motor do guincho e em qualquer carro; cada cliente
-- desenha o cabo (corda do GTA) a partir do statebag velCabo do caminhão. O servidor decide tudo.

local GANCHO = `prop_rope_hook_01` -- só o gancho (43 cm); o prop_winch_hook_* já vem com 8–15 m de cabo
local MAO = 57005 -- mão direita
local ANIM = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
local PERTO = 45.0

local caminhoes = {} -- [veiculo] = { c, ancora, interact = true }
local cabos = {}     -- [veiculo] = { assinatura, corda, gancho, alvo }
local meuCabo = nil  -- veiculo do caminhão cujo gancho está na minha mão

local function notificar(chave, tipo)
    lib.notify({ title = locale('painel_titulo'), description = locale(chave), type = tipo or 'error' })
end

local function cadastroDe(veiculo)
    local estado = GlobalState.velGuincho
    return estado and estado.caminhoes and estado.caminhoes[tostring(GetEntityModel(veiculo))]
end

---Âncora presa à peça da plataforma (para pontos que andam com ela); nil se o ponto é do caminhão.
local function ancoraDe(veiculo, c)
    local motor = c.pontos.motor
    if not motor or not motor.osso then return nil end
    local info = caminhoes[veiculo]
    if info and info.ancora and DoesEntityExist(info.ancora) then return info.ancora end
    local i = Plataforma.osso(veiculo, motor.osso)
    if not i then return nil end
    local a = Plataforma.ancora(veiculo, i)
    if info then info.ancora = a end
    return a
end

---Ponto do motor do guincho no mundo, agora.
local function motorNoMundo(veiculo, c)
    local m = c.pontos.motor
    if not m then return nil end
    local base = ancoraDe(veiculo, c) or veiculo
    return GetOffsetFromEntityInWorldCoords(base, m.x, m.y, m.z)
end

---Ponto de engate do carro (frente ou traseira, perto do chão, no centro).
---Carro de lado ou de rodas para cima.
function GuinchoTombado(carro)
    -- IsEntityUpsidedown devolve 1/0, e 0 é verdadeiro em Lua: compara explicitamente
    local cabecaParaBaixo = IsEntityUpsidedown(carro)
    if cabecaParaBaixo == true or cabecaParaBaixo == 1 then return true end
    return math.abs(GetEntityRoll(carro)) > 60.0 or math.abs(GetEntityPitch(carro)) > 60.0
end

-- Classes de aeronave: a caixa do modelo inclui o rotor/asas, então as pontas da caixa ficam no ar
local AERONAVE = { [15] = true, [16] = true }

---Ponto de engate relativo ao carro, em metros: frente/traseira perto do chão; 'lado' = centro.
---Em aeronaves, o engate fica na fuselagem (perto do centro e da base), não na ponta do rotor ou da asa.
local function pontoLocal(carro, ponto)
    if ponto == 'lado' then return vec3(0.0, 0.0, 0.0) end
    local min, max = GetModelDimensions(GetEntityModel(carro))
    if AERONAVE[GetVehicleClass(carro)] then
        local y = ponto == 'frente' and max.y * 0.4 or min.y * 0.4
        return vec3(0.0, y, min.z + 0.6)
    end
    local y = ponto == 'frente' and (max.y - 0.15) or (min.y + 0.15)
    return vec3(0.0, y, min.z + 0.45)
end

local function pontoDoCarro(carro, ponto)
    local o = pontoLocal(carro, ponto)
    return GetOffsetFromEntityInWorldCoords(carro, o.x, o.y, o.z)
end

GuinchoCabo = { motorNoMundo = motorNoMundo }

local function caboMax(c)
    return Config.Cabo[c.cabo] or 15.0
end

-- Interact ---------------------------------------------------------------

local function opcoesCaminhao(veiculo, c)
    local motor = c.pontos.motor
    if not motor then return nil end
    -- posição do motor relativa ao caminhão neste momento (plataforma como está agora)
    local w = motorNoMundo(veiculo, c)
    local o = GetOffsetFromEntityGivenWorldCoords(veiculo, w.x, w.y, w.z)
    return {
        {
            name = 'vel_guincho_pegar', icon = 'fa-solid fa-link', label = locale('pegar_cabo'), distance = 2.0,
            offsetAbsolute = vec3(o.x, o.y, o.z),
            canInteract = function(ent)
                return not meuCabo and not Entity(ent).state.velCabo
            end,
            onSelect = function(data)
                local ent = data.entity or veiculo
                local ok, motivo = lib.callback.await('vel_guincho:cabo:pegar', false, NetworkGetNetworkIdFromEntity(ent))
                if not ok then return notificar(motivo or 'pedido_invalido') end
                PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end,
        },
        {
            name = 'vel_guincho_devolver', icon = 'fa-solid fa-rotate-left', label = locale('devolver_cabo'), distance = 2.0,
            offsetAbsolute = vec3(o.x, o.y, o.z),
            canInteract = function(ent) return meuCabo == ent end,
            onSelect = function(data)
                lib.callback.await('vel_guincho:cabo:devolver', false, NetworkGetNetworkIdFromEntity(data.entity or veiculo))
            end,
        },
        table.unpack(GuinchoCarga.opcoes(veiculo, c)),
    }
end

---Caminhão cujo cabo está engatado neste carro (procura nos caminhões por perto).
local function caminhaoDoCarro(carro)
    local net = NetworkGetNetworkIdFromEntity(carro)
    for veiculo in pairs(caminhoes) do
        local s = DoesEntityExist(veiculo) and Entity(veiculo).state.velCabo
        if s and s.carro == net then return veiculo end
    end
end

---Limite de tamanho do caminhão (painel): comprimento do modelo e aeronaves. Só para levar (frente/traseira).
local function cabeNoCaminhao(caminhao, carro)
    local info = caminhoes[caminhao]
    local limite = info and info.c.pontos.limite
    if not limite then return true end
    if limite.aeronave == false and AERONAVE[GetVehicleClass(carro)] then return false, 'sem_aeronave' end
    local min, max = GetModelDimensions(GetEntityModel(carro))
    if (limite.comprimento or 0) > 0 and max.y - min.y > limite.comprimento then return false, 'grande_demais' end
    return true
end

local function engatar(carro, ponto)
    if not meuCabo or not DoesEntityExist(meuCabo) then return end
    if ponto ~= 'lado' then
        local cabe, motivo = cabeNoCaminhao(meuCabo, carro)
        if not cabe then return notificar(motivo) end
    end
    if pcall(lib.requestAnimDict, ANIM.dict, 3000) then
        TaskTurnPedToFaceEntity(cache.ped, carro, 600)
        Wait(600)
        TaskPlayAnim(cache.ped, ANIM.dict, ANIM.clip, 4.0, -4.0, 1400, 1, 0, false, false, false)
        Wait(1400)
    end
    local ok, motivo = lib.callback.await('vel_guincho:cabo:engatar', false, NetworkGetNetworkIdFromEntity(meuCabo), NetworkGetNetworkIdFromEntity(carro), ponto)
    if not ok then return notificar(motivo or 'pedido_invalido') end
    PlaySoundFrontend(-1, 'Hook_Attach', 'DLC_IE_Steal_Cargobob_Sounds', true)
end

local function soltar(carro)
    local caminhao = caminhaoDoCarro(carro)
    if not caminhao then return end
    if pcall(lib.requestAnimDict, ANIM.dict, 3000) then
        TaskTurnPedToFaceEntity(cache.ped, carro, 600)
        Wait(600)
        TaskPlayAnim(cache.ped, ANIM.dict, ANIM.clip, 4.0, -4.0, 1200, 1, 0, false, false, false)
        Wait(1200)
    end
    local ok, motivo = lib.callback.await('vel_guincho:cabo:soltar', false, NetworkGetNetworkIdFromEntity(caminhao))
    if not ok then return notificar(motivo or 'pedido_invalido') end
    PlaySoundFrontend(-1, 'Hook_Detach', 'DLC_IE_Steal_Cargobob_Sounds', true)
end

-- Ponto do cabo neste carro ('frente'/'tras'), se estiver engatado
local function pontoEngatado(carro)
    local caminhao = caminhaoDoCarro(carro)
    return caminhao and Entity(caminhao).state.velCabo.ponto
end

-- Frente, traseira e meio: ponto calculado por modelo, em metros (anchor do Interact), com pontoLocal
local PONTAS = { 'frente', 'tras', 'lado' }
local OPCOES_CARRO = {}

CreateThread(function()
    for _, ponto in ipairs(PONTAS) do
        local function anchor(ent) return pontoLocal(ent, ponto) end
        OPCOES_CARRO[#OPCOES_CARRO + 1] = {
            name = 'vel_guincho_engatar_' .. ponto, icon = 'fa-solid fa-link', label = locale('engatar_' .. ponto), distance = 2.0, anchor = anchor,
            canInteract = function(ent)
                -- carro tombado: só "para desvirar" (no meio do carro); em pé: frente ou traseira
                return meuCabo ~= nil and ent ~= meuCabo and not caminhaoDoCarro(ent) and (ponto == 'lado') == GuinchoTombado(ent)
            end,
            onSelect = function(data) CreateThread(function() engatar(data.entity, ponto) end) end,
        }
        OPCOES_CARRO[#OPCOES_CARRO + 1] = {
            name = 'vel_guincho_soltar_' .. ponto, icon = 'fa-solid fa-link-slash', label = locale('soltar_cabo'), distance = 2.0, anchor = anchor,
            -- soltar em qualquer ponta (frente, traseira ou meio), não importa onde foi engatado
            canInteract = function(ent) return meuCabo == nil and pontoEngatado(ent) ~= nil end,
            onSelect = function(data) CreateThread(function() soltar(data.entity) end) end,
        }
    end
    exports.mri_Qinteract:addGlobalVehicle(OPCOES_CARRO)
end)

-- Caminhões por perto: põe e tira as opções do motor -------------------------

local function esquecer(veiculo)
    local info = caminhoes[veiculo]
    if not info then return end
    pcall(function() exports.mri_Qinteract:removeLocalEntity(veiculo) end)
    if info.ancora and DoesEntityExist(info.ancora) then DeleteEntity(info.ancora) end
    caminhoes[veiculo] = nil
end

local function varrer()
        local vivos = {}
        for _, v in ipairs(lib.getNearbyVehicles(GetEntityCoords(cache.ped), PERTO, true)) do
            local c = cadastroDe(v.vehicle)
            if c and c.pontos and c.pontos.motor then
                vivos[v.vehicle] = true
                if not caminhoes[v.vehicle] then
                    caminhoes[v.vehicle] = { c = c }
                    local ops = opcoesCaminhao(v.vehicle, c)
                    if ops then exports.mri_Qinteract:addLocalEntity(v.vehicle, ops) end
                end
            end
        end
        for veiculo in pairs(caminhoes) do
            if not vivos[veiculo] or not DoesEntityExist(veiculo) then esquecer(veiculo) end
        end
end

CreateThread(function()
    while true do
        local ok, erro = pcall(varrer)
        if not ok then print(('^1[vel_guincho] caminhões: %s^7'):format(erro)) end
        Wait(1000)
    end
end)

-- O cadastro mudou no painel: refaz as opções
AddStateBagChangeHandler('velGuincho', 'global', function()
    SetTimeout(300, function() for veiculo in pairs(caminhoes) do esquecer(veiculo) end end)
end)

-- Cabos: desenho para todos ------------------------------------------------

local function apagarCabo(veiculo)
    local cb = cabos[veiculo]
    if not cb then return end
    if cb.corda and DoesRopeExist(cb.corda) then DeleteRope(cb.corda) end
    if cb.gancho and DoesEntityExist(cb.gancho) then DeleteEntity(cb.gancho) end
    cabos[veiculo] = nil
end

local function texturas()
    if RopeAreTexturesLoaded() then return true end
    RopeLoadTextures()
    local limite = GetGameTimer() + 3000
    while not RopeAreTexturesLoaded() and GetGameTimer() < limite do Wait(0) end
    return RopeAreTexturesLoaded()
end

local function montarCabo(veiculo, c, s)
    apagarCabo(veiculo)
    local motor = motorNoMundo(veiculo, c)
    if not motor or not texturas() then return end
    local alvo, ponto, gancho
    if s.mao then
        local jogador = GetPlayerFromServerId(s.mao)
        local ped = jogador ~= -1 and GetPlayerPed(jogador) or 0
        if ped == 0 or not DoesEntityExist(ped) then return end
        lib.requestModel(GANCHO, 3000)
        gancho = CreateObject(GANCHO, motor.x, motor.y, motor.z, false, false, false)
        SetModelAsNoLongerNeeded(GANCHO)
        SetEntityCollision(gancho, false, false)
        AttachEntityToEntity(gancho, ped, GetPedBoneIndex(ped, MAO), 0.12, 0.02, -0.02, -90.0, 0.0, 0.0, true, true, false, false, 2, true)
        alvo = gancho
        ponto = GetEntityCoords(gancho)
    else
        alvo = NetworkGetEntityFromNetworkId(s.carro)
        if not alvo or alvo == 0 or not DoesEntityExist(alvo) then return end
        ponto = pontoDoCarro(alvo, s.ponto)
    end
    -- corda só visual: as pontas são presas a cada quadro (presa a entidades a corda puxa de verdade
    -- e arremessa o caminhão); quem move o carro é o sistema, de forma controlada
    local comprimento = math.max(0.5, #(motor - ponto) * 0.97)
    local corda = AddRope(motor.x, motor.y, motor.z, 0.0, 0.0, 0.0, caboMax(c) + 2.0, 4, comprimento, 0.5, 1.0, false, false, false, 1.0, false)
    cabos[veiculo] = { assinatura = json.encode(s), corda = corda, gancho = gancho, alvo = alvo, ponto = s.ponto, c = c }
end

local function atualizarCabos(meuId)
        local tenho = nil
        for veiculo, info in pairs(caminhoes) do
            local s = DoesEntityExist(veiculo) and Entity(veiculo).state.velCabo
            local cb = cabos[veiculo]
            if not s then
                if cb then apagarCabo(veiculo) end
            else
                if s.mao == meuId then tenho = veiculo end
                if not cb or cb.assinatura ~= json.encode(s) then montarCabo(veiculo, info.c, s) cb = cabos[veiculo] end
                -- o cabo acompanha a distância (sem esticar além do limite)
                if cb and cb.corda and DoesRopeExist(cb.corda) then
                    local motor = motorNoMundo(veiculo, info.c)
                    local fim = cb.gancho and GetEntityCoords(cb.gancho) or pontoDoCarro(cb.alvo, cb.ponto)
                    if motor and fim then RopeForceLength(cb.corda, math.max(0.5, #(motor - fim) * 0.97)) end
                end
            end
        end
        for veiculo in pairs(cabos) do
            if not caminhoes[veiculo] then apagarCabo(veiculo) end
        end
        meuCabo = tenho
        -- limite do cabo: quem segura o gancho não passa do comprimento
        if meuCabo then
            local info = caminhoes[meuCabo]
            local motor = info and motorNoMundo(meuCabo, info.c)
            if motor and #(GetEntityCoords(cache.ped) - motor) > caboMax(info.c) + 0.5 then
                notificar('cabo_limite', 'inform')
                lib.callback.await('vel_guincho:cabo:devolver', false, NetworkGetNetworkIdFromEntity(meuCabo))
            end
        end
end

CreateThread(function()
    while true do
        local ok, erro = pcall(atualizarCabos, cache.serverId)
        if not ok then print(('^1[vel_guincho] cabos: %s^7'):format(erro)) end
        Wait(200)
    end
end)

-- Pontas do cabo: motor e gancho/carro, todo quadro
CreateThread(function()
    while true do
        local algum = false
        for veiculo, cb in pairs(cabos) do
            if cb.corda and DoesRopeExist(cb.corda) and DoesEntityExist(veiculo) then
                algum = true
                local motor = motorNoMundo(veiculo, cb.c)
                local fim = cb.gancho and DoesEntityExist(cb.gancho) and GetEntityCoords(cb.gancho)
                    or (cb.alvo and DoesEntityExist(cb.alvo) and pontoDoCarro(cb.alvo, cb.ponto))
                if motor and fim then
                    -- todos os pontos da corda na linha reta: cabo de aço tensionado, sem a física
                    -- elástica da corda do GTA (que estica e afunda sozinha)
                    local n = GetRopeVertexCount(cb.corda)
                    if n > 1 then
                        local passo = (fim - motor) / (n - 1)
                        for i = 0, n - 1 do
                            local p = motor + passo * i
                            PinRopeVertex(cb.corda, i, p.x, p.y, p.z)
                        end
                    end
                end
            end
        end
        Wait(algum and 0 or 250)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veiculo in pairs(cabos) do apagarCabo(veiculo) end
    for veiculo in pairs(caminhoes) do esquecer(veiculo) end
    local nomes = {}
    for _, o in ipairs(OPCOES_CARRO) do nomes[#nomes + 1] = o.name end
    pcall(function() exports.mri_Qinteract:removeGlobalVehicle(nomes) end)
end)

-- Diagnóstico (/guinchoinfo, admin): o que o guincho enxerga no veículo mais perto
RegisterNetEvent('vel_guincho:client:info', function()
    local v = lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
    local linhas = {}
    linhas[#linhas + 1] = ('cabo na mão: %s'):format(tostring(meuCabo))
    if v then
        local r = GetEntityRotation(v, 2)
        linhas[#linhas + 1] = ('veículo %s | IsEntityUpsidedown: %s | roll %.0f | pitch %.0f | rot %.0f %.0f %.0f'):format(
            GetDisplayNameFromVehicleModel(GetEntityModel(v)), tostring(IsEntityUpsidedown(v)), GetEntityRoll(v), GetEntityPitch(v), r.x, r.y, r.z)
        local engatado = caminhaoDoCarro(v)
        linhas[#linhas + 1] = ('tombado: %s | engatado em caminhão: %s | é o caminhão do cabo: %s'):format(
            tostring(GuinchoTombado(v)), tostring(engatado or false), tostring(v == meuCabo))
    else
        linhas[#linhas + 1] = 'nenhum veículo a 6 m'
    end
    for _, l in ipairs(linhas) do print('[vel_guincho] ' .. l) end
    lib.notify({ title = 'Guincho', description = table.concat(linhas, ' · '), type = 'inform', duration = 15000 })
end)
