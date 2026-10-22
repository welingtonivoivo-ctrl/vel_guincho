-- Colar em ox_inventory/data/items.lua e copiar install/guincho_portatil.png para ox_inventory/web/images/.
-- O ox_inventory só lê itens novos ao reiniciar (reinício da cidade, sem jogadores).
	['guincho_portatil'] = {
		label = 'Guincho portátil',
		weight = 12000,
		stack = false,
		close = true,
		consume = 0,
		description = 'Motor de guincho com cabo de aço. Fixe numa árvore, poste ou parede para desvirar um carro capotado.',
		server = { export = 'vel_guincho.usarPortatil' },
	},
