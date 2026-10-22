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
    maximo = tonumber(maximo) or (c and c.inclinacaoMax) or 1.0
    maximo = math.max(0.05, math.min(1.0, maximo))
    testando = true
    lib.notify({ description = locale('testando', mecanismo, math.floor(maximo * 100)), type = 'inform' })
    -- caminhão parado (freio + sapatas): a plataforma empurrando o chão não arrasta nem lança o caminhão
    FreezeEntityPosition(veiculo, true)
    animar(veiculo, mecanismo, 0.0, maximo)
    Wait(1500)
    animar(veiculo, mecanismo, maximo, 0.0)
    FreezeEntityPosition(veiculo, false)
    testando = false
    lib.notify({ description = locale('teste_fim', mecanismo), type = 'success' })
end)
