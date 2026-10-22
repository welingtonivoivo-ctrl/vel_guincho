-- Publica a configuração para os clientes e o comando de teste das plataformas (Etapa 1).

Guincho = {}

function Guincho.publicar()
    GlobalState.velGuincho = { caminhoes = Banco.caminhoes(), patios = Banco.patios() }
end

function Guincho.admin(source)
    return source == 0 or IsPlayerAceAllowed(source, Config.AcePainel) or IsPlayerAceAllowed(source, 'command')
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
