-- ============================================================
-- ADMIN REVOKER v2 (unificado) — comandos de HD Admin
-- Base: scroll estable del Admin Revoker + funciones del Admin Menu
-- ============================================================
local Players         = game:GetService("Players")
local UIS             = game:GetService("UserInputService")
local RS              = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local player          = Players.LocalPlayer

local GUI_NAME  = "AdminRevoker2"
local MAX_ORDER = 2147483647   -- siempre por encima de avisos/errores del juego

------------------------------------------------------------
-- Utilidades
------------------------------------------------------------
local function mk(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(r, p) return mk("UICorner", {CornerRadius = UDim.new(0, r)}, p) end

-- Padre del GUI: gethui (oculto al juego) > CoreGui > PlayerGui
local function obtenerPadre()
	local p
	pcall(function() if gethui then p = gethui() end end)
	if p then return p end
	pcall(function()
		local cg = game:GetService("CoreGui")
		local t = Instance.new("Folder")
		t.Parent = cg
		t:Destroy()
		p = cg
	end)
	if p then return p end
	return player:WaitForChild("PlayerGui")
end
local guiParent = obtenerPadre()

-- Borrar versiones anteriores (si ejecutas el script dos veces)
for _, par in ipairs({guiParent, player:FindFirstChild("PlayerGui")}) do
	pcall(function()
		local o = par:FindFirstChild(GUI_NAME)
		if o then o:Destroy() end
	end)
end

------------------------------------------------------------
-- Estado (vive fuera de la interfaz para sobrevivir si la reconstruimos)
------------------------------------------------------------
local S = {
	running = true,
	panelOpen = false,
	panelPos = nil, fabPos = nil,
	target = nil,
	killLoop = false, killName = nil,
	troll = false, trollTarget = nil,
	warp = {}, blur = {},
}
local syncs = {}                       -- repintan botones según el estado
local function syncUI()
	for _, f in ipairs(syncs) do pcall(f) end
end
local statusFn = nil
local function setStatus(txt, col)
	if statusFn then statusFn(txt, col) end
end
local refreshFn = function() end

local GRIS    = Color3.fromRGB(150, 150, 170)
local NARANJA = Color3.fromRGB(255, 160, 0)

------------------------------------------------------------
-- Envío de comandos
------------------------------------------------------------
local function enviar(cmd)
	-- 1) Señal de HD Admin
	local sig
	pcall(function() sig = RS.HDAdminHDClient.Signals.RequestCommandSilent end)
	if sig then
		local ok = false
		if sig:IsA("RemoteFunction") then
			ok = pcall(function() sig:InvokeServer(cmd) end)
		elseif sig:IsA("RemoteEvent") then
			ok = pcall(function() sig:FireServer(cmd) end)
		end
		if ok then return "HD Admin" end
	end
	-- 2) Chat nuevo
	local ok = pcall(function()
		TextChatService.TextChannels.RBXGeneral:SendAsync(cmd)
	end)
	if ok then return "chat" end
	-- 3) Chat clásico
	ok = pcall(function()
		RS.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(cmd, "All")
	end)
	if ok then return "chat clásico" end
	return nil
end

local function run(cmd, okText, col)
	local via = enviar(cmd)
	if via then
		setStatus(okText .. "  (" .. via .. ")", col)
	else
		setStatus("❌ No se pudo enviar el comando", Color3.fromRGB(255, 60, 60))
	end
end

local function withTarget(fn)
	local t = S.target
	if not t or t.Parent ~= Players then
		setStatus("⚠️ Selecciona un jugador primero", NARANJA)
		return
	end
	fn(t)
end

------------------------------------------------------------
-- Efectos persistentes (warp / blur): se reaplican al reaparecer
------------------------------------------------------------
local EFECTOS = {
	warp = { on = ";warp %s",     off = ";unwarp %s" },
	blur = { on = ";blur %s 50",  off = ";unblur %s" },
}

local perm = {}   -- conexiones permanentes
local function permConn(c) table.insert(perm, c); return c end

local function reaplicarEfectos(p)
	task.wait(1.5)
	if not S.running then return end
	if S.warp[p.Name] then enviar(EFECTOS.warp.on:format(p.Name)) end
	if S.blur[p.Name] then enviar(EFECTOS.blur.on:format(p.Name)) end
end
local function vigilar(p)
	permConn(p.CharacterAdded:Connect(function()
		task.spawn(reaplicarEfectos, p)
	end))
end
for _, p in ipairs(Players:GetPlayers()) do vigilar(p) end
permConn(Players.PlayerAdded:Connect(function(p)
	vigilar(p)
	task.defer(function() refreshFn() end)
end))
permConn(Players.PlayerRemoving:Connect(function(p)
	if S.target == p then S.target = nil end
	task.defer(function() refreshFn(); syncUI() end)
end))

------------------------------------------------------------
-- Kill loop
------------------------------------------------------------
local function detenerKillLoop(msg)
	S.killLoop = false
	S.killName = nil
	syncUI()
	if msg then setStatus(msg, GRIS) end
end

local function iniciarKillLoop(p)
	local nombre = p.Name
	S.killLoop = true
	S.killName = nombre
	syncUI()
	setStatus("🔁 Matando a " .. nombre .. " en bucle", Color3.fromRGB(255, 80, 80))
	task.spawn(function()
		while S.running and S.killLoop and S.killName == nombre do
			if not Players:FindFirstChild(nombre) then
				detenerKillLoop("⏹ " .. nombre .. " salió del servidor")
				break
			end
			enviar(";kill " .. nombre)
			task.wait(1.5)
		end
	end)
end

------------------------------------------------------------
-- Troll continuo
------------------------------------------------------------
-- %s = nombre del jugador. ;char va primero porque reaparece al jugador.
local TROLL_CMDS = {
	";char %s 1",
	";jumpHeight %s 0",
	";blur %s 50",
	";hideGuis %s",
	";clearHats %s",
}

local function detenerTroll(msg)
	S.troll = false
	S.trollTarget = nil
	syncUI()
	if msg then setStatus(msg, GRIS) end
end

local function iniciarTroll(p)
	S.troll = true
	S.trollTarget = p
	syncUI()
	setStatus("🎭 Troll continuo sobre " .. p.Name, Color3.fromRGB(255, 100, 200))
	task.spawn(function()
		local lastChar, lastApply = nil, 0
		while S.running and S.troll and S.trollTarget == p do
			if p.Parent ~= Players then
				detenerTroll("⏹ " .. p.Name .. " salió del servidor")
				break
			end
			local char = p.Character
			local respawned = char and char ~= lastChar and char:FindFirstChildOfClass("Humanoid")
			if respawned or (os.clock() - lastApply) > 15 then
				if respawned then task.wait(1.5) end
				lastApply = os.clock()
				for _, fmt in ipairs(TROLL_CMDS) do
					if not (S.troll and S.trollTarget == p) then break end
					enviar(fmt:format(p.Name))
					task.wait(fmt:find(";char", 1, true) and 3 or 0.5)
				end
				lastChar = p.Character
			end
			task.wait(0.5)
		end
	end)
end

------------------------------------------------------------
-- Interfaz
------------------------------------------------------------
local gui = nil
local conns = {}
local function track(c) table.insert(conns, c); return c end

local function limpiar()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	if gui then pcall(function() gui:Destroy() end) end
	gui = nil
end

local function construir()
	for i = #syncs, 1, -1 do syncs[i] = nil end

	local cam = workspace.CurrentCamera
	local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
	local PANEL_W = 260
	local PANEL_H = math.clamp(vp.Y - 40, 380, 540)

	local C_BG   = Color3.fromRGB(10, 8, 8)
	local C_ROW  = Color3.fromRGB(22, 12, 12)
	local C_SEL  = Color3.fromRGB(110, 20, 20)
	local C_TEXT = Color3.fromRGB(255, 220, 220)

	gui = mk("ScreenGui", {
		Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = MAX_ORDER,
	}, guiParent)
	pcall(function() gui.OnTopOfCoreGui = true end)

	-- Botón flotante (arrastrable) + panel -------------------
	local fab = mk("TextButton", {
		Size = UDim2.fromOffset(50, 50),
		Position = S.fabPos and UDim2.fromOffset(S.fabPos.X, S.fabPos.Y) or UDim2.new(1, -64, 0, 70),
		BackgroundColor3 = Color3.fromRGB(80, 0, 0),
		Text = "⚙️", TextColor3 = Color3.fromRGB(255, 80, 80),
		TextSize = 22, Font = Enum.Font.GothamBold,
		BorderSizePixel = 0, ZIndex = 30, AutoButtonColor = false,
	}, gui)
	corner(25, fab)
	mk("UIStroke", {Thickness = 2, Color = Color3.fromRGB(200, 0, 0)}, fab)

	local panel = mk("Frame", {
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		Position = S.panelPos and UDim2.fromOffset(S.panelPos.X, S.panelPos.Y)
			or UDim2.new(1, -PANEL_W - 70, 0, 20),
		BackgroundColor3 = C_BG, BorderSizePixel = 0,
		Visible = false, ZIndex = 20, Active = true,
	}, gui)
	corner(14, panel)
	mk("UIStroke", {Thickness = 1.5, Color = Color3.fromRGB(180, 0, 0)}, panel)

	local titleBar = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(120, 0, 0),
		BorderSizePixel = 0, ZIndex = 21,
	}, panel)
	corner(14, titleBar)
	mk("TextLabel", {
		Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1, Text = "⚙️ PANEL 2",
		TextColor3 = Color3.fromRGB(255, 200, 200),
		TextSize = 13, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	}, titleBar)
	local closeBtn = mk("TextButton", {
		Size = UDim2.fromOffset(30, 24), Position = UDim2.new(1, -36, 0.5, -12),
		BackgroundColor3 = Color3.fromRGB(160, 0, 0),
		Text = "✕", TextColor3 = Color3.new(1, 1, 1),
		TextSize = 12, Font = Enum.Font.GothamBold,
		BorderSizePixel = 0, ZIndex = 23,
	}, titleBar)
	corner(6, closeBtn)

	local function setPanel(v)
		S.panelOpen = v
		panel.Visible = v
		fab.TextColor3 = v and Color3.fromRGB(255, 255, 100) or Color3.fromRGB(255, 80, 80)
	end
	closeBtn.Activated:Connect(function() setPanel(false) end)

	-- Esfera arrastrable: toque corto abre/cierra, arrastrar la mueve
	local fDrag, fStart, fOrigin, fMoved = false, nil, nil, false
	fab.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1 then
			fDrag, fMoved = true, false
			fStart, fOrigin = i.Position, fab.AbsolutePosition
		end
	end)
	track(UIS.InputChanged:Connect(function(i)
		if not fDrag then return end
		if i.UserInputType ~= Enum.UserInputType.Touch
			and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local d = i.Position - fStart
		if d.Magnitude > 8 then fMoved = true end
		if fMoved then
			local sc = gui.AbsoluteSize
			local x = math.clamp(fOrigin.X + d.X, 0, math.max(0, sc.X - 50))
			local y = math.clamp(fOrigin.Y + d.Y, 0, math.max(0, sc.Y - 50))
			fab.Position = UDim2.fromOffset(x, y)
			S.fabPos = Vector2.new(x, y)
		end
	end))
	track(UIS.InputEnded:Connect(function(i)
		if not fDrag then return end
		if i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1 then
			fDrag = false
			if not fMoved then setPanel(not panel.Visible) end
		end
	end))

	-- Arrastrar el panel desde la barra de título
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = i.Position
			startPos = panel.AbsolutePosition
		end
	end)
	track(UIS.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType ~= Enum.UserInputType.Touch
			and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local d = i.Position - dragStart
		local sc = gui.AbsoluteSize
		local x = math.clamp(startPos.X + d.X, 0, math.max(0, sc.X - PANEL_W))
		local y = math.clamp(startPos.Y + d.Y, 0, math.max(0, sc.Y - PANEL_H))
		panel.Position = UDim2.fromOffset(x, y)
		S.panelPos = Vector2.new(x, y)
	end))
	track(UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end))

	-- Barra de estado (fija abajo, siempre visible) -----------
	local statusLbl = mk("TextLabel", {
		Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 1, -24),
		BackgroundTransparency = 1, Text = "Listo",
		TextColor3 = Color3.fromRGB(200, 150, 150),
		TextSize = 11, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22,
	}, panel)
	local statusToken = 0
	statusFn = function(txt, col)
		statusToken = statusToken + 1
		local my = statusToken
		statusLbl.Text = txt
		statusLbl.TextColor3 = col or Color3.fromRGB(255, 120, 120)
		task.delay(4, function()
			if my == statusToken and statusLbl.Parent then statusLbl.Text = "" end
		end)
	end

	-- Selector de jugador (fijo arriba) -----------------------
	local targetLbl = mk("TextLabel", {
		Size = UDim2.new(1, -12, 0, 18), Position = UDim2.fromOffset(6, 38),
		BackgroundTransparency = 1, Text = "🎯 Seleccionado: —",
		TextColor3 = Color3.fromRGB(255, 160, 160),
		TextSize = 11, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	}, panel)

	local plScroll = mk("ScrollingFrame", {
		Size = UDim2.new(1, -12, 0, 120), Position = UDim2.fromOffset(6, 58),
		BackgroundColor3 = Color3.fromRGB(16, 10, 10), BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(180, 0, 0),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = 22,
	}, panel)
	corner(7, plScroll)
	mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, plScroll)
	mk("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3),
		PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 3)}, plScroll)

	local function selectPlayer(p)
		S.target = p
		targetLbl.Text = p and ("🎯 Seleccionado: " .. p.Name) or "🎯 Seleccionado: —"
		for _, c in ipairs(plScroll:GetChildren()) do
			if c:IsA("TextButton") then
				c.BackgroundColor3 = (p and c.Name == tostring(p.UserId)) and C_SEL or C_ROW
			end
		end
		syncUI()
	end

	local function refreshPlayers()
		if not plScroll.Parent then return 0 end
		for _, c in ipairs(plScroll:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
		end

		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Parent == Players then table.insert(list, p) end
		end
		table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)
		table.insert(list, 1, player)  -- tú primero (para fly / noclip / speed)

		if S.target and S.target.Parent ~= Players then S.target = nil end
		targetLbl.Text = S.target and ("🎯 Seleccionado: " .. S.target.Name) or "🎯 Seleccionado: —"

		for idx, p in ipairs(list) do
			local base = (p.DisplayName ~= p.Name)
				and (p.DisplayName .. " (@" .. p.Name .. ")") or p.Name
			local label = (p == player) and ("  ⭐ Yo — " .. base) or ("  👤 " .. base)
			local pb = mk("TextButton", {
				Name = tostring(p.UserId), LayoutOrder = idx,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = (S.target == p) and C_SEL or C_ROW,
				Text = label, TextColor3 = Color3.fromRGB(230, 200, 200),
				TextSize = 11, Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				BorderSizePixel = 0, ZIndex = 24,
			}, plScroll)
			corner(5, pb)
			pb.Activated:Connect(function()
				selectPlayer(p)
				setStatus("✅ " .. p.Name .. " seleccionado", Color3.fromRGB(255, 160, 160))
			end)
		end
		return #list - 1
	end
	refreshFn = refreshPlayers

	local refreshBtn = mk("TextButton", {
		Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 182),
		BackgroundColor3 = Color3.fromRGB(50, 20, 20),
		Text = "🔄  Actualizar lista", TextColor3 = C_TEXT,
		TextSize = 11, Font = Enum.Font.GothamBold,
		BorderSizePixel = 0, ZIndex = 22,
	}, panel)
	corner(7, refreshBtn)
	refreshBtn.Activated:Connect(function()
		local n = refreshPlayers()
		setStatus("✅ Lista actualizada — " .. n .. " jugador(es)", Color3.fromRGB(200, 150, 150))
	end)

	-- Zona de acciones (único ScrollingFrame grande) ----------
	local ACTIONS_Y = 216
	local scroll = mk("ScrollingFrame", {
		Size = UDim2.new(1, -12, 0, PANEL_H - ACTIONS_Y - 28),
		Position = UDim2.fromOffset(6, ACTIONS_Y),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(180, 0, 0),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = 21,
	}, panel)
	mk("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
	mk("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6)}, scroll)

	local order = 0
	local function nextOrder() order = order + 1; return order end

	local function mkDiv(txt)
		mk("TextLabel", {
			LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1, Text = txt,
			TextColor3 = Color3.fromRGB(200, 40, 40), TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
		}, scroll)
	end
	local function mkInfo(txt)
		mk("TextLabel", {
			LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1, Text = txt,
			TextColor3 = Color3.fromRGB(200, 120, 120), TextSize = 10,
			Font = Enum.Font.Gotham, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
		}, scroll)
	end
	local function mkBtn(icon, label, color, onClick)
		local btn = mk("TextButton", {
			LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = color or Color3.fromRGB(60, 10, 10),
			Text = icon .. "  " .. label, TextColor3 = C_TEXT,
			TextSize = 12, Font = Enum.Font.GothamBold,
			BorderSizePixel = 0, ZIndex = 22,
		}, scroll)
		corner(8, btn)
		btn.Activated:Connect(function() task.spawn(onClick) end)
		return btn
	end
	local function accion(icon, label, fmt, okTxt, color)
		return mkBtn(icon, label, color, function()
			withTarget(function(t)
				run(fmt:format(t.Name), icon .. " " .. okTxt .. " → " .. t.Name)
			end)
		end)
	end
	local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

	-- Moderación ---------------------------------------------
	mkDiv("── 🚫 MODERACIÓN (HD Admin) ──")
	mkInfo("Solo funciona si TU rango en HD Admin permite estos comandos.")
	accion("🚫", "Quitar admin", ";unadmin %s", "unadmin", rgb(140, 0, 0))
	mkBtn("🚫", "Degradar (varios rangos)", rgb(120, 0, 0), function()
		withTarget(function(t)
			for _, cmd in ipairs({"unadmin", "unmod", "unowner", "unheadadmin"}) do
				enviar(";" .. cmd .. " " .. t.Name)
				task.wait(0.4)
			end
			setStatus("🚫 Rangos removidos → " .. t.Name)
		end)
	end)
	accion("🔨", "Kick (expulsar)", ";kick %s", "expulsado", rgb(100, 30, 0))

	-- Combate -------------------------------------------------
	mkDiv("── ⚡ COMBATE ──")
	accion("💀", "Matar", ";kill %s", "eliminado", rgb(100, 0, 0))

	local klBtn = mkBtn("🔁", "Kill Loop: OFF", rgb(100, 0, 0), function()
		if S.killLoop then
			detenerKillLoop("⏹ Kill loop detenido")
		else
			withTarget(iniciarKillLoop)
		end
	end)
	table.insert(syncs, function()
		if S.killLoop then
			klBtn.Text = "🔁  Kill Loop: ON → " .. tostring(S.killName)
			klBtn.BackgroundColor3 = rgb(180, 0, 0)
		else
			klBtn.Text = "🔁  Kill Loop: OFF"
			klBtn.BackgroundColor3 = rgb(100, 0, 0)
		end
	end)

	accion("🔄", "Respawnear", ";respawn %s", "respawn", rgb(30, 70, 30))
	accion("🛡", "Dar escudo (ff)", ";ff %s", "escudo", rgb(20, 60, 140))
	accion("🔓", "Quitar escudo (unff)", ";unff %s", "sin escudo", rgb(90, 40, 0))
	accion("💥", "Fling", ";fling %s", "fling", rgb(160, 40, 0))

	-- Efectos de vista persistentes --------------------------
	mkDiv("── 👁️ EFECTOS DE VISTA ──")
	mkInfo("Warp y Blur se mantienen aunque el jugador muera y reaparezca.")

	local function mkEfecto(icon, label, key, colorOn, colorOff)
		local btn
		btn = mkBtn(icon, label .. ": OFF", colorOff, function()
			withTarget(function(t)
				local tabla = S[key]
				if tabla[t.Name] then
					tabla[t.Name] = nil
					enviar(EFECTOS[key].off:format(t.Name))
					setStatus("⏹ " .. label .. " desactivado → " .. t.Name, GRIS)
				else
					tabla[t.Name] = true
					enviar(EFECTOS[key].on:format(t.Name))
					setStatus("✅ " .. label .. " activado → " .. t.Name .. " (persistente)",
						rgb(180, 100, 255))
				end
				syncUI()
			end)
		end)
		table.insert(syncs, function()
			local on = S.target and S[key][S.target.Name]
			btn.Text = icon .. "  " .. label .. ": " .. (on and "ON" or "OFF")
			btn.BackgroundColor3 = on and colorOn or colorOff
		end)
	end
	mkEfecto("🙈", "Cegar (Warp)", "warp", rgb(150, 0, 80), rgb(60, 10, 40))
	mkEfecto("🌀", "Mareo (Blur)", "blur", rgb(0, 100, 150), rgb(10, 50, 60))
	accion("🧼", "Ocultar sus paneles (hideGuis)", ";hideGuis %s", "paneles ocultos", rgb(100, 20, 60))
	accion("🧾", "Devolver paneles (showGuis)", ";showGuis %s", "paneles devueltos", rgb(30, 60, 30))

	-- Movimiento ----------------------------------------------
	mkDiv("── 🏃 MOVIMIENTO ──")
	mkInfo("Para fly / noclip / speed en ti mismo, selecciona ⭐ Yo.")
	accion("🧲", "Traer a mí (bring)", ";bring %s", "traído", rgb(60, 20, 120))
	accion("🌀", "Ir a él (tp)", ";tp me %s", "teletransportado", rgb(40, 20, 100))
	accion("🚀", "Volar (fly)", ";fly %s", "fly", rgb(30, 60, 160))
	accion("🛬", "Quitar vuelo (unfly)", ";unfly %s", "sin fly", rgb(50, 25, 0))
	accion("👻", "Noclip", ";noclip2 %s", "noclip", rgb(35, 35, 80))
	accion("🧱", "Quitar noclip", ";unnoclip2 %s", "sin noclip", rgb(35, 35, 45))
	accion("⚡", "Velocidad alta (50)", ";speed %s 50", "velocidad 50", rgb(80, 60, 0))
	accion("🐌", "Velocidad normal (16)", ";speed %s 16", "velocidad 16", rgb(35, 35, 45))
	accion("⛔", "No poder saltar", ";jumpHeight %s 0", "salto bloqueado", rgb(110, 40, 0))
	accion("✅", "Restaurar salto", ";jumpHeight %s 7.2", "salto restaurado", rgb(30, 60, 30))
	accion("🪑", "Sentar", ";sit %s", "sentado", rgb(70, 50, 40))
	accion("🌀", "Girar (spin)", ";spin %s 50", "girando", rgb(60, 30, 80))
	accion("🛑", "Dejar de girar (unspin)", ";unspin %s", "sin girar", rgb(35, 35, 45))
	accion("🦘", "Hacerlo saltar", ";jump %s", "salto", rgb(40, 60, 30))

	-- Apariencia ----------------------------------------------
	mkDiv("── 🎭 APARIENCIA ──")
	accion("🧍", "Quitar skin (char → noob)", ";char %s 1", "skin cambiada", rgb(80, 30, 60))
	accion("🧢", "Quitar accesorios", ";clearHats %s", "accesorios fuera", rgb(80, 50, 20))
	accion("👻", "Invisible", ";invisible %s", "invisible", rgb(50, 50, 80))
	accion("👁️", "Hacer visible", ";visible %s", "visible", rgb(30, 60, 30))
	accion("🫥", "Fantasma (ghost)", ";ghost %s", "fantasma", rgb(40, 50, 70))
	accion("🔥", "Fuego", ";fire %s", "fuego", rgb(120, 40, 0))
	accion("💨", "Humo", ";smoke %s", "humo", rgb(60, 60, 60))
	accion("✨", "Brillos (sparkles)", ";sparkles %s", "brillos", rgb(80, 70, 20))
	accion("🥇", "Dorado (gold)", ";gold %s", "dorado", rgb(100, 80, 0))
	accion("🙈", "Ocultar su nombre", ";hideName %s", "nombre oculto", rgb(60, 40, 60))
	accion("🦵", "Piernas gigantes (hipHeight)", ";hipHeight %s 10", "hipHeight", rgb(40, 60, 60))

	-- Comando libre -------------------------------------------
	mkDiv("── ⌨️ COMANDO LIBRE ──")
	local cmdBox = mk("TextBox", {
		LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Color3.fromRGB(25, 15, 15),
		PlaceholderText = "Ej: ;name {p} Pollito", Text = "",
		PlaceholderColor3 = Color3.fromRGB(140, 100, 100),
		TextColor3 = C_TEXT, TextSize = 12, Font = Enum.Font.Gotham,
		ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 22,
	}, scroll)
	corner(7, cmdBox)
	mkBtn("▶️", "Enviar comando libre", rgb(60, 30, 30), function()
		withTarget(function(t)
			local c = cmdBox.Text:gsub("{p}", t.Name)
			if c == "" then setStatus("⚠️ Escribe un comando", NARANJA); return end
			run(c, "▶️ " .. c)
		end)
	end)

	-- Troll continuo -----------------------------------------
	mkDiv("── 🎭 TROLL CONTINUO ──")
	mkInfo("Reaplica skin, salto, ceguera y paneles al reaparecer y cada 15 s.")
	local trollBtn = mkBtn("🎭", "Troll continuo: OFF", rgb(100, 0, 60), function()
		if S.troll then
			detenerTroll("⏹ Troll detenido")
		else
			withTarget(iniciarTroll)
		end
	end)
	table.insert(syncs, function()
		if S.troll and S.trollTarget then
			trollBtn.Text = "🎭  Troll continuo: ON → " .. S.trollTarget.Name
			trollBtn.BackgroundColor3 = rgb(180, 0, 100)
		else
			trollBtn.Text = "🎭  Troll continuo: OFF"
			trollBtn.BackgroundColor3 = rgb(100, 0, 60)
		end
	end)

	-- Apagar --------------------------------------------------
	mkDiv("── ⏻ SCRIPT ──")
	mkBtn("⏻", "Apagar script (quitar panel)", rgb(70, 0, 0), function()
		S.running = false
		S.killLoop = false
		S.troll = false
		for _, c in ipairs(perm) do pcall(function() c:Disconnect() end) end
		limpiar()
	end)

	refreshPlayers()
	syncUI()
	setPanel(S.panelOpen)
end

------------------------------------------------------------
-- Inicio + vigilante anti-borrado
------------------------------------------------------------
construir()

task.spawn(function()
	while S.running do
		task.wait(0.5)
		if not S.running then break end
		if not gui or gui.Parent == nil then
			-- Alguien borró el panel: lo reconstruimos igual que estaba
			limpiar()
			pcall(construir)
		else
			if gui.Parent ~= guiParent then
				pcall(function() gui.Parent = guiParent end)
			end
			if gui.DisplayOrder ~= MAX_ORDER then gui.DisplayOrder = MAX_ORDER end
			if not gui.Enabled then gui.Enabled = true end
		end
	end
end)

print("✅ Panel 2 cargado | toca ⚙️ para abrir")
