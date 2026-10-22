# 01 — PRD (o que é e para quem)

**Resource:** `vel_guincho` · **Data:** 22/10/2026 · **Status:** aguardando aprovação do dono

## Problema

A cidade tem caminhões guincho nas organizações (polícia, bombeiros, mecânica), mas nenhum script de guincho. Os scripts que vêm com as viaturas só ligam extras (giroflex). Rebocar, levar para o pátio e desvirar carro hoje é improviso.

## Objetivo

Um guincho **imersivo**, configurado no painel admin, que funcione em **qualquer caminhão** marcado lá, sem mexer em código. Feito no padrão MRI (skills `mri-world-placement`, `mri-game-ux`, `mri-upstream-wrap`), porque o dono repassa os sistemas para a MRI.

## Quem usa

| Quem | O que faz |
| --- | --- |
| Operador (emprego liberado no caminhão, em serviço) | Guincha, reboca, desvira, entrega no pátio |
| Policial | Apreende o carro entregue no pátio (opção que já existe no `mri_Qgarage`) |
| Admin (painel) | Cadastra caminhões, marca os pontos com prévia, define quem usa, marca os pátios |

## Requisitos (v1 = Etapa 1 a 9)

1. **Caminhões configuráveis no painel**: cada modelo vira um caminhão guincho com tipo, empregos e pontos.
2. **Tipo plataforma, com plataforma fixa** (rampa virtual): o carro sobe puxado pelo cabo da traseira até a plataforma.
3. **Tipo plataforma, com plataforma que inclina**: o sistema controla a plataforma do modelo (mecanismo "garfo" ou "braço"). Desce, o cabo puxa o carro, sobe com o carro.
4. **Fluxo da plataforma igual à vida real:**
   1. o operador sobe até o motor do guincho, na frente da plataforma;
   2. pega o cabo, leva até o carro e engata (frente ou traseira);
   3. na caixa de comando, na lateral, aciona **puxar**, e o carro sobe;
   4. aciona **recolher plataforma**: o carro fica centralizado e preso;
   5. para descer, faz o mesmo na caixa de comando: inclinar, soltar cabo, o carro desce;
   6. no chão, solta o cabo do carro e recolhe o cabo na caixa de comando.
5. **Tipo gancho (arrastar):** o caminhão dá ré até encostar e o engate é automático. No destino, o operador solta o carro.
6. **Desvirar carro capotado (todos os tipos):** engata o cabo no carro tombado, entra na cabine e puxa; o carro desvira.
7. **Pátio:** áreas marcadas no painel. Soltar um carro dentro delas registra a entrega e avisa a polícia. Apreender continua com a opção do `mri_Qgarage`.
8. **Só carro vazio** pode ser guinchado. O carro preso não liga nem anda.
9. **Painel no mri_Qadmin** (aba "Guincho"): lista, mapa, editor, **prévia em 3D** para marcar pontos. Nenhuma coordenada digitada.
10. **Pré-configurados** os 6 modelos achados na base (ver TRD).

## Etapa 2 (depois da v1 aprovada em jogo)

11. **Guincho de helicóptero:** levanta um carro pendurado por cabo.
12. **Rapel:** policiais descem e sobem por corda de helicóptero, em pontos de descida marcados no painel.

## Fora do escopo

- Cobrança de guincho e taxa de pátio (o `mri_Qgarage` já cobra a multa).
- Chamado de guincho no celular (o dispatch já tem "Solicitação de Reboque").
- Criar ou alterar modelos 3D.

## Critério de pronto (v1)

Os 6 modelos guincham, rebocam e desviram em jogo, sincronizados entre dois jogadores, sem carro caindo da plataforma. A entrega no pátio aparece para a polícia, e tudo é configurável pelo painel.

## Adendo (22/10/2026, aprovado pelo dono)

13. **Guincho portátil (item `guincho_portatil`):** motor de guincho (modelo `prop_bison_winch`) que qualquer jogador com o item fixa numa árvore, poste ou objeto. Estica o cabo até um carro capotado e desvira, igual aos caminhões. Só desvira (não arrasta). Desgasta: 10 desviradas e quebra. Vendido pelas mecânicas.
14. **Caminhões de cambão** (arrastam o carro: `towtruck`, `towtruck2`) **não têm** o sistema de desvirar. O mecânico que usa cambão precisa do guincho portátil.
15. O desvirar rola o carro **na direção do cabo**.
16. **Aeronaves e tamanho máximo (22/10):** helicóptero e avião engatam pela fuselagem. Cada caminhão tem no painel um comprimento máximo (0 = sem limite) e se leva aeronave. A carga apoia a base de cada modelo no assoalho.
17. **Desvirar só para quem é do emprego**, também dirigindo o caminhão.
18. **Guincho portátil, decisões finais (22/10):** loja só para mecânicos (`mecanica_centro`, `mechanic`) em balcões marcados no painel (aba Guincho → "Guincho portátil · lojas"); preço R$ 2.500; o mecânico revende. Fixa só em superfície em pé (tronco, poste, parede) a até 2,5 m. Enquanto montado, o item sai do inventário; recolher devolve com os usos restantes (barra de desgaste do inventário). Só quem montou recolhe; se ele sair do jogo, qualquer um recolhe. Um guincho montado por jogador.
