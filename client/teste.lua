-- Etapa 1: teste da plataforma no caminhão em que o admin está (desce até o chão e volta).

local testando = false

local function cadastro(veiculo)
    local estado = GlobalState.velGuincho
    return estado and estado.caminhoes and estado.caminhoes[tostring(GetEntityModel(veiculo))]
end

---Leva a plataforma de 'de' até 'ate' em Config.TempoPlataforma.
local function animar(veiculo, mecanismo, de, ate)
    local inicio = GetGameTimer()
    while true do
        local t = math.min(1.0, (GetGameTimer() - inicio) / Config.TempoPlataforma)
        Plataforma.mover(veiculo, mecanismo, de + (ate - de) * t)
        if t >= 1.0 then break end
        Wait(0)
    end
end

RegisterNetEvent('vel_guincho:client:testarPlataforma', function(mecanismo, maximo)
    if testando then return end
    local veiculo = cache.vehicle
    if not veiculo then return lib.notify({ description = locale('entre_caminhao'), type = 'error' }) end
    local c = cadastro(veiculo)
    mecanismo = mecanismo or (c and c.plataforma) or 'fixa'
    if mecanismo == 'fixa' then
        return lib.notify({ description = locale('plataforma_fixa', c and c.nome or GetDisplayNameFromVehicleModel(GetEntityModel(veiculo))), type = 'inform' })
    end
    maximo = tonumber(maximo) or (c and c.pontos and c.pontos.inclinacao) or 1.0
    maximo = math.max(0.05, math.min(1.0, maximo))
    testando = true
    lib.notify({ description = locale('testando', mecanismo, math.floor(maximo * 100)), type = 'inform' })
    -- caminhão parado (freio + sapatas): a plataforma empurrando o chão não arrasta nem lança o caminhão
    if Plataforma.travar(mecanismo) then FreezeEntityPosition(veiculo, true) end
    animar(veiculo, mecanismo, 0.0, maximo)
    Wait(1500)
    animar(veiculo, mecanismo, maximo, 0.0)
    if Plataforma.travar(mecanismo) then FreezeEntityPosition(veiculo, false) end
    testando = false
    lib.notify({ description = locale('teste_fim', mecanismo), type = 'success' })
end)

-- Diagnóstico (/guinchodiag): de FORA do caminhão, testa jeitos de a plataforma obedecer sem ninguém
-- dirigindo e mede quanto a peça da plataforma andou em cada um.
local function caminhaoMaisPerto()
    local v = lib.getClosestVehicle(GetEntityCoords(cache.ped), 15.0, true)
    return v and cadastro(v) and v, v and cadastro(v)
end

local function medir(veiculo, mecanismo, osso, preparo, limpeza)
    local antes = GetWorldPositionOfEntityBone(veiculo, osso)
    if preparo then preparo() end
    local inicio = GetGameTimer()
    while GetGameTimer() - inicio < 2500 do
        Plataforma.mover(veiculo, mecanismo, math.min(0.8, (GetGameTimer() - inicio) / 1500))
        Wait(0)
    end
    local andou = #(GetWorldPositionOfEntityBone(veiculo, osso) - antes)
    inicio = GetGameTimer()
    while GetGameTimer() - inicio < 2500 do
        Plataforma.mover(veiculo, mecanismo, math.max(0.0, 0.8 - (GetGameTimer() - inicio) / 1500))
        Wait(0)
    end
    if limpeza then limpeza() end
    Wait(500)
    return andou
end

RegisterNetEvent('vel_guincho:client:diag', function()
    if testando then return end
    if cache.vehicle then return lib.notify({ description = locale('diag_fora'), type = 'error' }) end
    local veiculo, c = caminhaoMaisPerto()
    if not veiculo or c.plataforma == 'fixa' then return lib.notify({ description = locale('diag_sem'), type = 'error' }) end
    local osso = Plataforma.osso(veiculo, c.pontos.osso or Plataforma.detectarOsso(veiculo, c.plataforma, 1.0) or '')
    if not osso then return lib.notify({ description = locale('sem_osso'), type = 'error' }) end
    testando = true
    FreezeEntityPosition(veiculo, false)
    local r = {}
    lib.notify({ description = locale('diag_teste', 1), type = 'inform' })
    r[1] = medir(veiculo, c.plataforma, osso)
    lib.notify({ description = locale('diag_teste', 2), type = 'inform' })
    r[2] = medir(veiculo, c.plataforma, osso, function() SetVehicleEngineOn(veiculo, true, true, false) end,
        function() SetVehicleEngineOn(veiculo, false, true, false) end)
    lib.notify({ description = locale('diag_teste', 3), type = 'inform' })
    local motorista
    r[3] = medir(veiculo, c.plataforma, osso, function()
        local m = `s_m_y_fireman_01`
        lib.requestModel(m, 5000)
        motorista = CreatePedInsideVehicle(veiculo, 4, m, -1, false, false)
        SetModelAsNoLongerNeeded(m)
        SetEntityVisible(motorista, false, false)
        SetBlockingOfNonTemporaryEvents(motorista, true)
    end, function() if motorista and DoesEntityExist(motorista) then DeleteEntity(motorista) end end)
    for i = 1, 3 do print(('[vel_guincho] diagnóstico %d: a plataforma andou %.2f m'):format(i, r[i])) end
    lib.notify({ description = locale('diag_resultado', r[1], r[2], r[3]), type = 'success', duration = 15000 })
    testando = false
end)
