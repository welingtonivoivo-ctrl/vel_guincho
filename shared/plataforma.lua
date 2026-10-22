-- Mecanismos que movem a plataforma de um caminhão (0.0 = recolhida, 1.0 = inclinada até o chão).
-- Cada modelo usa um: o criador do modelo ligou a plataforma ao garfo de empilhadeira, ao braço
-- do reboque ou ao braço de escavadeira. 'fixa' = plataforma que não se move (rampa virtual).

Plataforma = {}

Plataforma.mecanismos = { 'fixa', 'garfo', 'braco', 'escavadeira' }

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
