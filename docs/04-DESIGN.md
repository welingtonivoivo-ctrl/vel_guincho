# 04 — Design (o que o jogador vê e ouve)

Segue `mri-game-ux` (nada aparece do nada, ação com animação, interface espera a cena) e `mri-world-placement` (trilho de teclas, marcadores firmes).

## No mundo

- **Cabo:** corda real do GTA (textura de cabo de aço), saindo do motor do guincho. Enrola e desenrola de verdade ao puxar ou soltar, sem teleporte.
- **Gancho na mão:** prop de gancho na mão direita, com animação de carregar. Ao engatar: animação de agachar e prender (~1,2 s) e som metálico.
- **Caixa de comando:** animação de operar alavanca. O som do motor do guincho toca enquanto puxa.
- **Carro subindo:** velocidade constante (~0,6 m/s), com leve balanço ao passar da rampa para a plataforma.
- **Plataforma que inclina:** movimento contínuo (~4 s para descer ou subir), com som hidráulico.
- **Desvirar:** o carro gira devagar segurando a tecla, com estalo de lataria ao assentar.
- **Pontos do Interact** só aparecem para quem pode usar aquele caminhão.

## Interface

- **Trilho de teclas (NUI)** na caixa de comando e na cabine, igual ao `PlaceRail` do padrão MRI. Não usa textUI do ox_lib nem texto desenhado.
- **Avisos curtos** (ox_lib notify), com textos nos locales. Exemplos: "Cabo no limite", "Só carro vazio", "Carro entregue no Pátio Central".
- **Ações perigosas** (soltar o carro em movimento, por exemplo) são confirmadas **segurando** a tecla, com anel que enche. Não abre janela de confirmação.

## Painel (mri_Qadmin, aba "Guincho")

- Três colunas: **lista** (busca) | **mapa** (pátios) | **editor**. Usa `MriMapEditorLayout` / `MriGameMap` do `@mriqbox/ui-kit` se o mri_Qadmin já o expuser; se não, cards no estilo do `vel_balcao`.
- Cada ponto mostra um resumo: "Motor do guincho ✓", "Posição de carga ✓ (girado 180°)". Não mostra números.
- Botões grandes: "Marcar", "Marcar de novo", "Ver", "Testar plataforma", "Ir até lá", "Remover".
- Cores e tema herdados do mri_Qadmin (acento `mri:color`).

## Textos (pt-BR, exemplos)

| Chave | Texto |
| --- | --- |
| `pegar_cabo` | Pegar cabo |
| `engatar` | Engatar cabo |
| `engatar_desvirar` | Engatar para desvirar |
| `caixa` | Caixa de comando |
| `puxar` | Puxar cabo |
| `soltar` | Soltar cabo |
| `inclinar` | Inclinar plataforma |
| `recolher_plat` | Recolher plataforma |
| `recolher_cabo` | Recolher cabo |
| `soltar_reboque` | Soltar reboque |
| `so_vazio` | Só dá para guinchar carro vazio |
| `entregue` | Carro entregue no %s |
