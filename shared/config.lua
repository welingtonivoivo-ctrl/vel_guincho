Config = {}

-- Comprimento do cabo, escolhido no painel por nome (metros)
Config.Cabo = { curto = 10.0, medio = 15.0, longo = 25.0 }
Config.CaboPadrao = 'medio'

-- Tempo para a plataforma que inclina ir de um extremo ao outro (ms)
Config.TempoPlataforma = 4000

-- Quem pode usar o painel e os comandos de teste: a permissão própria (registrada no mri_Qadmin)
-- e outras ACEs de staff que a cidade já usa (qualquer uma serve)
Config.AcePainel = 'vel_guincho.admin'
Config.AcesPainel = { 'vel_guincho.admin', 'street.personagens.staff' }

-- Caminhões cadastrados na primeira partida (só se a tabela estiver vazia).
-- Pontos ficam vazios: são marcados no painel com a prévia (Etapa 2).
Config.Semente = {
    { modelo = 'volvocbmesp', nome = 'Guincho Bombeiros (AG)', tipo = 'plataforma', plataforma = 'cabine',
      empregos = { 'bombeiros', 'guincho_sp' } },
    { modelo = 'delivery11cmm', nome = 'Guincho Polícia (CMM)', tipo = 'plataforma', plataforma = 'cabine',
      empregos = { 'pmesp', 'pcesp', 'gcm', 'prf', 'police', 'guincho_sp' } },
    { modelo = 'deliverymec', nome = 'Guincho Mecânica', tipo = 'plataforma', plataforma = 'fixa',
      empregos = { 'mecanica_centro', 'guincho_sp' } },
    { modelo = 'flatbed', nome = 'Flatbed', tipo = 'plataforma', plataforma = 'fixa',
      empregos = { 'mecanica_centro', 'guincho_sp' } },
    { modelo = 'towtruck', nome = 'Reboque (gancho)', tipo = 'gancho',
      empregos = { 'mecanica_centro', 'guincho_sp' } },
    { modelo = 'towtruck2', nome = 'Reboque pequeno (gancho)', tipo = 'gancho',
      empregos = { 'mecanica_centro', 'guincho_sp' } },
}

-- Guincho portátil (item): qualquer jogador fixa numa árvore, poste ou parede e desvira um carro.
-- Desgasta: cada desvirada gasta 1 uso; sem usos, quebra e não volta para o inventário.
-- usos, preco, alcance, cabo, quedaKmh, arrasto e empregosLoja também mudam no painel (aba Guincho).
-- O que for salvo lá vale por cima destes valores.
-- Vendido numa loja só para os empregos abaixo (balcão marcado no painel), para o mecânico revender.
Config.Portatil = {
    item = 'guincho_portatil',
    modelo = 'prop_bison_winch',
    usos = 10,
    cabo = 'medio',          -- comprimento do cabo (Config.Cabo)
    alcance = 3.0,           -- distância máxima do jogador até onde fixa (m)
    quedaKmh = 30,           -- preso num carro: acima disso o guincho cai e se perde
    arrasto = 1.2,           -- velocidade do arrastar, em m/s (vale para todos os guinchos)
    preco = 2500,
    empregosLoja = { 'mecanica_centro', 'mechanic' },
}
