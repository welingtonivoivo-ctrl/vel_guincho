-- Mecanismos que movem a plataforma de um caminhão (0.0 = recolhida, 1.0 = inclinada até o chão).
-- Cada modelo usa um: o criador do modelo ligou a plataforma ao garfo de empilhadeira, ao braço
-- do reboque ou ao braço de escavadeira. 'fixa' = plataforma que não se move (rampa virtual).
-- Pontos que ficam NA plataforma (motor do guincho, posição de carga) são salvos presos à peça
-- (osso) que se move com ela, para acompanharem a inclinação.

Plataforma = {}

Plataforma.mecanismos = { 'fixa', 'garfo', 'braco', 'escavadeira' }

-- Peças que costumam ser a plataforma nos modelos de guincho
local CANDIDATOS = {
    'forks', 'carriage', 'mast', 'arm', 'towtruck_rear', 'misc_a', 'misc_b', 'misc_c', 'misc_d', 'misc_e',
    'misc_f', 'misc_g', 'misc_h', 'misc_i', 'misc_j', 'misc_w', 'misc_x', 'misc_y', 'misc_z', 'misc_base', 'misc_modulos',
}

---Põe a plataforma na posição pedida. Só no cliente, no veículo que ele enxerga.
---@param veiculo number
---@param mecanismo string
---@param pos number 0.0 a 1.0
function Plataforma.mover(veiculo, mecanismo, pos)
    if mecanismo == 'garfo' then
        SetForkliftForkHeight(veiculo, pos)
    elseif mecanismo == 'braco' then
        SetVehicleTowTruckArmPosition(veiculo, pos)
    elseif mecanismo == 'escavadeira' then
        SetVehicleBulldozerArmPosition(veiculo, pos, true)
    end
end

---Índice do osso (ou nil se o modelo não tem).
function Plataforma.osso(veiculo, nome)
    if type(nome) ~= 'string' then return nil end
    local i = GetEntityBoneIndexByName(veiculo, nome)
    return i ~= -1 and i or nil
end

---Descobre qual peça se move com a plataforma: inclina um pouco, vê qual osso andou mais e volta.
---@return string|nil nome do osso
function Plataforma.detectarOsso(veiculo, mecanismo, maximo)
    if mecanismo == 'fixa' then return nil end
    local antes = {}
    for _, nome in ipairs(CANDIDATOS) do
        local i = Plataforma.osso(veiculo, nome)
        if i then antes[nome] = { i = i, p = GetWorldPositionOfEntityBone(veiculo, i) } end
    end
    if not next(antes) then return nil end
    FreezeEntityPosition(veiculo, true)
    local alvo = math.max(0.3, (maximo or 1.0) * 0.6)
    local inicio = GetGameTimer()
    while GetGameTimer() - inicio < 1500 do
        Plataforma.mover(veiculo, mecanismo, alvo * (GetGameTimer() - inicio) / 1500)
        Wait(0)
    end
    Wait(200)
    local melhor, distancia = nil, 0.15
    for nome, b in pairs(antes) do
        local d = #(GetWorldPositionOfEntityBone(veiculo, b.i) - b.p)
        if d > distancia then melhor, distancia = nome, d end
    end
    inicio = GetGameTimer()
    while GetGameTimer() - inicio < 1500 do
        Plataforma.mover(veiculo, mecanismo, alvo * (1.0 - (GetGameTimer() - inicio) / 1500))
        Wait(0)
    end
    Plataforma.mover(veiculo, mecanismo, 0.0)
    FreezeEntityPosition(veiculo, false)
    return melhor
end

---Objeto invisível preso ao osso, para converter posições do mundo <-> relativas à plataforma.
---Quem chama apaga com DeleteEntity.
function Plataforma.ancora(veiculo, ossoIndice)
    local modelo = `prop_golf_ball`
    lib.requestModel(modelo, 5000)
    local c = GetEntityCoords(veiculo)
    local obj = CreateObjectNoOffset(modelo, c.x, c.y, c.z, false, false, false)
    SetModelAsNoLongerNeeded(modelo)
    SetEntityVisible(obj, false, false)
    SetEntityCollision(obj, false, false)
    AttachEntityToEntity(obj, veiculo, ossoIndice, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    return obj
end
