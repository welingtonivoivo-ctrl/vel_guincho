-- Etapa 4/5: puxar o carro para a plataforma e descer. Quem opera a caixa de comando anima o carro
-- (preso ao caminhão, posição recalculada a cada quadro, sem física solta que derruba o carro). Com o
-- carro carregado, quem tem o controle de rede do carro o mantém deitado na plataforma, mesmo quando
-- o motorista inclina ou recolhe a plataforma. Com o cabo engatado e o carro no chão, o caminhão não anda.

GuinchoCarga = {}

local VELOCIDADE = 0.7 -- m/s do carro sendo puxado
local ALAVANCA = { dict = 'anim@scripted@heist@ig2_hand_lever@male@', clip = 'idle' }
local ancoras = {}     -- [caminhão] = objeto preso à peça da plataforma
local operando = false

local function notificar(chave, tipo)
    lib.notify({ title = locale('painel_titulo'), description = locale(chave), type = tipo or 'error' })
end

local function cadastroDe(veiculo)
    local estado = GlobalState.velGuincho
    return estado and estado.caminhoes and estado.caminhoes[tostring(GetEntityModel(veiculo))]
end

local function ancoraDe(caminhao, c)
    local carga = c.pontos.carga
    if not carga or not carga.osso then return nil end
    local a = ancoras[caminhao]
    if a and DoesEntityExist(a) then return a end
    local i = Plataforma.osso(caminhao, carga.osso)
    if not i then return nil end
    a = Plataforma.ancora(caminhao, i)
    ancoras[caminhao] = a
    return a
end

---Pose do carro preso na plataforma agora (relativa ao caminhão): centro, inclinação, giro.
local function poseCarga(caminhao, c, ponto)
    local centro, inclinacao, giro = Plataforma.carga(caminhao, c.pontos.carga, ancoraDe(caminhao, c))
    -- engatado pela traseira, o carro sobe de ré
    if ponto == 'tras' then giro = (giro + 180.0) % 360.0 end
    return centro, inclinacao, giro
end

local function prender(carro, caminhao, pos, inclinacao, giro)
    AttachEntityToEntity(carro, caminhao, 0, pos.x, pos.y, pos.z, inclinacao, 0.0, giro, false, false, false, false, 2, true)
end

local function controlar(carro)
    local limite = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(carro) and GetGameTimer() < limite do
        NetworkRequestControlOfEntity(carro)
        Wait(0)
    end
    return NetworkHasControlOfEntity(carro)
end

local function difAngulo(a, b) return (b - a + 180.0) % 360.0 - 180.0 end

---Plataforma descida o bastante para o carro subir (mecanismos que inclinam).
local function plataformaDescida(caminhao, c)
    if c.plataforma == 'fixa' then return true end
    local _, inclinacao = poseCarga(caminhao, c)
    return math.abs(inclinacao) > 4.0
end

---Caminho do carro: pontos relativos ao caminhão { pos, inclinação, giro }.
local function caminho(caminhao, carro, c, ponto)
    local min = GetModelDimensions(GetEntityModel(carro))
    local lift = -min.z
    local r = c.pontos.rampa
    local centro, inclinacao, giro = poseCarga(caminhao, c, ponto)
    local agora = GetEntityCoords(carro)
    local inicio = GetOffsetFromEntityGivenWorldCoords(caminhao, agora.x, agora.y, agora.z)
    local giroAgora = (GetEntityHeading(carro) - GetEntityHeading(caminhao)) % 360.0
    local rampa = vec3(0.0, r.y, r.z + lift)
    return {
        { pos = inicio, inclinacao = 0.0, giro = giroAgora },
        { pos = rampa, inclinacao = 0.0, giro = giro },
        { pos = centro, inclinacao = inclinacao, giro = giro },
    }
end

---Leva o carro pelos pontos, na velocidade do guincho.
local function percorrer(carro, caminhao, pontos)
    for i = 1, #pontos - 1 do
        local a, b = pontos[i], pontos[i + 1]
        local dist = #(b.pos - a.pos)
        local duracao = math.max(300, dist / VELOCIDADE * 1000)
        local t0 = GetGameTimer()
        while true do
            if not DoesEntityExist(carro) or not DoesEntityExist(caminhao) then return false end
            local t = math.min(1.0, (GetGameTimer() - t0) / duracao)
            local pos = a.pos + (b.pos - a.pos) * t
            local inc = a.inclinacao + (b.inclinacao - a.inclinacao) * t
            local giro = a.giro + difAngulo(a.giro, b.giro) * t
            prender(carro, caminhao, pos, inc, giro)
            if t >= 1.0 then break end
            Wait(0)
        end
    end
    return true
end

local function alavanca(ligar)
    if ligar then
        if pcall(lib.requestAnimDict, ALAVANCA.dict, 3000) then
            TaskPlayAnim(cache.ped, ALAVANCA.dict, ALAVANCA.clip, 4.0, -4.0, -1, 1, 0, false, false, false)
        end
    else
        StopAnimTask(cache.ped, ALAVANCA.dict, ALAVANCA.clip, 2.0)
    end
end

local function operar(caminhao, acao)
    if operando then return end
    local c = cadastroDe(caminhao)
    local s = Entity(caminhao).state.velCabo
    if not c or not s or not s.carro then return end
    if not c.pontos.carga or not c.pontos.rampa then return notificar('sem_pontos') end
    if not plataformaDescida(caminhao, c) then return notificar('incline_primeiro', 'inform') end
    local carro = NetworkGetEntityFromNetworkId(s.carro)
    if not carro or carro == 0 or not DoesEntityExist(carro) then return end
    local net = NetworkGetNetworkIdFromEntity(caminhao)
    local ok, motivo = lib.callback.await('vel_guincho:carga:comando', false, net, acao)
    if not ok then return notificar(motivo or 'pedido_invalido') end
    operando = true
    alavanca(true)
    local sucesso = controlar(carro)
    if sucesso then
        local pontos = caminho(caminhao, carro, c, s.ponto)
        if acao == 'puxar' then
            sucesso = percorrer(carro, caminhao, pontos)
        else
            -- descer: da plataforma até a rampa e 1,5 m além, e solta no chão
            local fora = { pos = pontos[2].pos + vec3(0.0, -1.5, 0.0), inclinacao = 0.0, giro = pontos[2].giro }
            local agora = { pos = pontos[3].pos, inclinacao = pontos[3].inclinacao, giro = pontos[3].giro }
            sucesso = percorrer(carro, caminhao, { agora, pontos[2], fora })
            if sucesso then
                DetachEntity(carro, true, true)
                SetVehicleOnGroundProperly(carro)
            end
        end
    end
    alavanca(false)
    lib.callback.await('vel_guincho:carga:concluir', false, net, sucesso)
    operando = false
    if not sucesso then notificar('falhou_carga') end
end

---Opções da caixa de comando (somadas às do cabo no mesmo caminhão).
function GuinchoCarga.opcoes(caminhao, c)
    local caixa = c.pontos.caixa
    if not caixa or c.tipo ~= 'plataforma' then return {} end
    local onde = vec3(caixa.x, caixa.y, caixa.z + 1.0) -- marcada nos pés: o comando fica na altura da mão
    return {
        {
            name = 'vel_guincho_puxar', icon = 'fa-solid fa-angles-up', label = locale('puxar_carro'), distance = 2.0, offsetAbsolute = onde,
            canInteract = function(ent)
                local s = Entity(ent).state.velCabo
                return not operando and s and s.carro and not s.carga and not s.fase
            end,
            onSelect = function(data) CreateThread(function() operar(data.entity or caminhao, 'puxar') end) end,
        },
        {
            name = 'vel_guincho_descer', icon = 'fa-solid fa-angles-down', label = locale('descer_carro'), distance = 2.0, offsetAbsolute = onde,
            canInteract = function(ent)
                local s = Entity(ent).state.velCabo
                return not operando and s and s.carga and not s.fase
            end,
            onSelect = function(data) CreateThread(function() operar(data.entity or caminhao, 'descer') end) end,
        },
    }
end

-- Carro carregado: quem tem o controle dele o mantém deitado na plataforma ------------------

CreateThread(function()
    while true do
        local espera = 500
        for _, v in ipairs(lib.getNearbyVehicles(GetEntityCoords(cache.ped), 80.0, true)) do
            local caminhao = v.vehicle
            local s = Entity(caminhao).state.velCabo
            if s and s.carga and not s.fase then
                local c = cadastroDe(caminhao)
                local carro = NetworkGetEntityFromNetworkId(s.carro)
                if c and carro ~= 0 and DoesEntityExist(carro) and NetworkHasControlOfEntity(carro) then
                    local centro, inclinacao, giro = poseCarga(caminhao, c, s.ponto)
                    prender(carro, caminhao, centro, inclinacao, giro)
                    espera = 0
                end
            end
        end
        Wait(espera)
    end
end)

-- Freio: cabo engatado com o carro no chão, o caminhão não anda -------------------------------

CreateThread(function()
    local aviso = 0
    while true do
        local espera = 500
        local v = cache.vehicle
        if v and cache.seat == -1 then
            local s = Entity(v).state.velCabo
            if s and s.carro and not s.carga then
                espera = 0
                DisableControlAction(0, 71, true) -- acelerar
                DisableControlAction(0, 72, true) -- frear / ré
                if (IsDisabledControlPressed(0, 71) or IsDisabledControlPressed(0, 72)) and GetGameTimer() > aviso then
                    aviso = GetGameTimer() + 5000
                    notificar('caminhao_freado', 'inform')
                end
            end
        end
        Wait(espera)
    end
end)

-- Desvirar: o motorista segura G e o cabo gira o carro tombado até ficar de pé ----------------

local PUXAR = 47        -- G
local GIRO = 35.0       -- graus por segundo
local erguido = {}      -- [carro] = true depois de subir 60 cm para girar sem raspar no chão

local function desvirarAgora(caminhao, carro)
    if not controlar(carro) then return end
    local r = GetEntityRotation(carro, 2)
    local passo = GIRO * GetFrameTime()
    local function chegar(a) return math.abs(a) <= passo and 0.0 or (a - passo * (a > 0 and 1 or -1)) end
    local x, y = chegar(r.x), chegar(r.y)
    FreezeEntityPosition(carro, true)
    if not erguido[carro] then
        erguido[carro] = true
        local c = GetEntityCoords(carro)
        SetEntityCoordsNoOffset(carro, c.x, c.y, c.z + 0.6, false, false, false)
    end
    SetEntityRotation(carro, x, y, r.z, 2, true)
    if math.abs(x) < 1.0 and math.abs(y) < 1.0 then
        erguido[carro] = nil
        FreezeEntityPosition(carro, false)
        SetVehicleOnGroundProperly(carro)
        if lib.callback.await('vel_guincho:desvirar:concluir', false, NetworkGetNetworkIdFromEntity(caminhao)) then
            PlaySoundFrontend(-1, 'Hook_Detach', 'DLC_IE_Steal_Cargobob_Sounds', true)
            notificar('desvirado', 'success')
        end
        return true
    end
end

CreateThread(function()
    local trilho = false
    while true do
        local espera = 500
        local v = cache.vehicle
        local s = v and cache.seat == -1 and Entity(v).state.velCabo
        local ativo = s and s.desvirar
        if ativo then
            espera = 0
            if not trilho then
                trilho = true
                SendNUIMessage({ action = 'placeHud', data = { mode = 'desvirar', texto = locale('desvirar_segure') } })
            end
            local carro = NetworkGetEntityFromNetworkId(s.carro)
            if carro ~= 0 and DoesEntityExist(carro) and IsControlPressed(0, PUXAR) then
                if desvirarAgora(v, carro) then Wait(500) end
            elseif carro ~= 0 and DoesEntityExist(carro) and IsControlJustReleased(0, PUXAR) then
                FreezeEntityPosition(carro, false)
            end
        elseif trilho then
            trilho = false
            SendNUIMessage({ action = 'placeHud', data = false })
        end
        Wait(espera)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, a in pairs(ancoras) do if DoesEntityExist(a) then DeleteEntity(a) end end
end)
