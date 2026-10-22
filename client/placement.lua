-- Ferramentas de marcação no mundo (modelo mri-world-placement), com mira que acerta veículos
-- (os pontos ficam no próprio caminhão) e carro-fantasma para a posição de carga.


GuinchoPlacer = {}

local ROTATE_SPEED = 90.0
local WHEEL_STEP = 15.0
local RAY_DISTANCE = 30.0
-- Weapon wheel, attacks, vehicle weapon scroll and Esc (200), so the keys only drive the tool.
local BLOCKED_CONTROLS = { 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 200 }
local KEY = { mark = 38, undo = 177, finish = 191, cancel = 200, left = 174, right = 175, wheelUp = 15, wheelDown = 14 }
local START_COLOR = { 0, 230, 153 }
local STOP_COLOR = { 255, 255, 255 }
local ZONE_COLOR = { 255, 210, 0 }
local ZONE_MIN, ZONE_MAX, ZONE_STEP = 0.5, 50.0, 0.5
local SHIFT = 21

local active = false

-- Key rail drawn by the ui_page while a tool runs (false hides it).
local function hud(data)
	SendNUIMessage({ action = 'placeHud', data = data })
end

local function block()
	for i = 1, #BLOCKED_CONTROLS do DisableControlAction(0, BLOCKED_CONTROLS[i], true) end
	DisableControlAction(0, KEY.finish, true)
end

-- The ox_lib raycast waits a frame, so it runs apart and the draw loop keeps every frame.
local function trackAim()
	local aim = {}
	CreateThread(function()
		while active do
			local hit, _, coords = lib.raycast.fromCamera(1 | 2 | 16, 4, RAY_DISTANCE)
			aim.coords = (hit and coords and #coords > 1.0) and coords or nil
		end
	end)
	return aim
end

local function ghostPed(model, heading)
	local hash = tonumber(model) or joaat(model)
	if not IsModelInCdimage(hash) or not pcall(lib.requestModel, hash, 10000) then return nil end
	local coords = GetEntityCoords(cache.ped)
	local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, heading, false, false)
	SetModelAsNoLongerNeeded(hash)
	SetPedDefaultComponentVariation(ped)
	SetEntityAlpha(ped, 170, false)
	SetEntityCollision(ped, false, false)
	FreezeEntityPosition(ped, true)
	SetEntityInvincible(ped, true)
	SetBlockingOfNonTemporaryEvents(ped, true)
	return ped
end

-- Carro-fantasma (posição de carga na plataforma): local, transparente, sem colisão.
-- Devolve também quanto subir o centro para as rodas ficarem no ponto mirado.
local function ghostVehicle(model, heading)
	local hash = tonumber(model) or joaat(model)
	if not IsModelInCdimage(hash) or not pcall(lib.requestModel, hash, 10000) then return nil end
	local coords = GetEntityCoords(cache.ped)
	local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, false, false)
	SetModelAsNoLongerNeeded(hash)
	SetEntityAlpha(veh, 170, false)
	SetEntityCollision(veh, false, false)
	FreezeEntityPosition(veh, true)
	SetEntityInvincible(veh, true)
	SetVehicleDoorsLocked(veh, 2)
	local min = GetModelDimensions(hash)
	return veh, -min.z
end

-- Suite accent from the mri:color convar, like the mri_Qbox zone drawer.
local function accent()
	local hex = GetConvar('mri:color', '#00E699'):match('^#(%x%x%x%x%x%x)') or '00E699'
	return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

-- Aim cursor of a point without a model; a sphere marker scales by radius, so 0.1 is 20 cm across.
local function drawCursor(point, color)
	DrawMarker(28, point.x, point.y, point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.1, 0.1, color[1], color[2], color[3], 220, false, false, 2, false, nil, nil, false)
end

local function drawStop(point, color)
	DrawMarker(1, point.x, point.y, point.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.6, 0.35, color[1], color[2], color[3], 170, false, false, 2, false, nil, nil, false)
end

-- Box centered on `c`, turned by `heading`, `size` = { x, y, z } full lengths.
local function drawBox(c, size, heading, color, alpha)
	local rad = math.rad(heading)
	local cos, sin = math.cos(rad), math.sin(rad)
	local hx, hy, hz = size.x / 2, size.y / 2, size.z / 2
	local corners = {}
	for i, offset in ipairs({ { -hx, -hy }, { hx, -hy }, { hx, hy }, { -hx, hy } }) do
		local rx, ry = offset[1] * cos - offset[2] * sin, offset[1] * sin + offset[2] * cos
		corners[i] = { c.x + rx, c.y + ry }
	end
	local r, g, b, a = color[1], color[2], color[3], alpha or 255
	for i = 1, 4 do
		local p, n = corners[i], corners[i % 4 + 1]
		DrawLine(p[1], p[2], c.z - hz, n[1], n[2], c.z - hz, r, g, b, a)
		DrawLine(p[1], p[2], c.z + hz, n[1], n[2], c.z + hz, r, g, b, a)
		DrawLine(p[1], p[2], c.z - hz, p[1], p[2], c.z + hz, r, g, b, a)
	end
end

-- Arrow on the floor of the box pointing where `heading` faces.
local function drawArrow(c, heading, color)
	local rad = math.rad(heading)
	local length, tip = 2.0, 0.3
	local ex, ey = c.x - math.sin(rad) * length, c.y + math.cos(rad) * length
	local z = c.z + 0.5
	DrawLine(c.x, c.y, z, ex, ey, z, color[1], color[2], color[3], 255)
	for _, side in ipairs({ 150, -150 }) do
		local a = rad + math.rad(side)
		DrawLine(ex, ey, z, ex - math.sin(a) * tip, ey + math.cos(a) * tip, z, color[1], color[2], color[3], 255)
	end
end

local function drawLabel(c, text)
	local onScreen, x, y = World3dToScreen2d(c.x, c.y, c.z)
	if not onScreen then return end
	SetTextScale(0.35, 0.35)
	SetTextFont(4)
	SetTextColour(255, 255, 255, 215)
	SetTextOutline()
	SetTextCentre(true)
	BeginTextCommandDisplayText('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(x, y)
end

-- The pause menu opens when Esc is released, so it stays blocked until the key is up.
local function releaseEsc()
	repeat
		DisableControlAction(0, KEY.cancel, true)
		Wait(0)
	until not IsDisabledControlPressed(0, KEY.cancel)
	DisableControlAction(0, KEY.cancel, true)
end

local function clampSize(value)
	return math.min(ZONE_MAX, math.max(ZONE_MIN, value))
end

---Onde o jogador está: anda até o lugar, olha para onde o operador deve olhar e aperte E.
---Para pontos em que a mira não acerta (chassi sem colisão) e que são "onde a pessoa fica".
---@return { coords: { x: number, y: number, z: number }, heading: number }|nil
function GuinchoPlacer.here()
	if active then return nil end
	active = true
	hud({ mode = 'here' })
	local color = accent()
	local result
	while active do
		block()
		local c, h = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
		local pe = vec3(c.x, c.y, c.z - 0.98)
		DrawMarker(25, pe.x, pe.y, pe.z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8, color[1], color[2], color[3], 180, false, false, 2, false, nil, nil, false)
		drawArrow(vec3(pe.x, pe.y, pe.z - 0.4), h, color)
		if IsControlJustPressed(0, KEY.mark) then
			PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			result = { coords = { x = pe.x, y = pe.y, z = pe.z }, heading = math.floor(h * 100 + 0.5) / 100 }
			break
		elseif IsDisabledControlJustPressed(0, KEY.cancel) or IsControlJustPressed(0, KEY.undo) then
			PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			releaseEsc()
			break
		end
		Wait(0)
	end
	active = false
	hud(false)
	return result
end

-- Dois pontos na linha do carro (1 m à frente e 1 m atrás do centro), guardados relativos à peça da
-- plataforma. Com eles o carro é recolocado deitado na plataforma em qualquer inclinação (sem conta de giro).
local function pointsOnAnchor(truck, anchor, y, z)
	local function rel(dy)
		local w = GetOffsetFromEntityInWorldCoords(truck, 0.0, y + dy, z)
		local o = GetOffsetFromEntityGivenWorldCoords(anchor, w.x, w.y, w.z)
		return { x = math.floor(o.x * 1000 + 0.5) / 1000, y = math.floor(o.y * 1000 + 0.5) / 1000, z = math.floor(o.z * 1000 + 0.5) / 1000 }
	end
	return { f = rel(1.0), t = rel(-1.0) }
end

---Carro-fantasma preso ao caminhão, já no centro: ↑ ↓ anda na plataforma, Shift + ↑ ↓ sobe e desce,
---← → gira, E confirma. Devolve o deslocamento relativo ao caminhão (sempre centralizado em X) e, com
---`anchor` (objeto preso à peça da plataforma), também relativo à peça em `b` (posição e giro), para o
---carro acompanhar a plataforma quando ela inclina.
---@param opts { vehicle: string|number, truck: number, anchor?: number, start?: { y: number, z: number, h: number } }
---@return { x: number, y: number, z: number, h: number, b?: table }|nil
function GuinchoPlacer.onTruck(opts)
	if active then return nil end
	local truck = opts.truck
	if not DoesEntityExist(truck) then return nil end
	local ghost = ghostVehicle(opts.vehicle, GetEntityHeading(truck))
	if not ghost then return nil end
	local min, max = GetModelDimensions(GetEntityModel(truck))
	local cmin = GetModelDimensions(GetEntityModel(ghost))
	local s = opts.start or {}
	-- começo: o que já estava marcado, ou metade de trás do caminhão com as rodas no topo do chassi
	local y = tonumber(s.y) or (min.y * 0.35)
	local z = tonumber(s.z) or ((min.z + max.z) * 0.5 - cmin.z)
	local h = tonumber(s.h) or 0.0
	active = true
	hud({ mode = 'carga' })
	local result
	local UP, DOWN = 172, 173
	while active do
		block()
		DisableControlAction(0, UP, true); DisableControlAction(0, DOWN, true)
		local frame = GetFrameTime()
		local passo = (IsDisabledControlPressed(0, UP) and 1 or 0) - (IsDisabledControlPressed(0, DOWN) and 1 or 0)
		if passo ~= 0 then
			if IsControlPressed(0, SHIFT) then z = z + passo * 0.4 * frame else y = y + passo * 1.2 * frame end
		end
		if IsControlPressed(0, KEY.left) then h = h + ROTATE_SPEED * frame end
		if IsControlPressed(0, KEY.right) then h = h - ROTATE_SPEED * frame end
		h = h % 360
		AttachEntityToEntity(ghost, truck, 0, 0.0, y, z, 0.0, 0.0, h, false, false, false, false, 2, true)
		if IsControlJustPressed(0, KEY.mark) then
			PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			local r = function(v) return math.floor(v * 1000 + 0.5) / 1000 end
			result = { x = 0.0, y = r(y), z = r(z), h = r(h) }
			break
		elseif IsDisabledControlJustPressed(0, KEY.cancel) or IsControlJustPressed(0, KEY.undo) then
			PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			releaseEsc()
			break
		end
		Wait(0)
	end
	active = false
	hud(false)
	if result and opts.anchor and DoesEntityExist(opts.anchor) then
		result.b = pointsOnAnchor(truck, opts.anchor, result.y, result.z)
	end
	DeleteEntity(ghost)
	return result
end

function GuinchoPlacer.isActive()
	return active
end

function GuinchoPlacer.cancel()
	active = false
end

---Ghost follows the aim; arrows and wheel rotate, E confirms, Backspace or Esc cancels.
---Without `model` (an interaction point) a sphere in the suite accent follows the aim instead and there is no heading.
---@param opts { model?: string|number, vehicle?: string|number, heading?: number }
---@return { coords: { x: number, y: number, z: number }, heading?: number }|nil
function GuinchoPlacer.point(opts)
	if active then return nil end
	local heading = tonumber(opts.heading) or GetEntityHeading(cache.ped)
	local ghost, lift = nil, 0.0
	if opts.vehicle then
		ghost, lift = ghostVehicle(opts.vehicle, heading)
		if not ghost then return nil end
	elseif opts.model then
		ghost = ghostPed(opts.model, heading)
		if not ghost then return nil end
	end

	active = true
	hud({ mode = ghost and 'place' or 'spot' })
	local aim = trackAim()
	local color = accent()

	local result, last
	while active do
		local frame = GetFrameTime()
		block()

		local coords = aim.coords
		if coords and coords ~= last then
			last = coords
			if ghost then SetEntityCoords(ghost, coords.x, coords.y, coords.z + lift, false, false, false, false) end
		end

		if ghost then
			if IsControlPressed(0, KEY.left) then heading = heading + ROTATE_SPEED * frame end
			if IsControlPressed(0, KEY.right) then heading = heading - ROTATE_SPEED * frame end
			if IsDisabledControlJustPressed(0, KEY.wheelUp) then heading = heading + WHEEL_STEP end
			if IsDisabledControlJustPressed(0, KEY.wheelDown) then heading = heading - WHEEL_STEP end
			heading = heading % 360
			SetEntityHeading(ghost, heading)
		elseif last then
			drawCursor(last, color)
		end

		if IsControlJustPressed(0, KEY.mark) and last then
			PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			result = { coords = { x = last.x, y = last.y, z = last.z + lift } }
			if ghost then result.heading = math.floor(heading * 100 + 0.5) / 100 end
			break
		elseif IsDisabledControlJustPressed(0, KEY.cancel) or IsControlJustPressed(0, KEY.undo) then
			PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			releaseEsc()
			break
		end
		Wait(0)
	end

	active = false
	hud(false)
	if ghost then DeleteEntity(ghost) end
	return result
end

---Box with heading around the player: walk to place it, the player's heading turns it, wheel sizes it,
---Shift + wheel sets the height, E marks. With `multiple`, Backspace undoes and Enter finishes; otherwise
---E returns at once and Backspace cancels. Esc always cancels. `refs` are zones already placed, drawn green.
---@param opts { size?: { x: number, y: number, z: number }, multiple?: boolean, refs?: { coords: table, size: table, heading: number, label?: string }[] }
---@return { coords: table, heading: number, size: table }|{ coords: table, heading: number, size: table }[]|nil
function GuinchoPlacer.zone(opts)
	if active then return nil end
	local s = type(opts.size) == 'table' and opts.size or { x = 3.0, y = 3.0, z = 3.0 }
	local size = { x = clampSize(tonumber(s.x) or 3.0), y = clampSize(tonumber(s.y) or 3.0), z = clampSize(tonumber(s.z) or 3.0) }
	local refs = type(opts.refs) == 'table' and opts.refs or {}
	local marks = {}

	active = true
	local function push() hud({ mode = 'zone', size = size, count = #marks, multiple = opts.multiple == true }) end
	push()

	local result
	while active do
		block()

		for _, ref in ipairs(refs) do
			drawBox(ref.coords, ref.size, ref.heading or 0.0, START_COLOR, 200)
			if ref.label then drawLabel(vec3(ref.coords.x, ref.coords.y, ref.coords.z + ref.size.z / 2 + 0.2), ref.label) end
		end
		for _, mark in ipairs(marks) do drawBox(mark.coords, mark.size, mark.heading, START_COLOR, 200) end

		local coords, heading = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
		drawBox(coords, size, heading, ZONE_COLOR)
		drawArrow(coords, heading, ZONE_COLOR)
		drawLabel(vec3(coords.x, coords.y, coords.z + size.z / 2 + 0.3), ('%.1f x %.1f x %.1f m'):format(size.x, size.y, size.z))

		local step = (IsDisabledControlJustPressed(0, KEY.wheelUp) and 1 or 0) - (IsDisabledControlJustPressed(0, KEY.wheelDown) and 1 or 0)
		if step ~= 0 then
			if IsControlPressed(0, SHIFT) then
				size.z = clampSize(size.z + step * ZONE_STEP)
			else
				size.x, size.y = clampSize(size.x + step * ZONE_STEP), clampSize(size.y + step * ZONE_STEP)
			end
			push()
		end

		if IsControlJustPressed(0, KEY.mark) then
			local mark = {
				coords = { x = coords.x, y = coords.y, z = coords.z },
				heading = math.floor(heading * 100 + 0.5) / 100,
				size = { x = size.x, y = size.y, z = size.z },
			}
			PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			if not opts.multiple then
				result = mark
				break
			end
			marks[#marks + 1] = mark
			push()
		elseif IsControlJustPressed(0, KEY.undo) then
			PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			if not opts.multiple then break end
			if #marks > 0 then
				marks[#marks] = nil
				push()
			end
		elseif opts.multiple and IsDisabledControlJustPressed(0, KEY.finish) then
			result = #marks > 0 and marks or nil
			break
		elseif IsDisabledControlJustPressed(0, KEY.cancel) then
			PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			releaseEsc()
			break
		end
		Wait(0)
	end

	active = false
	hud(false)
	return result
end

---Marks a path from `start`: E adds where the player aims, Backspace undoes, Enter finishes, Esc cancels.
---Finishing with no stops counts as cancel, so the caller keeps the path it had.
---@param opts { start: vector3|table, max?: integer }
---@return { x: number, y: number, z: number }[]|nil
function GuinchoPlacer.path(opts)
	if active then return nil end
	local s = opts.start
	if type(s) ~= 'table' and type(s) ~= 'vector3' then return nil end
	local start = vec3(s.x + 0.0, s.y + 0.0, s.z + 0.0)
	local max = opts.max or 20

	local points = {}
	active = true
	hud({ mode = 'route', count = 0 })
	local aim = trackAim()

	local result
	while active do
		block()
		local last = aim.coords

		local previous = start
		drawStop(start, START_COLOR)
		for _, point in ipairs(points) do
			local here = vec3(point.x, point.y, point.z)
			DrawLine(previous.x, previous.y, previous.z + 0.1, here.x, here.y, here.z + 0.1, START_COLOR[1], START_COLOR[2], START_COLOR[3], 220)
			drawStop(here, STOP_COLOR)
			previous = here
		end
		if last then
			DrawLine(previous.x, previous.y, previous.z + 0.1, last.x, last.y, last.z + 0.1, 255, 255, 255, 110)
			drawStop(last, STOP_COLOR)
		end

		if IsControlJustPressed(0, KEY.mark) and last and #points < max then
			points[#points + 1] = { x = last.x, y = last.y, z = last.z }
			PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			hud({ mode = 'route', count = #points })
		elseif IsControlJustPressed(0, KEY.undo) and #points > 0 then
			points[#points] = nil
			PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			hud({ mode = 'route', count = #points })
		elseif IsDisabledControlJustPressed(0, KEY.finish) then
			result = #points > 0 and points or nil
			break
		elseif IsDisabledControlJustPressed(0, KEY.cancel) then
			PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
			releaseEsc()
			break
		end
		Wait(0)
	end

	active = false
	hud(false)
	return result
end
