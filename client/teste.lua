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
    local osso = Plataforma.osso(veiculo, c.pontos.osso or 'forks') or Plataforma.osso(veiculo, 'forks')
    if not osso then return lib.notify({ description = locale('sem_osso'), type = 'error' }) end
    testando = true
    FreezeEntityPosition(veiculo, false)
    local motorista
    local function comMotorista()
        local m = `s_m_y_fireman_01`
        lib.requestModel(m, 5000)
        motorista = CreatePedInsideVehicle(veiculo, 4, m, -1, false, false)
        SetModelAsNoLongerNeeded(m)
        SetEntityVisible(motorista, false, false)
        SetBlockingOfNonTemporaryEvents(motorista, true)
    end
    local function semMotorista() if motorista and DoesEntityExist(motorista) then DeleteEntity(motorista) end motorista = nil end
    local linhas, n, melhor = {}, 0, nil
    for _, mec in ipairs({ 'garfo', 'braco', 'escavadeira' }) do
        for _, motor in ipairs({ false, true }) do
            n = n + 1
            lib.notify({ description = locale('diag_teste', n), type = 'inform' })
            local andou = medir(veiculo, mec, osso, motor and comMotorista or nil, motor and semMotorista or nil)
            linhas[#linhas + 1] = ('%s%s = %.2f m'):format(mec, motor and ' + motorista' or '', andou)
            print(('[vel_guincho] diagnóstico %s'):format(linhas[#linhas]))
            if andou > 0.3 and (not melhor or (not motor and melhor.motor)) then melhor = { mec = mec, motor = motor } end
        end
    end
    lib.notify({ description = locale('diag_resultado', table.concat(linhas, ' · ')), type = melhor and 'success' or 'error', duration = 20000 })
    testando = false
end)

-- Teste do desvirar (/guinchocapotar): vira de rodas para cima o veículo mais perto (fora do caminhão)
RegisterNetEvent('vel_guincho:client:capotar', function()
    local v = lib.getClosestVehicle(GetEntityCoords(cache.ped), 8.0, false)
    if not v then return lib.notify({ description = locale('capotar_nenhum'), type = 'error' }) end
    local limite = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(v) and GetGameTimer() < limite do
        NetworkRequestControlOfEntity(v)
        Wait(0)
    end
    local c = GetEntityCoords(v)
    SetEntityCoordsNoOffset(v, c.x, c.y, c.z + 1.5, false, false, false)
    SetEntityRotation(v, 0.0, 180.0, GetEntityHeading(v), 2, true)
    lib.notify({ description = locale('capotado'), type = 'success' })
end)
