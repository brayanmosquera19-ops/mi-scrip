-- Admin Revoker (versión corregida)
local Players          = game:GetService("Players")
local UIS              = game:GetService("UserInputService")
local RS               = game:GetService("ReplicatedStorage")
local TextChatService  = game:GetService("TextChatService")
local player           = Players.LocalPlayer

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

-- Padre del GUI (PlayerGui, o gethui si existe)
local guiParent
pcall(function() if gethui then guiParent = gethui() end end)
guiParent = guiParent or player:WaitForChild("PlayerGui")

-- Borrar versión anterior si se ejecuta dos veces
pcall(function()
	local old = guiParent:FindFirstChild("AdminRevoker")
	if old then old:Destroy() end
end)

local gui = mk("ScreenGui", {
	Name = "AdminRevoker",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999,
}, guiParent)

------------------------------------------------------------
-- Medidas
------------------------------------------------------------
local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
local PANEL_W = 260
local PANEL_H = math.clamp(vp.Y - 40, 380, 540)

local C_BG     = Color3.fromRGB(10, 8, 8)
local C_ROW    = Color3.fromRGB(22, 12, 12)
local C_SEL    = Color3.fromRGB(110, 20, 20)
local C_TEXT   = Color3.fromRGB(255, 220, 220)

------------------------------------------------------------
-- Botón flotante + panel
------------------------------------------------------------
local fab = mk("TextButton", {
	Size = UDim2.fromOffset(50, 50),
	Position = UDim2.new(1, -64, 0, 8), -- << CAMBIO: arriba a la derecha (antes 0, 80)
	BackgroundColor3 = Color3.fromRGB(80, 0, 0),
	Text = "🚫", TextColor3 = Color3.fromRGB(255, 80, 80),
	TextSize = 22, Font = Enum.Font.GothamBold,
	BorderSizePixel = 0, ZIndex = 30, AutoButtonColor = true,
}, gui)
corner(25, fab)
mk("UIStroke", {Thickness = 2, Color = Color3.fromRGB(200, 0, 0)}, fab)

local panel = mk("Frame", {
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	Position = UDim2.new(1, -PANEL_W - 70, 0, 20),
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
	BackgroundTransparency = 1, Text = "🚫 ADMIN REVOKER",
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
	panel.Visible = v
	fab.TextColor3 = v and Color3.fromRGB(255, 255, 100) or Color3.fromRGB(255, 80, 80)
end
fab.Activated:Connect(function() setPanel(not panel.Visible) end)
closeBtn.Activated:Connect(function() setPanel(false) end)

-- Arrastrar desde la barra de título (mouse y táctil)
local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch
		or i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = i.Position
		startPos = panel.AbsolutePosition
	end
end)
UIS.InputChanged:Connect(function(i)
	if not dragging then return end
	if i.UserInputType ~= Enum.UserInputType.Touch
		and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	local d = i.Position - dragStart
	local sc = gui.AbsoluteSize
	panel.Position = UDim2.fromOffset(
		math.clamp(startPos.X + d.X, 0, math.max(0, sc.X - PANEL_W)),
		math.clamp(startPos.Y + d.Y, 0, math.max(0, sc.Y - PANEL_H)))
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch
		or i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

------------------------------------------------------------
-- Barra de estado (fija abajo, siempre visible)
------------------------------------------------------------
local statusLbl = mk("TextLabel", {
	Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 1, -24),
	BackgroundTransparency = 1, Text = "Listo",
	TextColor3 = Color3.fromRGB(200, 150, 150),
	TextSize = 11, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22,
}, panel)

local statusToken = 0
local function setStatus(txt, col)
	statusToken += 1
	local my = statusToken
	statusLbl.Text = txt
	statusLbl.TextColor3 = col or Color3.fromRGB(255, 120, 120)
	task.delay(4, function()
		if my == statusToken and statusLbl.Parent then statusLbl.Text = "" end
	end)
end

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

------------------------------------------------------------
-- Selector de jugador (fijo arriba, sin ScrollingFrame anidado)
------------------------------------------------------------
local targetPlayer = nil

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
	ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(180, 0, 0),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 22,
}, panel)
corner(7, plScroll)
mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.Name}, plScroll)
mk("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 3)}, plScroll)

local function selectPlayer(p)
	targetPlayer = p
	targetLbl.Text = p and ("🎯 Seleccionado: " .. p.Name) or "🎯 Seleccionado: —"
	for _, c in ipairs(plScroll:GetChildren()) do
		if c:IsA("TextButton") then
			c.BackgroundColor3 = (p and c.Name == tostring(p.UserId)) and C_SEL or C_ROW
		end
	end
end

local function refreshPlayers()
	for _, c in ipairs(plScroll:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
	end

	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)

	-- Si el seleccionado ya se fue, limpiar
	if targetPlayer and targetPlayer.Parent ~= Players then
		targetPlayer = nil
		targetLbl.Text = "🎯 Seleccionado: —"
	end

	for _, p in ipairs(list) do
		local label = (p.DisplayName ~= p.Name)
			and ("  👤 " .. p.DisplayName .. " (@" .. p.Name .. ")")
			or ("  👤 " .. p.Name)
		local pb = mk("TextButton", {
			Name = tostring(p.UserId),
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = (targetPlayer == p) and C_SEL or C_ROW,
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

	if #list == 0 then
		mk("TextLabel", {
			Name = "empty", Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1, Text = "Sin otros jugadores",
			TextColor3 = Color3.fromRGB(150, 100, 100),
			TextSize = 11, Font = Enum.Font.Gotham, ZIndex = 24,
		}, plScroll)
	end
	return #list
end

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

Players.PlayerAdded:Connect(function() refreshPlayers() end)
Players.PlayerRemoving:Connect(function(p)
	task.defer(refreshPlayers)
end)

------------------------------------------------------------
-- Zona de acciones (único ScrollingFrame grande)
------------------------------------------------------------
local ACTIONS_Y = 216
local scroll = mk("ScrollingFrame", {
	Size = UDim2.new(1, -12, 0, PANEL_H - ACTIONS_Y - 28),
	Position = UDim2.fromOffset(6, ACTIONS_Y),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(180, 0, 0),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 21,
}, panel)
mk("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
mk("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6)}, scroll)

local order = 0
local function nextOrder() order += 1; return order end

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

local function withTarget(fn)
	if not targetPlayer or targetPlayer.Parent ~= Players then
		setStatus("⚠️ Selecciona un jugador primero", Color3.fromRGB(255, 160, 0))
		return
	end
	fn(targetPlayer)
end

-- Ejecuta un comando y avisa si realmente se pudo enviar
local function run(cmd, okText, col)
	local via = enviar(cmd)
	if via then
		setStatus(okText .. "  (" .. via .. ")", col)
	else
		setStatus("❌ No se pudo enviar el comando", Color3.fromRGB(255, 60, 60))
	end
end

------------------------------------------------------------
-- Moderación
------------------------------------------------------------
mkDiv("── 🚫 MODERACIÓN (HD Admin) ──")
mkInfo("Solo funciona si TU rango en HD Admin permite estos comandos.")

mkBtn("🚫", "Quitar admin", Color3.fromRGB(140, 0, 0), function()
	withTarget(function(t) run(";unadmin " .. t.Name, "🚫 unadmin → " .. t.Name) end)
end)

mkBtn("🚫", "Degradar (varios rangos)", Color3.fromRGB(120, 0, 0), function()
	withTarget(function(t)
		for _, cmd in ipairs({"unadmin", "unmod", "unowner", "unheadadmin"}) do
			enviar(";" .. cmd .. " " .. t.Name)
			task.wait(0.4)
		end
		setStatus("🚫 Rangos removidos → " .. t.Name)
	end)
end)

mkBtn("🔨", "Kick (expulsar)", Color3.fromRGB(100, 30, 0), function()
	withTarget(function(t) run(";kick " .. t.Name, "🔨 " .. t.Name .. " expulsado", Color3.fromRGB(255, 140, 0)) end)
end)

mkBtn("⛔", "Bloquear salto", Color3.fromRGB(110, 40, 0), function()
	withTarget(function(t) run(";jumpHeight " .. t.Name .. " 0", "⛔ Salto bloqueado → " .. t.Name, Color3.fromRGB(255, 140, 0)) end)
end)

mkBtn("✅", "Restaurar salto", Color3.fromRGB(30, 60, 30), function()
	withTarget(function(t) run(";jumpHeight " .. t.Name .. " 7.2", "✅ Salto restaurado → " .. t.Name, Color3.fromRGB(100, 200, 100)) end)
end)

------------------------------------------------------------
-- Control
------------------------------------------------------------
mkDiv("── ⚡ CONTROL ──")

mkBtn("💀", "Matar", Color3.fromRGB(100, 0, 0), function()
	withTarget(function(t) run(";kill " .. t.Name, "💀 " .. t.Name .. " eliminado") end)
end)


------------------------------------------------------------
-- Kill loop
------------------------------------------------------------
mkDiv("── 🔁 KILL LOOP ──")

local killLoopOn = false
local klBtn
klBtn = mkBtn("🔁", "Kill Loop: OFF", Color3.fromRGB(100, 0, 0), function()
	if killLoopOn then
		killLoopOn = false
		klBtn.Text = "🔁  Kill Loop: OFF"
		klBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
		setStatus("⏹ Kill loop detenido", Color3.fromRGB(150, 150, 170))
		return
	end
	if not targetPlayer or targetPlayer.Parent ~= Players then
		setStatus("⚠️ Selecciona un jugador primero", Color3.fromRGB(255, 160, 0))
		return
	end
	killLoopOn = true
	local nombre = targetPlayer.Name
	klBtn.Text = "🔁  Kill Loop: ON → " .. nombre
	klBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
	setStatus("🔁 Matando a " .. nombre .. " en bucle")
	while killLoopOn do
		if not Players:FindFirstChild(nombre) then
			killLoopOn = false
			klBtn.Text = "🔁  Kill Loop: OFF"
			klBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
			setStatus("⏹ " .. nombre .. " salió del servidor", Color3.fromRGB(150, 150, 170))
			break
		end
		enviar(";kill " .. nombre)
		task.wait(1.5)
	end
end)

------------------------------------------------------------
-- Troll (comandos reales de TU HD Admin, según tu lista)
------------------------------------------------------------
-- Se aplican en este orden sobre el jugador elegido en el modo continuo.
-- (%s = nombre del jugador). ;char va primero porque reaparece al jugador.
local TROLL_CMDS = {
	";char %s 1",           -- quita su skin (usa el avatar del userId 1)
	";jumpHeight %s 0",     -- no puede saltar
	";blur %s 50",          -- pantalla borrosa (casi ciego)
	";hideGuis %s",         -- le oculta los paneles/GUI de su pantalla
	";clearHats %s",        -- quita accesorios
}

local function accion(icon, label, fmt, okTxt, color)
	mkBtn(icon, label, color, function()
		withTarget(function(t)
			run(fmt:format(t.Name), icon .. " " .. okTxt .. " → " .. t.Name)
		end)
	end)
end

mkDiv("── 👁️ CEGAR / PANELES ──")
accion("🕶️", "Cegar (blur fuerte)", ";blur %s 50", "Cegado", Color3.fromRGB(40, 40, 40))
accion("👁️", "Quitar ceguera", ";blur %s 0", "Ceguera quitada", Color3.fromRGB(30, 60, 30))
accion("🧼", "Ocultar sus paneles (hideGuis)", ";hideGuis %s", "Paneles ocultos", Color3.fromRGB(100, 20, 60))
accion("🧾", "Devolver paneles (showGuis)", ";showGuis %s", "Paneles devueltos", Color3.fromRGB(30, 60, 30))

mkDiv("── 🏃 MOVIMIENTO ──")
accion("⛔", "No poder saltar", ";jumpHeight %s 0", "Salto bloqueado", Color3.fromRGB(110, 40, 0))
accion("✅", "Restaurar salto", ";jumpHeight %s 7.2", "Salto restaurado", Color3.fromRGB(30, 60, 30))
accion("🐌", "Lento (slow)", ";slow %s", "Lento", Color3.fromRGB(70, 50, 20))
accion("⚡", "Rápido (fast)", ";fast %s", "Rápido", Color3.fromRGB(20, 60, 70))
accion("🌀", "Girar (spin)", ";spin %s 50", "Girando", Color3.fromRGB(60, 30, 80))
accion("🪑", "Sentar", ";sit %s", "Sentado", Color3.fromRGB(70, 50, 40))
accion("🦘", "Hacerlo saltar", ";jump %s", "Salto", Color3.fromRGB(40, 60, 30))
accion("📍", "Teletransportar (warp)", ";warp %s", "Warp", Color3.fromRGB(30, 40, 80))

mkDiv("── 🎭 APARIENCIA ──")
accion("🧍", "Quitar skin (char → noob)", ";char %s 1", "Skin cambiada", Color3.fromRGB(80, 30, 60))
accion("🧢", "Quitar accesorios", ";clearHats %s", "Accesorios fuera", Color3.fromRGB(80, 50, 20))
accion("👻", "Invisible", ";invisible %s", "Invisible", Color3.fromRGB(50, 50, 80))
accion("🫥", "Fantasma (ghost)", ";ghost %s", "Fantasma", Color3.fromRGB(40, 50, 70))
accion("🔥", "Fuego", ";fire %s", "Fuego", Color3.fromRGB(120, 40, 0))
accion("💨", "Humo", ";smoke %s", "Humo", Color3.fromRGB(60, 60, 60))
accion("✨", "Brillos (sparkles)", ";sparkles %s", "Brillos", Color3.fromRGB(80, 70, 20))
accion("🥇", "Dorado (gold)", ";gold %s", "Dorado", Color3.fromRGB(100, 80, 0))
accion("🙈", "Ocultar su nombre", ";hideName %s", "Nombre oculto", Color3.fromRGB(60, 40, 60))
accion("🦵", "Piernas gigantes (hipHeight)", ";hipHeight %s 10", "hipHeight", Color3.fromRGB(40, 60, 60))

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
mkBtn("▶️", "Enviar comando libre", Color3.fromRGB(60, 30, 30), function()
	withTarget(function(t)
		local c = cmdBox.Text:gsub("{p}", t.Name)
		if c == "" then setStatus("⚠️ Escribe un comando", Color3.fromRGB(255, 160, 0)); return end
		run(c, "▶️ " .. c)
	end)
end)

mkDiv("── 🎭 TROLL CONTINUO ──")
mkInfo("Reaplica todo (skin, salto, ceguera, paneles) al reaparecer y cada 15 s.")

local trollOn = false
local trollBtn
local function trollOff(msg)
	trollOn = false
	trollBtn.Text = "🎭  Troll continuo: OFF"
	trollBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 60)
	setStatus(msg, Color3.fromRGB(150, 150, 170))
end
trollBtn = mkBtn("🎭", "Troll continuo: OFF", Color3.fromRGB(100, 0, 60), function()
	if trollOn then trollOff("⏹ Troll detenido"); return end
	if not targetPlayer or targetPlayer.Parent ~= Players then
		setStatus("⚠️ Selecciona un jugador primero", Color3.fromRGB(255, 160, 0))
		return
	end
	trollOn = true
	local t = targetPlayer
	trollBtn.Text = "🎭  Troll continuo: ON → " .. t.Name
	trollBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 100)
	setStatus("🎭 Troll continuo sobre " .. t.Name, Color3.fromRGB(255, 100, 200))

	local lastChar, lastApply = nil, 0
	while trollOn do
		if t.Parent ~= Players then trollOff("⏹ " .. t.Name .. " salió del servidor"); break end
		local char = t.Character
		local respawned = char and char ~= lastChar and char:FindFirstChildOfClass("Humanoid")
		if respawned or (os.clock() - lastApply) > 15 then
			if respawned then task.wait(1.5) end
			lastApply = os.clock()
			for _, fmt in ipairs(TROLL_CMDS) do
				if not trollOn then break end
				enviar(fmt:format(t.Name))
				-- ;char reaparece al jugador: esperar antes de seguir
				task.wait(fmt:find(";char", 1, true) and 3 or 0.5)
			end
			lastChar = t.Character -- evita bucle infinito por el respawn de ;char
		end
		task.wait(0.5)
	end
end)


------------------------------------------------------------
-- Inicio
------------------------------------------------------------
refreshPlayers()
setPanel(false)
print("✅ Admin Revoker cargado | toca 🚫 para abrir")
