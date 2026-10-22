-- Publica a configuração para os clientes e o comando de teste das plataformas (Etapa 1).

Guincho = {}

function Guincho.publicar()
    GlobalState.velGuincho = { caminhoes = Banco.caminhoes(), patios = Banco.patios() }
end

function Guincho.admin(source)
    if source == 0 then return true end
    for _, ace in ipairs(Config.AcesPainel) do
        if IsPlayerAceAllowed(source, ace) then return true end
    end
    return false
end

CreateThread(function()
    Banco.preparar()
    Guincho.publicar()
end)

-- /guinchoteste [mecanismo]: move a plataforma do caminhão em que o admin está (desce e sobe).
-- Sem mecanismo, usa o do cadastro. Serve para descobrir qual mecanismo cada modelo usa.
lib.addCommand('guinchoteste', {
    help = locale('cmd_teste'),
    params = {
        { name = 'mecanismo', type = 'string', help = 'fixa | garfo | braco | escavadeira', optional = true },
        { name = 'maximo', type = 'number', help = '5 a 100 (% da inclinação)', optional = true },
    },
}, function(source, args)
    if not Guincho.admin(source) then return end
    local m = args.mecanismo
    if m and not lib.table.contains(Plataforma.mecanismos, m) then
        return lib.notify(source, { description = locale('mecanismo_invalido'), type = 'error' })
    end
    TriggerClientEvent('vel_guincho:client:testarPlataforma', source, m, args.maximo and args.maximo / 100)
end)

-- /guinchodiag: diagnóstico da plataforma com o admin fora do caminhão
lib.addCommand('guinchodiag', { help = 'Diagnóstico da plataforma (fique fora do caminhão)' }, function(source)
    if not Guincho.admin(source) then return end
    TriggerClientEvent('vel_guincho:client:diag', source)
end)

-- Registro de ações (vel_guincho_log)
function Guincho.log(source, acao, carro, c, patioId)
    local p = exports.qbx_core:GetPlayer(source)
    local pd = p and p.PlayerData
    MySQL.insert('INSERT INTO `vel_guincho_log` (citizenid, emprego, acao, placa, modelo_caminhao, patio_id) VALUES (?, ?, ?, ?, ?, ?)', {
        pd and pd.citizenid, pd and pd.job and pd.job.name, acao, carro and GetVehicleNumberPlateText(carro) or nil, c and c.modelo, patioId,
    })
end

-- /guinchocapotar: vira o veículo mais perto (para testar o desvirar)
lib.addCommand('guinchocapotar', { help = 'Vira de rodas para cima o veículo mais perto (teste do guincho)' }, function(source)
    if not Guincho.admin(source) then return end
    TriggerClientEvent('vel_guincho:client:capotar', source)
end)
