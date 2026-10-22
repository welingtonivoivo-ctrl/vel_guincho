# 06 — Plano (etapas, cada uma testada antes da próxima)

| Etapa | Entrega | Teste do dono |
| --- | --- | --- |
| 1 | Esqueleto: fxmanifest, locales, tabelas, semente dos 6 modelos, `GlobalState`; **teste das plataformas** (`volvocbmesp` garfo, `delivery11cmm` braço) com comando de admin | Spawnar os dois, rodar o teste e ver a plataforma subir e descer |
| 2 | Painel no mri_Qadmin: lista, editor, "usar caminhão em que estou", empregos; marcação de pontos com prévia (`WorldPlacer`) | Marcar os pontos dos 6 modelos |
| 3 | Cabo: pegar, levar, engatar e soltar, com corda sincronizada entre 2 jogadores | Dois jogadores veem o mesmo cabo |
| 4 | Plataforma fixa: caixa de comando, puxar até a carga, preso na viagem, descer | `deliverymec` e `flatbed` levam um carro pela cidade sem cair |
| 5 | Plataforma que inclina: inclinar, puxar, recolher, descer | `volvocbmesp` e `delivery11cmm` |
| 6 | Gancho: engate automático na ré e soltar | `towtruck` reboca e solta |
| 7 | Desvirar | Capotar um carro e desvirar |
| 8 | Pátio: zonas no painel, entrega, aviso, log | Entregar no pátio e o policial apreender pelo mri_Qgarage |
| 9 | Polimento AAA (sons, tempos, trilho), `mri-resource-check`, README e `TESTES-DONO.md` | Teste geral |
| — | **Fim da v1**: relatório para a MRI, com o pedido de export de apreensão no `mri_Qgarage` | |
| 10 | Etapa 2: guincho de helicóptero (carro pendurado no cabo) | Levantar um carro e soltar |
| 11 | Etapa 2: rapel (pontos de corda no helicóptero, descer e subir) | Policial desce e sobe |

## Regras

- Cada etapa termina com: código conferido pelo `mri-resource-check`, commit em pt-BR no repositório privado `vel_guincho` e teste do dono em jogo.
- Reinício só com a cidade vazia, pelo dono. Um resource novo precisa de `refresh` antes do `ensure`.
- Nada é mexido em `mri_Qgarage`, `mri_Qadmin` ou outros resources de terceiros. A integração é só pelo que eles já oferecem.
