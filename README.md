# vel_guincho — Guincho imersivo para FiveM (QBox)

Sistema de guincho para servidores **FiveM / QBox**, configurado inteiro pelo painel admin, sem mexer em código. Funciona em qualquer caminhão cadastrado no painel.

## O que faz

- **Plataforma fixa ou que inclina** (mecanismos "garfo" e "braço"): o operador pega o cabo no motor, engata no carro, puxa pela caixa de comando, recolhe a plataforma e o carro fica preso na viagem.
- **Gancho (arrastar):** dá ré até encostar e o engate é automático.
- **Guincho frontal** para viaturas (bombeiros): arrasta e desvira pelo motor da frente.
- **Desvirar** carro capotado com o cabo.
- **Guincho portátil** (item): fixa numa árvore, poste ou parede e desvira um carro; desgaste de 10 usos, vendido só para mecânicos.
- **Cabo físico** sincronizado entre jogadores; o carro preso cai se o caminhão passar de 30 km/h.
- **Painel no mri_Qadmin**: caminhões, empregos que podem usar, limite de tamanho, pontos marcados no mundo com prévia em 3D (nenhuma coordenada digitada).

> **Situação (0.1.0):** etapas 1 a 7C feitas; pátio (etapa 8), polimento e o guincho de helicóptero ainda estão no plano. Veja `docs/06-PLANO.md`.

## Dependências

`ox_lib`, `oxmysql`, `qbx_core`, `mri_Qinteract`. Opcional: `mri_Qadmin` (painel e permissões).

## Instalação

1. Copie a pasta como **`vel_guincho`** para os seus resources.
2. Cole o item de `install/ox_inventory_item.lua` em `ox_inventory/data/items.lua` e copie `install/guincho_portatil.png` para `ox_inventory/web/images/`.
3. No `server.cfg`, depois das dependências: `ensure vel_guincho`. As tabelas do banco são criadas sozinhas.
4. Dê a permissão `vel_guincho.admin` para a staff (pelo mri_Qadmin ou `add_ace`).
5. Reinicie com a cidade vazia e cadastre os caminhões no painel.

## Documentação

`docs/01-PRD.md` (o que é), `02-TRD.md` (técnico), `03-FLUXO.md`, `04-DESIGN.md`, `05-BACKEND.md` (banco) e `06-PLANO.md` (etapas).

## Licença

GPL-3.0 — pode usar, modificar e redistribuir, desde que o código continue aberto com a mesma licença. Proibido vender como script fechado.
