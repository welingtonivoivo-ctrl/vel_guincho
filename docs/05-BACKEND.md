# 05 — Backend (dados, servidor, segurança)

## Banco (só tabelas novas, criadas pelo próprio resource ao iniciar)

```sql
CREATE TABLE IF NOT EXISTS vel_guincho_caminhoes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  modelo VARCHAR(64) NOT NULL UNIQUE,        -- spawn name
  nome VARCHAR(64) NOT NULL,
  tipo ENUM('plataforma','gancho') NOT NULL,
  plataforma ENUM('fixa','garfo','braco') NULL,
  empregos JSON NOT NULL,                    -- ["pmesp","guincho_sp"]
  exige_servico TINYINT(1) NOT NULL DEFAULT 1,
  cabo VARCHAR(8) NOT NULL DEFAULT 'medio',  -- curto|medio|longo
  pontos JSON NOT NULL,                      -- {motor,caixa,carga,rampa,engate}: offsets x,y,z,h
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  atualizado TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS vel_guincho_patios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(64) NOT NULL,
  zona JSON NOT NULL                         -- centro, heading, largura, comprimento, altura
);
CREATE TABLE IF NOT EXISTS vel_guincho_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  quando TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  citizenid VARCHAR(64), emprego VARCHAR(64),
  acao VARCHAR(24),                          -- engatou|carregou|descarregou|rebocou|desvirou|entregou
  placa VARCHAR(16), modelo_caminhao VARCHAR(64), patio_id INT NULL
);
```

Os 6 modelos entram como **semente**, só se a tabela estiver vazia. Os pontos ficam vazios até serem marcados na Etapa 2.

## Estado de jogo (statebag no caminhão)

`Entity(caminhao).state.velGuincho = { fase, cabo = {comp, alvo=netId|nil, mao=serverId|nil, ponto='frente'|'tras'}, carga = netId|nil, plataforma = 0.0–1.0, reboque = netId|nil }`

Só o servidor escreve (`SetStateBag... replicated`). Os clientes desenham o cabo, o ângulo da plataforma e o carro preso.

## Callbacks do servidor (`lib.callback.register`)

| Nome | Faz | Confere |
| --- | --- | --- |
| `vel_guincho:pegarCabo` | põe o cabo na mão | emprego, serviço, ≤3 m do motor, cabo livre |
| `vel_guincho:engatar` | prende o cabo no carro | quem tem o cabo, carro vazio, ≤ comprimento, ≤2,5 m do carro, carro não preso em outro |
| `vel_guincho:comando` | puxar, soltar, inclinar, recolher, recolher cabo | ≤3 m da caixa, fase válida (máquina de estados) |
| `vel_guincho:reboque` | engate ou solta do gancho | motorista do caminhão, ≤2 m, carro vazio |
| `vel_guincho:desvirar` | início e fim do giro | motorista, cabo engatado em carro tombado |
| `vel_guincho:soltarCabo` | tira o cabo do carro | perto do carro |

A cada passo o servidor valida a **fase** (máquina de estados: livre → cabo_na_mao → engatado → subindo → carregado → descendo...). Pedido fora de ordem é recusado.

## Pátio

Quando o carro é solto e o centro dele está dentro de uma zona de pátio:
- o servidor grava no log;
- marca o carro com `Entity(carro).state.velGuinchoPatio = { patio, por, quando }`;
- avisa os policiais em serviço (notify);
- dispara o evento `vel_guincho:server:entregue (source, placa, patioId)`, para outros scripts usarem.

## Painel (plugin mri_Qadmin)

- Permissão `vel_guincho.admin` (ACE), declarada no `RegisterPlugin`.
- Callbacks: `painel:listar`, `salvar`, `remover`, `marcarPonto`, `salvarPatio`, `removerPatio`, `irAte`, `testarPlataforma`. Todos conferem a ACE.
- Depois de salvar, publica `GlobalState.velGuincho`.

## Segurança

- **O cliente nunca decide** emprego, distância, vazio, fase ou pátio. Tudo isso é conferido no servidor.
- Limite de pedidos por jogador (um a cada 300 ms), contra spam.
- Se o operador sair do jogo ou morrer, o cabo volta para o motor, e o carro carregado continua preso ao caminhão.
- Se o caminhão for deletado, o carro preso é solto no chão ao lado.
- Nada é escrito no banco pelo cliente, e não há SQL com texto do cliente (só parâmetros).
