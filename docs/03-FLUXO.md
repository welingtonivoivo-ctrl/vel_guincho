# 03 — Fluxo (passo a passo de quem usa)

Legenda: **[I]** opção do Interact (mri_Qinteract) · **[T]** tecla mostrada no trilho da NUI · **[S]** conferido no servidor.

## A. Plataforma (fixa ou que inclina)

1. O operador para o caminhão perto do carro e desce.
2. **Pegar o cabo:** sobe até o motor do guincho (frente da plataforma) **[I] "Pegar cabo"** **[S]**. O gancho aparece na mão, com o cabo saindo do motor. O cabo tem comprimento máximo do cadastro (padrão 15 m) e não deixa passar disso.
3. **Engatar:** perto da frente ou da traseira do carro, **[I] "Engatar cabo"** **[S]** (carro vazio, cadastrado ou não). O cabo fica preso no carro.
4. **Caixa de comando** (lateral do caminhão) **[I] "Caixa de comando"**. O operador faz a animação de operar e o trilho mostra as teclas:
   - **[T] Inclinar / recolher plataforma:** só se a plataforma inclina;
   - **[T] Puxar cabo:** o carro anda até a ponta da plataforma, sobe pela rampa (ou pela plataforma inclinada) e para na posição de carga;
   - **[T] Soltar cabo:** o inverso;
   - **[T] Sair.**
5. **Recolher:** com o carro na posição de carga, **[T] Recolher plataforma**. A plataforma volta, e o carro fica **preso e centralizado**. Na plataforma fixa, o carro já fica preso ao chegar.
6. Viagem: o carro vai junto, sem cair, mesmo em curva e lombada.
7. **Descer:** caixa de comando → **[T] Inclinar** → **[T] Soltar cabo**, e o carro desce até o chão.
8. **Soltar do carro:** **[I] "Soltar cabo"** no carro. O gancho volta para a mão.
9. **Recolher cabo:** caixa de comando → **[T] Recolher cabo**. O gancho volta para o motor.

## B. Gancho (arrastar)

1. O operador dá ré até a traseira do caminhão ficar a menos de 2 m da frente ou da traseira de um carro vazio.
2. **Engate automático** **[S]**: o carro levanta pelo eixo e fica preso.
3. Dirige até o destino. **[T] Soltar reboque** (dentro da cabine): o carro desce e fica parado.

## C. Desvirar (qualquer caminhão cadastrado)

1. Para perto do carro capotado e desce.
2. Pega o cabo (A.2) e **[I] "Engatar para desvirar"** no carro tombado.
3. Volta para a cabine. O trilho mostra **[T] Puxar (segurar)**. Segurando a tecla, o cabo estica e o carro gira até ficar de pé. Soltar a tecla para o giro.
4. De pé, o cabo solta sozinho e volta para o motor. A partir daí, segue o fluxo A ou B normalmente.

## D. Pátio

1. O operador solta o carro (A.7 ou B.3) dentro de uma área de pátio.
2. **[S]** O servidor registra a entrega (quem, placa e hora), marca o carro como "entregue no pátio" e avisa os policiais em serviço.
3. O policial usa a opção **"Apreender veículo"** do `mri_Qgarage`, que já existe, com multa e data.

## E. Painel (admin, aba "Guincho" no mri_Qadmin)

1. Lista de caminhões cadastrados | mapa (pátios) | editor.
2. **Novo caminhão:** "Usar o caminhão em que estou". O modelo vem do veículo, sem digitar nada.
3. **Editor:**
   - nome;
   - tipo (Plataforma ou Gancho);
   - plataforma (Fixa, Inclina-garfo ou Inclina-braço), com um botão **Testar** que move a do caminhão;
   - empregos que podem usar (lista de seleção);
   - exigir serviço (sim/não);
   - comprimento do cabo, escolhido como Curto, Médio ou Longo.
4. **Pontos (marcar com prévia):** o painel some e o trilho mostra as teclas.
   - motor do guincho;
   - caixa de comando;
   - posição de carga: um carro-fantasma em cima da plataforma, girável;
   - início da rampa;
   - engate do gancho.
   Cada ponto vira "Marcado ✓", com "Marcar de novo" e "Ver". Os pontos são salvos relativos ao caminhão.
5. **Pátios:** "Nova área", marcada como caixa (`WorldPlacer.zone`) com nome. Cada pátio tem "Ir até lá" e "Remover".
6. **Ir até lá / Remover** em tudo que tem lugar no mundo.
