-- Etapa 3: o cabo. O servidor confere quem pode, distâncias e carro vazio, e guarda o estado no
-- statebag do caminhão (velCabo); todos os clientes desenham o cabo a partir dele.
-- velCabo = { mao = serverId } (gancho na mão) | { carro = netId, ponto = 'frente'|'tras', por = serverId }

local comCabo = {} -- [netId do caminhão] = true (para limpar quando o jogador sai)
local ultimo = {}  -- [source] = GetGameTimer() (limite de pedidos)

local function cadastroDe(entidade)
    local estado = GlobalState.velGuincho
    return estado and estado.caminhoes and estado.caminhoes[tostring(GetEntityModel(entidade))]
end

local function entidade(netId)
    local e = tonumber(netId) and NetworkGetEntityFromNetworkId(netId)
    return e and e ~= 0 and DoesEntityExist(e) and e or nil
end

local function distancia(source, e)
    return #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(e))
end

---Emprego liberado no caminhão (e em serviço, se o cadastro pedir).
function Guincho.podeOperar(source, c)
    if Guincho.admin(source) then return true end
    local p = exports.qbx_core:GetPlayer(source)
    local job = p and p.PlayerData and p.PlayerData.job
    if not job or not lib.table.contains(c.empregos or {}, job.name) then return false, 'sem_emprego' end
    if c.exigeServico and not job.onduty then return false, 'fora_servico' end
    return true
end

---Carro de lado ou de rodas para cima (giro em X ou Y acima de 60°).
local function tombado(carro)
    local r = GetEntityRotation(carro, 2)
    return math.abs(r.x) > 60.0 or math.abs(r.y) > 60.0
end

local function vazio(carro)
    for assento = -1, 8 do
        if GetPedInVehicleSeat(carro, assento) ~= 0 then return false end
    end
    return true
end

local function definir(caminhao, valor)
    Entity(caminhao).state:set('velCabo', valor, true)
    comCabo[NetworkGetNetworkIdFromEntity(caminhao)] = valor and true or nil
end

local function cedo(source)
    local agora = GetGameTimer()
    if ultimo[source] and agora - ultimo[source] < 300 then return true end
    ultimo[source] = agora
    return false
end

-- Pegar o cabo no motor do guincho
lib.callback.register('vel_guincho:cabo:pegar', function(source, netCaminhao)
    if cedo(source) then return false end
    local caminhao = entidade(netCaminhao)
    local c = caminhao and cadastroDe(caminhao)
    if not c then return false, 'nao_e_guincho' end
    local ok, motivo = Guincho.podeOperar(source, c)
    if not ok then return false, motivo end
    if distancia(source, caminhao) > 12.0 then return false, 'longe' end
    if Entity(caminhao).state.velCabo then return false, 'cabo_ocupado' end
    definir(caminhao, { mao = source })
    return true
end)

-- Devolver o cabo ao motor (com o gancho na mão)
lib.callback.register('vel_guincho:cabo:devolver', function(source, netCaminhao)
    local caminhao = entidade(netCaminhao)
    local s = caminhao and Entity(caminhao).state.velCabo
    if not s or s.mao ~= source then return false end
    definir(caminhao, nil)
    return true
end)

-- Engatar o gancho num carro
lib.callback.register('vel_guincho:cabo:engatar', function(source, netCaminhao, netCarro, ponto)
    if cedo(source) then return false end
    local caminhao, carro = entidade(netCaminhao), entidade(netCarro)
    local s = caminhao and Entity(caminhao).state.velCabo
    if not s or s.mao ~= source or not carro or carro == caminhao or GetEntityType(carro) ~= 2 then return false end
    if ponto ~= 'frente' and ponto ~= 'tras' and ponto ~= 'lado' then return false end
    local c = cadastroDe(caminhao)
    if distancia(source, carro) > 4.0 then return false, 'longe' end
    if #(GetEntityCoords(carro) - GetEntityCoords(caminhao)) > (Config.Cabo[c.cabo] or 15.0) + 8.0 then return false, 'cabo_curto' end
    if not vazio(carro) then return false, 'so_vazio' end
    -- carro tombado só engata "para desvirar"; carro em pé só pela frente ou traseira
    if (ponto == 'lado') ~= tombado(carro) then return false, ponto == 'lado' and 'nao_tombado' or 'tombado' end
    for netId in pairs(comCabo) do
        local outro = entidade(netId)
        local o = outro and Entity(outro).state.velCabo
        if o and o.carro == netCarro then return false, 'ja_engatado' end
    end
    definir(caminhao, { carro = netCarro, ponto = ponto, por = source, desvirar = ponto == 'lado' or nil })
    Guincho.log(source, 'engatou', carro, c)
    return true
end)

-- Soltar o gancho do carro (volta para a mão de quem soltou)
lib.callback.register('vel_guincho:cabo:soltar', function(source, netCaminhao)
    if cedo(source) then return false end
    local caminhao = entidade(netCaminhao)
    local s = caminhao and Entity(caminhao).state.velCabo
    if not s or not s.carro then return false end
    local c = cadastroDe(caminhao)
    local ok, motivo = Guincho.podeOperar(source, c)
    if not ok then return false, motivo end
    local carro = entidade(s.carro)
    if carro and distancia(source, carro) > 5.0 then return false, 'longe' end
    if s.carga or s.fase then return false, 'carro_preso' end
    definir(caminhao, { mao = source })
    return true
end)

-- Quem sai do jogo com o gancho na mão: o cabo volta para o motor
AddEventHandler('playerDropped', function()
    local src = source
    ultimo[src] = nil
    for netId in pairs(comCabo) do
        local caminhao = entidade(netId)
        local s = caminhao and Entity(caminhao).state.velCabo
        if not s then comCabo[netId] = nil
        elseif s.mao == src then definir(caminhao, nil) end
    end
end)

AddEventHandler('entityRemoved', function(e)
    if GetEntityType(e) == 2 then comCabo[NetworkGetNetworkIdFromEntity(e)] = nil end
end)

-- Etapa 4/5: puxar o carro para a plataforma e descer. Quem pede anima o carro no próprio cliente
-- (com o controle de rede do carro) e avisa quando terminou; o servidor só guarda a fase.
-- velCabo ganha: fase = 'subindo'|'descendo' (durante o movimento), carga = true (carro preso)
lib.callback.register('vel_guincho:carga:comando', function(source, netCaminhao, acao)
    if cedo(source) then return false end
    local caminhao = entidade(netCaminhao)
    local s = caminhao and Entity(caminhao).state.velCabo
    if not s or not s.carro or s.fase then return false end
    local c = cadastroDe(caminhao)
    local ok, motivo = Guincho.podeOperar(source, c)
    if not ok then return false, motivo end
    if distancia(source, caminhao) > 10.0 then return false, 'longe' end
    if acao == 'puxar' and s.carga then return false end
    if acao == 'descer' and not s.carga then return false end
    if acao ~= 'puxar' and acao ~= 'descer' then return false end
    s.fase, s.por = acao == 'puxar' and 'subindo' or 'descendo', source
    definir(caminhao, s)
    return true
end)

lib.callback.register('vel_guincho:carga:concluir', function(source, netCaminhao, sucesso)
    local caminhao = entidade(netCaminhao)
    local s = caminhao and Entity(caminhao).state.velCabo
    if not s or not s.fase or s.por ~= source then return false end
    if sucesso then
        s.carga = s.fase == 'subindo' or nil
        Guincho.log(source, s.carga and 'carregou' or 'descarregou', entidade(s.carro), cadastroDe(caminhao))
    end
    s.fase = nil
    definir(caminhao, s)
    return true
end)

-- Desvirar: o motorista do caminhão puxou o carro até ficar de pé; o cabo volta para o guincho
lib.callback.register('vel_guincho:desvirar:concluir', function(source, netCaminhao)
    local caminhao = entidade(netCaminhao)
    local s = caminhao and Entity(caminhao).state.velCabo
    if not s or not s.desvirar then return false end
    local motorista = GetPedInVehicleSeat(caminhao, -1) == GetPlayerPed(source)
    if not motorista and (not Guincho.podeOperar(source, cadastroDe(caminhao)) or distancia(source, caminhao) > 10.0) then return false end
    local carro = entidade(s.carro)
    if not carro or tombado(carro) then return false end
    Guincho.log(source, 'desvirou', carro, cadastroDe(caminhao))
    s.desvirar = nil
    definir(caminhao, s)
    return true
end)
