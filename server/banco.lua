-- Tabelas próprias (criadas na primeira partida; nunca alteram tabelas existentes) e semente dos caminhões.

Banco = {}

local TABELAS = {
    [[CREATE TABLE IF NOT EXISTS `vel_guincho_caminhoes` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `modelo` VARCHAR(64) NOT NULL,
        `nome` VARCHAR(64) NOT NULL,
        `tipo` VARCHAR(12) NOT NULL,
        `plataforma` VARCHAR(12) NULL,
        `empregos` LONGTEXT NOT NULL,
        `exige_servico` TINYINT(1) NOT NULL DEFAULT 1,
        `cabo` VARCHAR(8) NOT NULL DEFAULT 'medio',
        `pontos` LONGTEXT NOT NULL,
        `ativo` TINYINT(1) NOT NULL DEFAULT 1,
        `atualizado_por` VARCHAR(60) NULL,
        `atualizado_em` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`), UNIQUE KEY `uk_vg_modelo` (`modelo`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `vel_guincho_patios` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `nome` VARCHAR(64) NOT NULL,
        `zona` LONGTEXT NOT NULL,
        `criado_por` VARCHAR(60) NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `vel_guincho_lojas` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `nome` VARCHAR(64) NOT NULL,
        `coords` LONGTEXT NOT NULL,
        `ativo` TINYINT(1) NOT NULL DEFAULT 1,
        `criado_por` VARCHAR(60) NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `vel_guincho_config` (
        `chave` VARCHAR(40) NOT NULL,
        `valor` LONGTEXT NOT NULL,
        `atualizado_por` VARCHAR(60) NULL,
        `atualizado_em` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`chave`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `vel_guincho_log` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `quando` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `citizenid` VARCHAR(64) NULL,
        `emprego` VARCHAR(64) NULL,
        `acao` VARCHAR(24) NOT NULL,
        `placa` VARCHAR(16) NULL,
        `modelo_caminhao` VARCHAR(64) NULL,
        `patio_id` INT UNSIGNED NULL,
        PRIMARY KEY (`id`), KEY `idx_vg_log_placa` (`placa`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function decodificar(texto, padrao)
    local ok, v = pcall(json.decode, texto or '')
    return ok and type(v) == 'table' and v or padrao
end

function Banco.preparar()
    for _, sql in ipairs(TABELAS) do MySQL.query.await(sql) end
    local total = MySQL.scalar.await('SELECT COUNT(*) FROM `vel_guincho_caminhoes`') or 0
    if total > 0 then return end
    for _, c in ipairs(Config.Semente) do
        MySQL.insert.await('INSERT INTO `vel_guincho_caminhoes` (modelo, nome, tipo, plataforma, empregos, cabo, pontos, atualizado_por) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            c.modelo, c.nome, c.tipo, c.plataforma, json.encode(c.empregos), Config.CaboPadrao, '{}', 'semente',
        })
    end
    print(('[vel_guincho] %d caminhões pré-configurados cadastrados.'):format(#Config.Semente))
end

---Caminhões ativos, indexados pelo hash do modelo (o cliente compara com GetEntityModel).
function Banco.caminhoes()
    local lista = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `vel_guincho_caminhoes` WHERE ativo = 1') or {}) do
        lista[tostring(joaat(r.modelo))] = {
            id = r.id, modelo = r.modelo, nome = r.nome, tipo = r.tipo, plataforma = r.plataforma or 'fixa',
            empregos = decodificar(r.empregos, {}), exigeServico = r.exige_servico == 1,
            cabo = Config.Cabo[r.cabo] and r.cabo or Config.CaboPadrao, pontos = decodificar(r.pontos, {}),
        }
    end
    return lista
end

---Guincho portátil: entra na lista como um "caminhão" (pelo modelo do motor) para o cabo e o
---desvirar funcionarem igual. Qualquer um usa; o ponto do motor é calculado pelo modelo no cliente.
function Banco.portatil()
    local P = Config.Portatil
    return {
        id = 0, modelo = P.modelo, nome = 'Guincho portátil', tipo = 'portatil', livre = true,
        empregos = {}, exigeServico = false, cabo = P.cabo, pontos = {},
    }
end

---Balcões da loja do guincho portátil (marcados no painel).
-- Ajustes do guincho portátil que o painel muda (o resto do Config.Portatil fica no arquivo)
Banco.AJUSTAVEIS = { 'usos', 'preco', 'alcance', 'cabo', 'quedaKmh', 'arrasto', 'empregosLoja' }

---Lê os ajustes salvos e aplica no Config.Portatil (servidor). Devolve só os ajustáveis.
function Banco.ajustes()
    local r = MySQL.scalar.await("SELECT valor FROM `vel_guincho_config` WHERE chave = 'portatil'")
    local salvo = decodificar(r, {})
    local P = Config.Portatil
    local atual = {}
    for _, k in ipairs(Banco.AJUSTAVEIS) do
        if salvo[k] ~= nil then P[k] = salvo[k] end
        atual[k] = P[k]
    end
    return atual
end

function Banco.salvarAjustes(valores, quem)
    MySQL.query.await("INSERT INTO `vel_guincho_config` (chave, valor, atualizado_por) VALUES ('portatil', ?, ?) ON DUPLICATE KEY UPDATE valor = VALUES(valor), atualizado_por = VALUES(atualizado_por)",
        { json.encode(valores), quem })
end

function Banco.lojas()
    local lista = {}
    for _, r in ipairs(MySQL.query.await('SELECT id, nome, coords FROM `vel_guincho_lojas` WHERE ativo = 1') or {}) do
        local c = decodificar(r.coords, nil)
        if c and c.x then lista[#lista + 1] = { id = r.id, nome = r.nome, coords = c } end
    end
    return lista
end

function Banco.patios()
    local lista = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `vel_guincho_patios`') or {}) do
        lista[#lista + 1] = { id = r.id, nome = r.nome, zona = decodificar(r.zona, {}) }
    end
    return lista
end
