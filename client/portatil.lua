-- Etapa 7B: guincho portátil. Usar o item abre a mira: o motor-fantasma encosta na superfície
-- mirada (tronco, poste ou parede: só superfície em pé, perto do jogador). E fixa, setas giram, Esc cancela.
-- Depois de fixo, o motor funciona como o de um caminhão (client/cabo.lua): pegar cabo, engatar no
-- carro capotado, "Puxar cabo para desvirar" no motor e "Recolher guincho".

GuinchoPortatil = {}

local P = Config.Portatil
local MODELO = joaat(P.modelo)
local ANIM = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
local BLOQUEADOS = { 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 200 }
local TECLA = { fixar = 38, cancelar = 200, voltar = 177, esquerda = 174, direita = 175 }
local GIRO_VELOCIDADE = 90.0
local montando = false

local function notificar(chave, tipo, ...)
    lib.notify({ title = locale('painel_titulo'), description = locale(chave, ...), type = tipo or 'error' })
end

---Ponto de onde o cabo sai: frente do motor, na altura do meio (o fundo fica encostado na superfície).
function GuinchoPortatil.motor(obj)
    local min, max = GetModelDimensions(GetEntityModel(obj))
    return GetOffsetFromEntityInWorldCoords(obj, 0.0, max.y, (min.z + max.z) / 2)
end

local function legenda(c, texto)
    local ok, x, y = World3dToScreen2d(c.x, c.y, c.z)
    if not ok then return end
    SetTextScale(0.35, 0.35); SetTextFont(4); SetTextColour(255, 255, 255, 230); SetTextOutline(); SetTextCentre(true)
    BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(texto); EndTextCommandDisplayText(x, y)
end

---Mira: devolve posição e giro do motor encostado na superfície, ou nil (com o motivo).
---mira = { coords, normal } lidos pela linha da mira (o raycast do ox_lib espera um quadro).
local function mirar(mira, min, max, giro)
    local coords, normal = mira.coords, mira.normal
    if not coords or not normal then return nil, 'portatil_mire' end
    if math.abs(normal.z) > 0.5 then return nil, 'portatil_em_pe' end
    if #(GetEntityCoords(cache.ped) - coords) > P.alcance then return nil, 'portatil_perto' end
    local n = norm(vec3(normal.x, normal.y, 0.0))
    -- frente do motor (eixo Y) para fora da superfície; o fundo encosta nela
    local heading = math.deg(math.atan(-n.x, n.y)) + giro
    local pos = coords + n * (-min.y) - vec3(0.0, 0.0, (min.z + max.z) / 2)
    return { pos = pos, heading = heading % 360.0, ponto = coords }
end

local function montar(slot)
    if montando or cache.vehicle then return end
    if not pcall(lib.requestModel, MODELO, 5000) then return end
    montando = true
    local min, max = GetModelDimensions(MODELO)
    local c = GetEntityCoords(cache.ped)
    local fantasma = CreateObjectNoOffset(MODELO, c.x, c.y, c.z - 5.0, false, false, false)
    SetModelAsNoLongerNeeded(MODELO)
    SetEntityAlpha(fantasma, 170, false)
    SetEntityCollision(fantasma, false, false)
    FreezeEntityPosition(fantasma, true)
    SendNUIMessage({ action = 'placeHud', data = { mode = 'portatil' } })

    local mira = {}
    CreateThread(function()
        while montando do
            local hit, _, coords, normal = lib.raycast.fromCamera(1 | 16, 4, 6.0)
            mira.coords = hit and coords or nil
            mira.normal = hit and normal or nil
        end
    end)

    local giro, escolhido = 0.0, nil
    while true do
        for i = 1, #BLOQUEADOS do DisableControlAction(0, BLOQUEADOS[i], true) end
        local frame = GetFrameTime()
        if IsControlPressed(0, TECLA.esquerda) then giro = giro + GIRO_VELOCIDADE * frame end
        if IsControlPressed(0, TECLA.direita) then giro = giro - GIRO_VELOCIDADE * frame end
        local alvo, motivo = mirar(mira, min, max, giro)
        if alvo then
            SetEntityVisible(fantasma, true, false)
            SetEntityCoordsNoOffset(fantasma, alvo.pos.x, alvo.pos.y, alvo.pos.z, false, false, false)
            SetEntityRotation(fantasma, 0.0, 0.0, alvo.heading, 2, true)
        else
            SetEntityVisible(fantasma, false, false)
            local frente = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.5, 0.5)
            legenda(frente, locale(motivo))
        end
        if IsControlJustPressed(0, TECLA.fixar) and alvo then
            escolhido = alvo
            break
        elseif IsDisabledControlJustPressed(0, TECLA.cancelar) or IsControlJustPressed(0, TECLA.voltar) or cache.vehicle then
            repeat DisableControlAction(0, TECLA.cancelar, true) Wait(0) until not IsDisabledControlPressed(0, TECLA.cancelar)
            break
        end
        Wait(0)
    end
    SendNUIMessage({ action = 'placeHud', data = false })
    DeleteEntity(fantasma)
    mira.coords = nil

    if escolhido then
        if pcall(lib.requestAnimDict, ANIM.dict, 3000) then
            TaskTurnPedToFaceCoord(cache.ped, escolhido.ponto.x, escolhido.ponto.y, escolhido.ponto.z, 600)
            Wait(600)
            TaskPlayAnim(cache.ped, ANIM.dict, ANIM.clip, 4.0, -4.0, 2500, 1, 0, false, false, false)
            Wait(2500)
        end
        local p = escolhido.pos
        local ok, erro = lib.callback.await('vel_guincho:portatil:fixar', false, slot,
            { x = p.x, y = p.y, z = p.z }, { x = 0.0, y = 0.0, z = escolhido.heading })
        if ok then
            PlaySoundFrontend(-1, 'Hook_Attach', 'DLC_IE_Steal_Cargobob_Sounds', true)
            notificar('portatil_fixado', 'success')
        else
            notificar(erro or 'pedido_invalido')
        end
    end
    montando = false
end

RegisterNetEvent('vel_guincho:portatil:montar', function(slot)
    if GetInvokingResource() then return end
    CreateThread(function() montar(slot) end)
end)

---Opções do motor fixo que não são do cabo: "Recolher guincho" (somadas às do cabo em client/cabo.lua).
function GuinchoPortatil.opcoes(obj, offset)
    return {
        {
            name = 'vel_guincho_recolher', icon = 'fa-solid fa-box-archive', label = locale('portatil_recolher'), distance = 2.0,
            offsetAbsolute = offset,
            canInteract = function(ent)
                local s = Entity(ent).state
                local p = s.velPortatil
                if not p or (p.dono and p.dono ~= cache.serverId) then return false end
                local cabo = s.velCabo
                return not cabo or cabo.mao == cache.serverId
            end,
            onSelect = function(data)
                local ent = data.entity or obj
                if pcall(lib.requestAnimDict, ANIM.dict, 3000) then
                    TaskPlayAnim(cache.ped, ANIM.dict, ANIM.clip, 4.0, -4.0, 1800, 1, 0, false, false, false)
                    Wait(1800)
                end
                local ok, msg = lib.callback.await('vel_guincho:portatil:recolher', false, NetworkGetNetworkIdFromEntity(ent))
                if not ok then return notificar(msg or 'pedido_invalido') end
                notificar(msg, msg == 'portatil_sucata' and 'error' or 'success')
            end,
        },
    }
end

-- Balcões da loja (marcados no painel): ponto do Interact que abre a loja do ox_inventory.
-- O ox_inventory confere o emprego de novo ao abrir.
local balcoes = {} -- ids do mri_Qinteract

local function meuEmprego()
    local pd = exports.qbx_core:GetPlayerData()
    return pd and pd.job and pd.job.name
end

local function montarBalcoes(estado)
    for _, id in ipairs(balcoes) do pcall(function() exports.mri_Qinteract:removeCoords(id) end) end
    balcoes = {}
    for _, l in ipairs(estado and estado.lojas or {}) do
        local c = l.coords
        balcoes[#balcoes + 1] = exports.mri_Qinteract:addCoords(vec3(c.x, c.y, c.z + 1.0), {
            {
                name = 'vel_guincho_loja_' .. l.id, icon = 'fa-solid fa-cart-shopping', label = locale('portatil_comprar'), distance = 2.0,
                canInteract = function() return lib.table.contains(P.empregosLoja, meuEmprego()) end,
                onSelect = function() exports.ox_inventory:openInventory('shop', { type = 'vel_guincho_portatil' }) end,
            },
        })
    end
end

local assinatura
AddStateBagChangeHandler('velGuincho', 'global', function(_, _, valor)
    local nova = json.encode(valor and valor.lojas or {})
    if nova == assinatura then return end
    assinatura = nova
    montarBalcoes(valor)
end)

CreateThread(function()
    local estado = GlobalState.velGuincho
    assinatura = json.encode(estado and estado.lojas or {})
    montarBalcoes(estado)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, id in ipairs(balcoes) do pcall(function() exports.mri_Qinteract:removeCoords(id) end) end
end)
