# 02 — TRD (como, tecnicamente)

## Base confirmada (22/10/2026)

| Item | Fonte | Situação |
| --- | --- | --- |
| QBox + ox_lib + oxmysql | base | confirmado |
| Painel: plugin do `mri_Qadmin` (`RegisterPlugin`, handshake `mri-plugin/ready`) | padrão já usado no `vel_balcao` / `street_personagens` | confirmado |
| Interação: `exports.mri_Qinteract:addCoords/removeCoords` (pontos no caminhão) e `addLocalEntity` | memória do projeto (ox_target nunca fica started) | confirmado |
| Marcação com prévia: `WorldPlacer.point` / `WorldPlacer.zone` + `PlaceRail` | skill `mri-world-placement` | confirmado |
| Pátio: `mri_Qgarage` apreende só pela opção dele no carro (função local `impoundVehicle`, callbacks `policeImpound.lookup/impoundveh`, autorização por emprego no servidor). **Não há export para apreender.** | `modules/impound/*.lua` | confirmado: a v1 só entrega; pedido de export vai para a MRI |
| Empregos: `pmesp`, `pcesp`, `gcm`, `prf`, `police` (PF), `bombeiros`, `mecanica_centro`, `guincho_sp` | `mri_qjobsystem` (migração SP) | confirmado |
| Nenhum script de guincho/corda na base; os `NOISESTD-dutra_viaturas*` só alternam extras | análise dos `client.lua` | confirmado |

## Modelos pré-configurados

| Spawn | Dono padrão | Tipo | Plataforma | Evidência |
| --- | --- | --- | --- | --- |
| `volvocbmesp` | bombeiros, guincho_sp | plataforma | inclina, mecanismo **garfo** | bones `forks`/`carriage`; nasce inclinada |
| `delivery11cmm` | pmesp, pcesp, gcm, prf, police, guincho_sp | plataforma | inclina, mecanismo **braço** | bone `towtruck_rear`; nasce inclinada |
| `deliverymec` | mecanica_centro, guincho_sp | plataforma | **fixa** (rampa virtual) | sem bones móveis |
| `flatbed` (GTA) | mecanica_centro, guincho_sp | plataforma | fixa | modelo original |
| `towtruck`, `towtruck2` (GTA) | mecanica_centro, guincho_sp | gancho | – | modelos originais |

Os pontos padrão dos modelos são marcados na Etapa 2, com a prévia, e ficam salvos no banco. Os empregos de cada um podem ser trocados no painel.

## Dependências a confirmar na Etapa 1 (teste em jogo)

1. `SetForkliftForkHeight(veh, 0.0–1.0)` move a plataforma do `volvocbmesp`.
2. `SetVehicleTowTruckArmPosition(veh, 0.0–1.0)` (ou `SetVehicleBulldozerArmPosition`) move a do `delivery11cmm`. Se nenhum mover, ele cai para "fixa" até achar o mecanismo.
3. Cordas (`RopeLoadTextures`, `AddRope`, `AttachEntitiesToRope`, `StartRopeWinding`) sincronizadas por statebag. Corda é local em cada cliente, então cada um desenha a sua a partir do mesmo estado.

Os nomes dos natives são conferidos com `mri-resource-check` (`natives.mjs`) antes do código.

## Arquitetura

- **Servidor manda.** Engatar, puxar, soltar e entregar são pedidos ao servidor (`lib.callback`). Ele confere:
  - emprego e serviço;
  - distância;
  - se o carro está vazio;
  - se o caminhão está cadastrado.
  O resultado vira **statebag** no caminhão (`Entity(caminhao).state.velGuincho`), e todos os clientes desenham a partir dele: cabo, carro preso, ângulo da plataforma.
- **Movimento do carro:** quem é dono de rede do carro anima o carro preso por `AttachEntityToEntity`, interpolando ao longo da rampa até a posição de carga. Não usa física solta, que derruba o carro. Preso: anexado na posição de carga, com colisão do carro desligada contra o caminhão.
- **Gancho (arrastar):** `AttachVehicleToTowTruck` nos modelos originais com braço; nos outros, anexo físico no ponto de engate.
- **Desvirar:** interpolação da rotação até ficar de pé, mais `SetVehicleOnGroundProperly`, disparada pelo operador na cabine com o cabo engatado.
- **Pontos salvos como deslocamento relativo ao caminhão** (`GetOffsetFromEntityGivenWorldCoords`), então valem para qualquer caminhão do mesmo modelo, em qualquer lugar.
- **Config compartilhada:** `GlobalState.velGuincho` (modelos e pátios), publicada pelo servidor ao iniciar e ao salvar no painel.
- **Textos:** `locales/pt-br.json` e `en.json` (padrão MRI), sem texto fixo no código.

## Decisões

| Decisão | Por quê |
| --- | --- |
| Pontos relativos ao modelo | Um cadastro serve para todas as unidades daquele caminhão |
| Anexo interpolado em vez de física | Física com carro em cima de veículo em movimento derruba e faz bugs; a interpolação é estável e sincroniza |
| Pátio só entrega na v1 | O `mri_Qgarage` não tem export; mexer nele quebra o upstream. Pedido de export para a MRI |
| Só carro vazio | Escolha do dono: evita abuso e bug |
| Plugin no mri_Qadmin | Padrão dos outros sistemas; sem comando solto |
