Config = {}

-- Comprimento do cabo, escolhido no painel por nome (metros)
Config.Cabo = { curto = 10.0, medio = 15.0, longo = 25.0 }
Config.CaboPadrao = 'medio'

-- Tempo para a plataforma que inclina ir de um extremo ao outro (ms)
Config.TempoPlataforma = 4000

-- Quem pode usar o painel e os comandos de teste
Config.AcePainel = 'vel_guincho.admin'

-- Caminhões cadastrados na primeira partida (só se a tabela estiver vazia).
-- Pontos ficam vazios: são marcados no painel com a prévia (Etapa 2).
Config.Semente = {
    { modelo = 'volvocbmesp', nome = 'Guincho Bombeiros (AG)', tipo = 'plataforma', plataforma = 'garfo',
      empregos = { 'bombeiros', 'guincho_sp' } },
    { modelo = 'delivery11cmm', nome = 'Guincho Polícia (CMM)', tipo = 'plataforma', plataforma = 'escavadeira',
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
