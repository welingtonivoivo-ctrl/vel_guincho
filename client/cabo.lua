-- Etapa 3: o cabo. Opções do mri_Qinteract no motor do guincho e em qualquer carro; cada cliente
-- desenha o cabo (corda do GTA) a partir do statebag velCabo do caminhão. O servidor decide tudo.

local GANCHO = `prop_winch_hook_short`
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
local function pontoDoCarro(carro, ponto)
    local min, max = GetModelDimensions(GetEntityModel(carro))
    local y = ponto == 'frente' and (max.y - 0.15) or (min.y + 0.15)
    return GetOffsetFromEntityInWorldCoords(carro, 0.0, y, min.z + 0.45)
end

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

local function engatar(carro)
    if not meuCabo or not DoesEntityExist(meuCabo) then return end
    -- frente ou traseira: a ponta do carro mais perto de quem engata
    local p = GetEntityCoords(cache.ped)
    local ponto = #(p - pontoDoCarro(carro, 'frente')) <= #(p - pontoDoCarro(carro, 'tras')) and 'frente' or 'tras'
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

CreateThread(function()
    exports.mri_Qinteract:addGlobalVehicle({
        {
            name = 'vel_guincho_engatar', icon = 'fa-solid fa-link', label = locale('engatar_cabo'), distance = 2.5,
            canInteract = function(ent) return meuCabo ~= nil and ent ~= meuCabo and not caminhaoDoCarro(ent) end,
            onSelect = function(data) CreateThread(function() engatar(data.entity) end) end,
        },
        {
            name = 'vel_guincho_soltar', icon = 'fa-solid fa-link-slash', label = locale('soltar_cabo'), distance = 2.5,
            canInteract = function(ent) return meuCabo == nil and caminhaoDoCarro(ent) ~= nil end,
            onSelect = function(data) CreateThread(function() soltar(data.entity) end) end,
        },
    })
end)

-- Caminhões por perto: põe e tira as opções do motor -------------------------

local function esquecer(veiculo)
    local info = caminhoes[veiculo]
    if not info then return end
    pcall(function() exports.mri_Qinteract:removeLocalEntity(veiculo) end)
    if info.ancora and DoesEntityExist(info.ancora) then DeleteEntity(info.ancora) end
    caminhoes[veiculo] = nil
end

CreateThread(function()
    while true do
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
    local comprimento = math.max(1.0, #(motor - ponto))
    local corda = AddRope(motor.x, motor.y, motor.z, 0.0, 0.0, 0.0, caboMax(c) + 2.0, 4, comprimento, 0.5, 1.0, false, false, false, 1.0, false)
    AttachEntitiesToRope(corda, veiculo, alvo, motor.x, motor.y, motor.z, ponto.x, ponto.y, ponto.z, comprimento, false, false, nil, nil)
    cabos[veiculo] = { assinatura = json.encode(s), corda = corda, gancho = gancho, alvo = alvo, ponto = s.ponto }
end

CreateThread(function()
    local meuId = cache.serverId
    while true do
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
                    if motor and fim then RopeForceLength(cb.corda, math.min(caboMax(info.c) + 2.0, #(motor - fim) + 0.3)) end
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
        Wait(200)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veiculo in pairs(cabos) do apagarCabo(veiculo) end
    for veiculo in pairs(caminhoes) do esquecer(veiculo) end
    pcall(function() exports.mri_Qinteract:removeGlobalVehicle({ 'vel_guincho_engatar', 'vel_guincho_soltar' }) end)
end)
