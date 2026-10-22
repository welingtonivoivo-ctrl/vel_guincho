-- Aba "Guincho" do mri_Qadmin (html/painel.html). Para marcar no mundo a aba fecha, a ferramenta roda
-- no caminhão que está perto e a aba volta. Pontos são salvos relativos ao caminhão (valem para todos
-- os caminhões daquele modelo, em qualquer lugar).

local PLUGIN = 'vel_guincho'
local PERTO = 15.0
local CARRO_PREVIA = 'sultan'
local PERMITIDAS = { dados = true, salvar = true, novo = true, remover = true }

-- Pontos que o painel marca e como cada um é marcado
local PONTOS = {
    motor = { ferramenta = 'ponto', naPlataforma = true },
    caixa = { ferramenta = 'aqui' },
    carga = { ferramenta = 'carro', naPlataforma = true },
    rampa = { ferramenta = 'ponto', inclinada = true },
    engate = { ferramenta = 'ponto' },
}

local function notificar(texto, tipo)
    lib.notify({ title = locale('painel_titulo'), description = texto, type = tipo or 'inform' })
end

local function cadastroPorId(id)
    local estado = GlobalState.velGuincho
    for _, c in pairs(estado and estado.caminhoes or {}) do
        if c.id == id then return c end
    end
end

---O caminhão daquele modelo em que o admin está, ou o mais perto dele.
local function caminhaoPerto(modelo)
    local hash = joaat(modelo)
    if cache.vehicle and GetEntityModel(cache.vehicle) == hash then return cache.vehicle end
    local perto = lib.getClosestVehicle(GetEntityCoords(cache.ped), PERTO, true)
    if perto and GetEntityModel(perto) == hash then return perto end
    for _, v in ipairs(lib.getNearbyVehicles(GetEntityCoords(cache.ped), PERTO, true)) do
        if GetEntityModel(v.vehicle) == hash then return v.vehicle end
    end
end

local function relativo(caminhao, coords, heading)
    local o = GetOffsetFromEntityGivenWorldCoords(caminhao, coords.x, coords.y, coords.z)
    local r = { x = o.x, y = o.y, z = o.z }
    if heading then r.h = (heading - GetEntityHeading(caminhao)) % 360 end
    return r
end

---Posição no mundo de um ponto salvo (preso ao caminhão ou à peça da plataforma).
---ancoras: cache { [osso] = objeto } que quem chama apaga depois.
local function noMundoDe(caminhao, p, ancoras)
    if p.osso then
        local a = ancoras[p.osso]
        if a == nil then
            local i = Plataforma.osso(caminhao, p.osso)
            a = i and Plataforma.ancora(caminhao, i) or false
            ancoras[p.osso] = a
        end
        if a then return GetOffsetFromEntityInWorldCoords(a, p.x, p.y, p.z) end
    end
    return GetOffsetFromEntityInWorldCoords(caminhao, p.x, p.y, p.z)
end

local function apagarAncoras(ancoras)
    for _, a in pairs(ancoras) do if a then DeleteEntity(a) end end
end

---Leva a plataforma de 'de' até 'ate' (caminhão travado enquanto ela se move).
local function moverPlataforma(caminhao, mecanismo, de, ate)
    if mecanismo == 'fixa' then return end
    FreezeEntityPosition(caminhao, true)
    local inicio = GetGameTimer()
    while true do
        local t = math.min(1.0, (GetGameTimer() - inicio) / Config.TempoPlataforma)
        Plataforma.mover(caminhao, mecanismo, de + (ate - de) * t)
        if t >= 1.0 then break end
        Wait(0)
    end
    if ate == 0.0 then FreezeEntityPosition(caminhao, false) end
end

RegisterNUICallback('painel', function(body, cb)
    if type(body) ~= 'table' or not PERMITIDAS[body.fn] then return cb({ erro = locale('pedido_invalido') }) end
    local a = type(body.args) == 'table' and body.args or {}
    cb(lib.callback.await('vel_guincho:painel:' .. body.fn, false, a[1], a[2]) or { erro = locale('sem_resposta') })
end)

-- Cadastrar o caminhão em que o admin está
RegisterNUICallback('painelNovo', function(_, cb)
    if not cache.vehicle then return cb({ erro = locale('entre_caminhao_novo') }) end
    local modelo = GetEntityArchetypeName(cache.vehicle)
    cb(lib.callback.await('vel_guincho:painel:novo', false, modelo, GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(cache.vehicle)))))
end)

local function fechar() pcall(function() exports.mri_Qadmin:ClosePlugin() end) end
local function reabrir() pcall(function() exports.mri_Qadmin:OpenPlugin(PLUGIN) end) end

local function noMundo(fn)
    if GuinchoPlacer.isActive() then return end
    fechar()
    CreateThread(function()
        Wait(300)
        local r = fn()
        if r then notificar(r.erro or r.msg, r.erro and 'error' or 'success') end
        Wait(200)
        reabrir()
    end)
end

-- Marcar um ponto ({ id, ponto }) no caminhão perto
RegisterNUICallback('painelMarcar', function(d, cb)
    cb(1)
    local c = type(d) == 'table' and cadastroPorId(tonumber(d.id))
    local regra = c and PONTOS[d.ponto]
    if not regra then return end
    local caminhao = caminhaoPerto(c.modelo)
    if not caminhao then return notificar(locale('fique_perto', c.nome), 'error') end
    noMundo(function()
        local inclinada = regra.inclinada and c.plataforma ~= 'fixa'
        local maximo = c.pontos.inclinacao or 1.0
        -- ponto na plataforma que inclina: fica preso à peça que se move com ela
        local osso, ossoIndice, ancora
        if regra.naPlataforma and c.plataforma ~= 'fixa' then
            osso = c.pontos.osso or Plataforma.detectarOsso(caminhao, c.plataforma, maximo)
            ossoIndice = Plataforma.osso(caminhao, osso)
            if not ossoIndice then return { erro = locale('sem_osso') } end
            ancora = Plataforma.ancora(caminhao, ossoIndice)
        end
        local base = ancora or caminhao
        if inclinada then moverPlataforma(caminhao, c.plataforma, 0.0, maximo) end
        local dado
        if regra.ferramenta == 'carro' then
            -- ajusta preso ao caminhão (x,y,z,h); com âncora devolve também relativo à peça (b)
            dado = GuinchoPlacer.onTruck({ vehicle = CARRO_PREVIA, truck = caminhao, anchor = ancora, start = c.pontos.carga })
        else
            local r = regra.ferramenta == 'aqui' and GuinchoPlacer.here() or GuinchoPlacer.point({})
            dado = r and relativo(base, r.coords, r.heading)
        end
        if inclinada then moverPlataforma(caminhao, c.plataforma, maximo, 0.0) end
        if ancora then DeleteEntity(ancora) end
        if not dado then return nil end
        dado.osso = osso
        return lib.callback.await('vel_guincho:painel:ponto', false, c.id, d.ponto, dado)
    end)
end)

-- Prévia da inclinação ({ id, pos 0–1 }): move a plataforma do caminhão perto até 'pos'
local previa = {}
RegisterNUICallback('painelInclinar', function(d, cb)
    cb(1)
    local c = type(d) == 'table' and cadastroPorId(tonumber(d.id))
    if not c or c.plataforma == 'fixa' then return end
    local caminhao = caminhaoPerto(c.modelo)
    if not caminhao then return notificar(locale('fique_perto', c.nome), 'error') end
    local pos = math.max(0.0, math.min(1.0, tonumber(d.pos) or 0.0))
    local de = previa[caminhao] or 0.0
    previa[caminhao] = pos
    CreateThread(function() moverPlataforma(caminhao, c.plataforma, de, pos) end)
end)

-- Ver os pontos marcados por 15 s no caminhão perto ({ id })
RegisterNUICallback('painelVer', function(d, cb)
    cb(1)
    local c = type(d) == 'table' and cadastroPorId(tonumber(d.id))
    if not c then return end
    local caminhao = caminhaoPerto(c.modelo)
    if not caminhao then return notificar(locale('fique_perto', c.nome), 'error') end
    fechar()
    notificar(locale('vendo_pontos'), 'inform')
    CreateThread(function()
        local fantasma
        local ancoras = {}
        local carga = c.pontos.carga
        if carga and pcall(lib.requestModel, joaat(CARRO_PREVIA), 5000) then
            fantasma = CreateVehicle(joaat(CARRO_PREVIA), GetEntityCoords(caminhao), 0.0, false, false)
            SetModelAsNoLongerNeeded(joaat(CARRO_PREVIA))
            SetEntityAlpha(fantasma, 170, false)
            SetEntityCollision(fantasma, false, false)
            local osso = carga.b and Plataforma.osso(caminhao, carga.osso)
            if osso then
                local b = carga.b
                AttachEntityToEntity(fantasma, caminhao, osso, b.x, b.y, b.z, b.rx, b.ry, b.rz, false, false, false, false, 2, true)
            else
                AttachEntityToEntity(fantasma, caminhao, 0, carga.x, carga.y, carga.z, 0.0, 0.0, carga.h or 0.0, false, false, false, false, 2, true)
            end
        end
        local fim = GetGameTimer() + 15000
        while GetGameTimer() < fim and DoesEntityExist(caminhao) do
            for nome, p in pairs(c.pontos) do
                if type(p) == 'table' and p.x and nome ~= 'carga' then
                    local w = noMundoDe(caminhao, p, ancoras)
                    DrawMarker(28, w.x, w.y, w.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.15, 0.15, 0, 230, 153, 200, false, false, 2, false, nil, nil, false)
                    local ok, sx, sy = World3dToScreen2d(w.x, w.y, w.z + 0.3)
                    if ok then
                        SetTextScale(0.35, 0.35); SetTextFont(4); SetTextColour(255, 255, 255, 230); SetTextOutline(); SetTextCentre(true)
                        BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(locale('ponto_' .. nome)); EndTextCommandDisplayText(sx, sy)
                    end
                end
            end
            Wait(0)
        end
        if fantasma then DeleteEntity(fantasma) end
        apagarAncoras(ancoras)
        reabrir()
    end)
end)

RegisterNUICallback('painelFechar', function(_, cb)
    cb(1)
    fechar()
end)
