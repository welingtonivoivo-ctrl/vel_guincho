-- Aba "Guincho" do mri_Qadmin: cadastro dos caminhões e dos pontos. Tudo conferido aqui.

local PONTOS = { motor = true, caixa = true, carga = true, rampa = true, engate = true }
local TIPOS = { plataforma = true, gancho = true }
local MECANISMOS = { fixa = true, garfo = true, braco = true, escavadeira = true, cabine = true }

local function quem(source)
    local p = exports.qbx_core:GetPlayer(source)
    return p and p.PlayerData and (p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname) or GetPlayerName(source)
end

local function numero(v, min, max)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return math.max(min, math.min(max, v + 0.0))
end

local function decodificar(texto)
    local ok, v = pcall(json.decode, texto or '')
    return ok and type(v) == 'table' and v or {}
end

local F = {}

function F.dados()
    local lista = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `vel_guincho_caminhoes` WHERE ativo = 1 ORDER BY nome') or {}) do
        lista[#lista + 1] = {
            id = r.id, modelo = r.modelo, nome = r.nome, tipo = r.tipo, plataforma = r.plataforma or 'fixa',
            empregos = decodificar(r.empregos), exigeServico = r.exige_servico == 1, cabo = r.cabo, pontos = decodificar(r.pontos),
        }
    end
    local empregos = {}
    for nome, j in pairs(exports.qbx_core:GetJobs() or {}) do
        empregos[#empregos + 1] = { nome = nome, rotulo = j.label or nome }
    end
    table.sort(empregos, function(a, b) return a.rotulo < b.rotulo end)
    return { caminhoes = lista, empregos = empregos, cabos = Config.Cabo }
end

function F.novo(source, modelo, rotulo)
    if type(modelo) ~= 'string' or not modelo:match('^[%w_]+$') or #modelo > 64 then return { erro = locale('modelo_invalido') } end
    if MySQL.scalar.await('SELECT id FROM `vel_guincho_caminhoes` WHERE modelo = ? AND ativo = 1', { modelo }) then
        return { erro = locale('ja_cadastrado') }
    end
    local nome = (type(rotulo) == 'string' and rotulo ~= '' and rotulo ~= 'NULL') and rotulo:sub(1, 64) or modelo
    -- um cadastro removido antes volta a valer (nunca apaga de verdade)
    local antigo = MySQL.scalar.await('SELECT id FROM `vel_guincho_caminhoes` WHERE modelo = ?', { modelo })
    if antigo then
        MySQL.update.await('UPDATE `vel_guincho_caminhoes` SET ativo = 1, atualizado_por = ? WHERE id = ?', { quem(source), antigo })
    else
        MySQL.insert.await('INSERT INTO `vel_guincho_caminhoes` (modelo, nome, tipo, plataforma, empregos, cabo, pontos, atualizado_por) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { modelo, nome, 'plataforma', 'fixa', '[]', Config.CaboPadrao, '{}', quem(source) })
    end
    Guincho.publicar()
    return { msg = locale('cadastrado', nome) }
end

function F.salvar(source, id, c)
    id = tonumber(id)
    if not id or type(c) ~= 'table' then return { erro = locale('pedido_invalido') } end
    local nome = type(c.nome) == 'string' and c.nome:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 64) or ''
    if nome == '' or not TIPOS[c.tipo] or not MECANISMOS[c.plataforma or 'fixa'] or not Config.Cabo[c.cabo] then
        return { erro = locale('pedido_invalido') }
    end
    local empregos = {}
    for _, e in ipairs(type(c.empregos) == 'table' and c.empregos or {}) do
        if type(e) == 'string' and e:match('^[%w_]+$') and #empregos < 30 then empregos[#empregos + 1] = e end
    end
    local pontos = decodificar(MySQL.scalar.await('SELECT pontos FROM `vel_guincho_caminhoes` WHERE id = ?', { id }))
    pontos.inclinacao = numero(c.inclinacao, 0.05, 1.0) or pontos.inclinacao or 1.0
    MySQL.update.await('UPDATE `vel_guincho_caminhoes` SET nome = ?, tipo = ?, plataforma = ?, empregos = ?, exige_servico = ?, cabo = ?, pontos = ?, atualizado_por = ? WHERE id = ?', {
        nome, c.tipo, c.tipo == 'plataforma' and (c.plataforma or 'fixa') or nil, json.encode(empregos), c.exigeServico == false and 0 or 1,
        c.cabo, json.encode(pontos), quem(source), id,
    })
    Guincho.publicar()
    return { msg = locale('salvo') }
end

function F.ponto(source, id, nome, d)
    id = tonumber(id)
    if not id or not PONTOS[nome] or type(d) ~= 'table' then return { erro = locale('pedido_invalido') } end
    -- relativo ao caminhão: um caminhão não passa de ~20 m
    local p = { x = numero(d.x, -20, 20), y = numero(d.y, -20, 20), z = numero(d.z, -10, 10) }
    if not (p.x and p.y and p.z) then return { erro = locale('pedido_invalido') } end
    if nome ~= 'carga' and math.abs(p.x) + math.abs(p.y) + math.abs(p.z) < 0.05 then return { erro = locale('ponto_vazio') } end
    if d.h then p.h = numero(d.h, 0, 360) end
    if type(d.osso) == 'string' and d.osso:match('^[%w_]+$') and #d.osso <= 32 then p.osso = d.osso end
    -- posição relativa à peça da plataforma (a origem da peça pode ficar alguns metros longe)
    if p.osso and type(d.b) == 'table' and type(d.b.f) == 'table' and type(d.b.t) == 'table' then
        local function v(q) return { x = numero(q.x, -30, 30), y = numero(q.y, -30, 30), z = numero(q.z, -30, 30) } end
        local f, t = v(d.b.f), v(d.b.t)
        if f.x and f.y and f.z and t.x and t.y and t.z then p.b = { f = f, t = t } end
    end
    local pontos = decodificar(MySQL.scalar.await('SELECT pontos FROM `vel_guincho_caminhoes` WHERE id = ?', { id }))
    pontos[nome] = p
    if p.osso then pontos.osso = p.osso end
    MySQL.update.await('UPDATE `vel_guincho_caminhoes` SET pontos = ?, atualizado_por = ? WHERE id = ?', { json.encode(pontos), quem(source), id })
    Guincho.publicar()
    return { msg = locale('ponto_salvo', locale('ponto_' .. nome)) }
end

function F.remover(source, id)
    id = tonumber(id)
    if not id then return { erro = locale('pedido_invalido') } end
    MySQL.update.await('UPDATE `vel_guincho_caminhoes` SET ativo = 0, atualizado_por = ? WHERE id = ?', { quem(source), id })
    Guincho.publicar()
    return { msg = locale('removido') }
end

for fn, f in pairs(F) do
    lib.callback.register('vel_guincho:painel:' .. fn, function(source, ...)
        if not Guincho.admin(source) then return { erro = locale('sem_permissao') } end
        return f(source, ...)
    end)
end

-- Registro no mri_Qadmin ---------------------------------------------------

local function registrar()
    if GetResourceState('mri_Qadmin') ~= 'started' then return end
    local def = { id = Config.AcePainel, label = locale('perm_label'), desc = locale('perm_desc') }
    pcall(function() exports.mri_Qadmin:RegisterPermissions({ def }, { id = 'vel_guincho', label = locale('painel_titulo') }) end)
    local ok, err = pcall(function()
        exports.mri_Qadmin:RegisterPlugin({
            id = 'vel_guincho', label = locale('painel_titulo'), icon = 'truck', resource = GetCurrentResourceName(),
            htmlPath = 'html/painel.html', requiredPerms = Config.AcesPainel, permDefs = { def }, description = def.desc,
        })
    end)
    print(ok and '^5[vel_guincho]^7 aba Guincho registrada no mri_Qadmin' or ('^1[vel_guincho] painel: %s^7'):format(err))
end

CreateThread(function() Wait(1500) registrar() end)
AddEventHandler('onResourceStart', function(res) if res == 'mri_Qadmin' then SetTimeout(3000, registrar) end end)
