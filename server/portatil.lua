-- Etapa 7B: guincho portátil (item). Usar o item abre a mira no cliente; o servidor confere o item e
-- a distância, tira o item do inventário e cria o motor fixo no lugar (objeto em rede, congelado).
-- O motor vira a âncora do cabo, igual a um caminhão (statebag velCabo), e só desvira.
-- velPortatil (statebag do motor) = { dono = serverId|nil, usos = número }
-- Recolher devolve o item com os usos que sobraram; sem usos, o guincho quebra e não volta.

Portatil = {}

local P = Config.Portatil
local MODELO = joaat(P.modelo)
local LOJA = 'vel_guincho_portatil'
local montados = {} -- [netId] = { obj, dono, usos }
local ultimo = {}

local function cedo(source)
    local agora = GetGameTimer()
    if ultimo[source] and agora - ultimo[source] < 800 then return true end
    ultimo[source] = agora
    return false
end

---Metadados do item: usos e a barra de desgaste do ox_inventory (durability 0–100).
local function metadados(usos)
    return {
        usos = usos,
        durability = math.floor(usos / P.usos * 100 + 0.5),
        description = locale('portatil_usos', usos, P.usos),
    }
end

local function publicar()
    local lista = {}
    for net in pairs(montados) do lista[#lista + 1] = net end
    GlobalState.velPortateis = lista
end

local function deDono(source)
    for net, m in pairs(montados) do
        if m.dono == source then return net, m end
    end
end

-- Item usado no inventário: o ox_inventory não consome; o cliente abre a mira
exports('usarPortatil', function(event, _, inventory, slot)
    if event ~= 'usingItem' then return end
    local src = inventory and inventory.id
    if type(src) ~= 'number' then return false end
    if deDono(src) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('painel_titulo'), description = locale('portatil_ja_montado'), type = 'error' })
        return false
    end
    TriggerClientEvent('vel_guincho:portatil:montar', src, slot)
    return false
end)

local function numero(v)
    v = tonumber(v)
    return v and v == v and v or nil
end

-- Fixar o motor no ponto mirado (pos = mundo, rot = graus)
lib.callback.register('vel_guincho:portatil:fixar', function(source, slot, pos, rot)
    if cedo(source) then return false end
    slot = tonumber(slot)
    if not slot or type(pos) ~= 'table' or type(rot) ~= 'table' then return false, 'pedido_invalido' end
    local x, y, z = numero(pos.x), numero(pos.y), numero(pos.z)
    local rx, ry, rz = numero(rot.x), numero(rot.y), numero(rot.z)
    if not (x and y and z and rx and ry and rz) then return false, 'pedido_invalido' end
    if deDono(source) then return false, 'portatil_ja_montado' end
    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item or item.name ~= P.item then return false, 'portatil_sem_item' end
    local ped = GetPlayerPed(source)
    if #(GetEntityCoords(ped) - vec3(x, y, z)) > P.alcance + 1.5 then return false, 'longe' end
    local usos = math.floor(tonumber(item.metadata and item.metadata.usos) or P.usos)
    if usos <= 0 then return false, 'portatil_quebrado' end
    if not exports.ox_inventory:RemoveItem(source, P.item, 1, nil, slot) then return false, 'portatil_sem_item' end

    local obj = CreateObjectNoOffset(MODELO, x, y, z, true, true, false)
    local limite = GetGameTimer() + 2000
    while not DoesEntityExist(obj) and GetGameTimer() < limite do Wait(0) end
    if not DoesEntityExist(obj) then
        exports.ox_inventory:AddItem(source, P.item, 1, metadados(usos))
        return false, 'falhou_portatil'
    end
    SetEntityRotation(obj, rx, ry, rz, 2, true)
    FreezeEntityPosition(obj, true)
    local net = NetworkGetNetworkIdFromEntity(obj)
    montados[net] = { obj = obj, dono = source, usos = usos }
    Entity(obj).state:set('velPortatil', { dono = source, usos = usos }, true)
    publicar()
    Guincho.log(source, 'portatil_fixou', nil, { modelo = P.modelo })
    return true
end)

---Recolher o motor: só o dono (ou qualquer um, se o dono saiu do jogo). Cabo tem que estar solto.
lib.callback.register('vel_guincho:portatil:recolher', function(source, net)
    if cedo(source) then return false end
    net = tonumber(net)
    local m = net and montados[net]
    if not m or not DoesEntityExist(m.obj) then return false end
    if m.dono and m.dono ~= source then return false, 'portatil_nao_e_seu' end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(m.obj)) > 4.0 then return false, 'longe' end
    local cabo = Entity(m.obj).state.velCabo
    if cabo and (cabo.carro or cabo.mao ~= source) then return false, 'portatil_solte_cabo' end
    if m.usos > 0 then
        if not exports.ox_inventory:CanCarryItem(source, P.item, 1) then return false, 'portatil_sem_espaco' end
        exports.ox_inventory:AddItem(source, P.item, 1, metadados(m.usos))
    end
    DeleteEntity(m.obj)
    montados[net] = nil
    publicar()
    return true, m.usos <= 0 and 'portatil_sucata' or 'portatil_recolhido'
end)

---Uma desvirada feita com este motor: gasta 1 uso (chamado pelo desvirar:concluir).
function Portatil.gastar(obj, source)
    local net = NetworkGetNetworkIdFromEntity(obj)
    local m = montados[net]
    if not m then return end
    m.usos = math.max(0, m.usos - 1)
    Entity(obj).state:set('velPortatil', { dono = m.dono, usos = m.usos }, true)
    local chave = m.usos == 0 and 'portatil_quebrou' or 'portatil_restam'
    TriggerClientEvent('ox_lib:notify', source, {
        title = locale('painel_titulo'), description = locale(chave, m.usos), type = m.usos == 0 and 'error' or 'inform',
    })
end

-- O dono saiu do jogo: o motor fica no lugar e qualquer um pode recolher
AddEventHandler('playerDropped', function()
    local src = source
    ultimo[src] = nil
    for _, m in pairs(montados) do
        if m.dono == src then
            m.dono = nil
            if DoesEntityExist(m.obj) then Entity(m.obj).state:set('velPortatil', { usos = m.usos }, true) end
        end
    end
end)

AddEventHandler('entityRemoved', function(e)
    local net = NetworkGetNetworkIdFromEntity(e)
    if montados[net] then montados[net] = nil publicar() end
end)

-- Resource parando: devolve o item a quem está online e tira os motores do mundo
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, m in pairs(montados) do
        if m.dono and m.usos > 0 and GetPlayerPing(m.dono) > 0 then
            pcall(function() exports.ox_inventory:AddItem(m.dono, P.item, 1, metadados(m.usos)) end)
        end
        if DoesEntityExist(m.obj) then DeleteEntity(m.obj) end
    end
    GlobalState.velPortateis = {}
end)

-- Loja só dos empregos da mecânica (o balcão é um ponto do Interact marcado no painel)
local function registrarLoja()
    local grupos = {}
    for _, nome in ipairs(P.empregosLoja) do grupos[nome] = 0 end
    -- o item só existe para o ox_inventory depois que ele reinicia com o items.lua novo
    local ok, erro = pcall(function()
        exports.ox_inventory:RegisterShop(LOJA, {
            name = locale('portatil_loja'),
            groups = grupos,
            inventory = { { name = P.item, price = P.preco, metadata = metadados(P.usos) } },
        })
    end)
    if not ok then print(('^1[vel_guincho] loja do guincho portátil: %s^7'):format(erro)) end
end

CreateThread(function()
    GlobalState.velPortateis = {}
    registrarLoja()
end)

-- o ox_inventory reiniciado esquece as lojas registradas por outros resources
AddEventHandler('onResourceStart', function(res)
    if res == 'ox_inventory' then registrarLoja() end
end)
