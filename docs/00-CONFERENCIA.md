# 00 — Conferência dos 6 documentos

Feita em 22/10/2026, antes de qualquer código.

| # | Verificação | Resultado |
| --- | --- | --- |
| 1 | Contradições | Nenhuma. Os tipos (plataforma fixa, garfo, braço, gancho) são os mesmos no PRD, TRD, FLUXO, BACKEND e PLANO |
| 2 | Funcionalidade ausente em algum doc | Os 10 requisitos da v1 têm fluxo (03), dados/servidor (05) e etapa (06). Helicóptero e rapel: PRD, PLANO (Etapas 10–11), detalhados quando a v1 for aprovada |
| 3 | Dependências não confirmadas | 3, testadas na Etapa 1: native da plataforma-garfo, native da plataforma-braço, cordas sincronizadas |
| 4 | Decisões sem justificativa | Nenhuma (tabela no TRD) |
| 5 | Fluxos incompletos | Operador sai do jogo ou morre, ou caminhão some: tratado no BACKEND (segurança) |
| 6 | Permissões indefinidas | Nenhuma: empregos e "exige serviço" por caminhão; ACE `vel_guincho.admin` no painel |
| 7 | Riscos de segurança | Ordem de fases no servidor, distância, carro vazio, limite de pedidos, sem SQL com texto do cliente |
| 8 | Banco incompatível | Nenhum: só 3 tabelas novas |
| 9 | Fora do escopo | Cobrança, chamado no celular e modelos 3D ficaram fora (PRD) |
| 10 | Exige decisão do dono | Lista abaixo |

## Para o dono decidir (com a recomendação)

1. **Empregos padrão de cada caminhão** (TRD, tabela de modelos). Recomendo como está; dá para trocar no painel.
2. **Exigir estar em serviço:** sim por padrão.
3. **Comprimento do cabo padrão:** médio (15 m).
4. **Repositório privado no GitHub `vel_guincho`:** criar agora (a regra pede aprovação na primeira publicação).
