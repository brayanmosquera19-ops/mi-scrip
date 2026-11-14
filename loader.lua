-- Skin Changer (HD Admin ;char) - pausa, etiquetas de nombre, persistencia y vigilancia
local Players          = game:GetService("Players")
local UIS              = game:GetService("UserInputService")
local RS               = game:GetService("ReplicatedStorage")
local TextChatService  = game:GetService("TextChatService")
local player           = Players.LocalPlayer

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local FAB_POS = UDim2.new(1, -120, 1, -220)
local DELAY_ENTRE_COMANDOS = 4.0    -- segundos entre jugadores al aplicar "a todos"
local VIGILANCIA_INTERVALO = 45.0   -- cada cuánto se repasa la lista de protegidos
local VIGILANCIA_ESPACIADO = 15.0   -- espera entre cada jugador protegido dentro de un mismo ciclo

-- ✏️ Comando para poner la etiqueta de nombre (AJUSTA si tu HD Admin usa otro).
-- %s %s = nombre del jugador, texto de la etiqueta
local NICKNAME_SET_CMD   = ";nickname %s %s"
local NICKNAME_RESET_CMD = ";nickname %s %s" -- se usa con el propio nombre para "quitar" la etiqueta

-- ✏️ EDITA AQUÍ tus skins favoritas
local SKINS_FAVORITAS = {
	{apodo = "🤡 Payaso", usuario = "NombreDeUsuarioPayaso"},
	{apodo = "🧙‍♀️ Bruja", usuario = "NombreDeUsuarioBruja"},
	{apodo = "👽 Alien", usuario = "NombreDeUsuarioAlien"},
}

-- ✏️ Etiquetas rápidas que pidieron los chicos (puedes agregar/quitar líneas)
local ETIQUETAS_RAPIDAS = {
	"SOYPRO 😏",
	"QUIERO CONVERSAR 😊",
	"BUSCO AMIGOS 😊",
}

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

local guiParent
pcall(function() if gethui then guiParent = gethui() end end)
guiParent = guiParent or player:WaitForChild("PlayerGui")

pcall(function()
	local old = guiParent:FindFirstChild("SkinChanger")
	if old then old:Destroy() end
end)

local gui = mk("ScreenGui", {
	Name = "SkinChanger", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
}, guiParent)

------------------------------------------------------------
-- Medidas y colores
------------------------------------------------------------
local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
local PANEL_W = 280
local PANEL_H = math.clamp(vp.Y - 40, 420, 580)

local C_BG   = Color3.fromRGB(12, 8, 18)
local C_ROW  = Color3.fromRGB(26, 16, 36)
local C_SEL  = Color3.fromRGB(90, 40, 130)
local C_SEL2 = Color3.fromRGB(40, 90, 130)
local C_TEXT = Color3.fromRGB(240, 225, 255)
local C_LINE = Color3.fromRGB(150, 70, 210)

------------------------------------------------------------
-- Botón flotante + panel
------------------------------------------------------------
local fab = mk("TextButton", {
	Size = UDim2.fromOffset(50, 50), Position = FAB_POS,
	BackgroundColor3 = Color3.fromRGB(70, 30, 110),
	Text = "🧍", TextColor3 = Color3.new(1, 1, 1),
	TextSize = 22, Font = Enum.Font.GothamBold,
	BorderSizePixel = 0, ZIndex = 30,
}, gui)
corner(25, fab)
mk("UIStroke", {Thickness = 2, Color = C_LINE}, fab)

local panel = mk("Frame", {
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	Position = UDim2.new(1, -PANEL_W - 70, 0, 20),
	BackgroundColor3 = C_BG, BorderSizePixel = 0,
	Visible = false, ZIndex = 20, Active = true,
}, gui)
corner(14, panel)
mk("UIStroke", {Thickness = 1.5, Color = C_LINE}, panel)

local titleBar = mk("Frame", {
	Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(100, 40, 150),
	BorderSizePixel = 0, ZIndex = 21,
}, panel)
corner(14, titleBar)
mk("TextLabel", {
	Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(10, 0),
	BackgroundTransparency = 1, Text = "🧍 SKIN CHANGER",
	TextColor3 = Color3.fromRGB(240, 220, 255), TextSize = 13,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
}, titleBar)
local closeBtn = mk("TextButton", {
	Size = UDim2.fromOffset(30, 24), Position = UDim2.new(1, -36, 0.5, -12),
	BackgroundColor3 = Color3.fromRGB(130, 50, 180), Text = "✕",
	TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = Enum.Font.GothamBold,
	BorderSizePixel = 0, ZIndex = 23,
}, titleBar)
corner(6, closeBtn)

local function setPanel(v)
	panel.Visible = v
	fab.TextColor3 = v and Color3.fromRGB(255, 255, 100) or Color3.new(1, 1, 1)
end
fab.Activated:Connect(function() setPanel(not panel.Visible) end)
closeBtn.Activated:Connect(function() setPanel(false) end)

local dragging, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch
		or i.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging, dragStart, startPos = true, i.Position, panel.AbsolutePosition
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
-- Barra de estado
------------------------------------------------------------
local statusLbl = mk("TextLabel", {
	Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 1, -24),
	BackgroundTransparency = 1, Text = "Listo",
	TextColor3 = Color3.fromRGB(190, 160, 220), TextSize = 11, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22,
}, panel)

local statusToken = 0
local function setStatus(txt, col)
	statusToken += 1
	local my = statusToken
	statusLbl.Text = txt
	statusLbl.TextColor3 = col or Color3.fromRGB(220, 180, 255)
	task.delay(4, function()
		if my == statusToken and statusLbl.Parent then statusLbl.Text = "" end
	end)
end

------------------------------------------------------------
-- Envío de comandos (HD Admin, con respaldo por chat)
------------------------------------------------------------
local function enviar(cmd)
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
	local ok = pcall(function()
		TextChatService.TextChannels.RBXGeneral:SendAsync(cmd)
	end)
	if ok then return "chat" end
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

------------------------------------------------------------
-- PAUSA GENERAL: detiene la protección automática (skins y etiquetas)
------------------------------------------------------------
local pausado = false

------------------------------------------------------------
-- Memoria de skins forzadas, por UserId (sobrevive a salir/entrar)
------------------------------------------------------------
local assignedSkin = {}

local function forzarSkin(t, userId)
	assignedSkin[t.UserId] = userId
	enviar(";char " .. t.Name .. " " .. userId)
end

local function quitarForzado(t)
	assignedSkin[t.UserId] = nil
end

------------------------------------------------------------
-- Memoria de etiquetas de nombre, por UserId
------------------------------------------------------------
local assignedTag = {}

local function forzarEtiqueta(t, texto)
	assignedTag[t.UserId] = texto
	enviar(string.format(NICKNAME_SET_CMD, t.Name, texto))
end

local function quitarEtiqueta(t)
	assignedTag[t.UserId] = nil
	enviar(string.format(NICKNAME_RESET_CMD, t.Name, t.Name))
end

------------------------------------------------------------
-- Al reaparecer (muerte) o al entrar de nuevo al servidor,
-- se reaplican sola la skin y la etiqueta (si no está pausado)
------------------------------------------------------------
local function vigilarJugador(p)
	local function aplicarSiCorresponde()
		if pausado then return end
		local id = assignedSkin[p.UserId]
		local tag = assignedTag[p.UserId]
		if id or tag then
			task.wait(1.5)
			if pausado then return end
			if id and assignedSkin[p.UserId] == id then
				enviar(";char " .. p.Name .. " " .. id)
			end
			if tag and assignedTag[p.UserId] == tag then
				enviar(string.format(NICKNAME_SET_CMD, p.Name, tag))
			end
		end
	end
	p.CharacterAdded:Connect(aplicarSiCorresponde)
	if p.Character then aplicarSiCorresponde() end
end
for _, p in ipairs(Players:GetPlayers()) do vigilarJugador(p) end
Players.PlayerAdded:Connect(vigilarJugador)
-- OJO: no borramos la memoria al salir, para que se mantenga si vuelve a entrar

------------------------------------------------------------
-- Vigilancia activa: reafirma cada cierto tiempo skin y etiqueta,
-- aunque alguien las haya cambiado mientras tanto (si no está pausado)
------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(VIGILANCIA_INTERVALO)
		if not pausado then
			for _, p in ipairs(Players:GetPlayers()) do
				local idEsperado = assignedSkin[p.UserId]
				local tagEsperada = assignedTag[p.UserId]
				if (idEsperado or tagEsperada) and p.Character then
					if idEsperado then
						enviar(";char " .. p.Name .. " " .. idEsperado)
					end
					if tagEsperada then
						enviar(string.format(NICKNAME_SET_CMD, p.Name, tagEsperada))
					end
					task.wait(VIGILANCIA_ESPACIADO)
				end
			end
		end
	end
end)

------------------------------------------------------------
-- LISTA 1: a quién le cambiamos la skin / etiqueta
------------------------------------------------------------
local targetPlayer = nil

local targetLbl = mk("TextLabel", {
	Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 38),
	BackgroundTransparency = 1, Text = "1️⃣ A quién cambiarle la skin:",
	TextColor3 = Color3.fromRGB(220, 180, 255), TextSize = 11, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
}, panel)

local plScroll = mk("ScrollingFrame", {
	Size = UDim2.new(1, -12, 0, 90), Position = UDim2.fromOffset(6, 56),
	BackgroundColor3 = Color3.fromRGB(18, 12, 26), BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C_LINE,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 22,
}, panel)
corner(7, plScroll)
mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.Name}, plScroll)
mk("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 3)}, plScroll)

------------------------------------------------------------
-- LISTA 2: de quién copiar la skin (jugadores del servidor)
------------------------------------------------------------
local sourcePlayer = nil

local sourceLbl = mk("TextLabel", {
	Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 152),
	BackgroundTransparency = 1, Text = "2️⃣ De quién copiar la skin:",
	TextColor3 = Color3.fromRGB(180, 210, 255), TextSize = 11, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
}, panel)

local srcScroll = mk("ScrollingFrame", {
	Size = UDim2.new(1, -12, 0, 90), Position = UDim2.fromOffset(6, 170),
	BackgroundColor3 = Color3.fromRGB(12, 16, 26), BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(70, 130, 210),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 22,
}, panel)
corner(7, srcScroll)
mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.Name}, srcScroll)
mk("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 3)}, srcScroll)

------------------------------------------------------------
-- Llenar listas 1 y 2
------------------------------------------------------------
local function etiquetaDe(p)
	local label = (p.DisplayName ~= p.Name)
		and ("  👤 " .. p.DisplayName .. " (@" .. p.Name .. ")")
		or ("  👤 " .. p.Name)
	if p == player then label = label .. "  (tú)" end
	return label
end

local function refreshListas()
	for _, c in ipairs(plScroll:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
	end
	for _, c in ipairs(srcScroll:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
	end

	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do table.insert(list, p) end
	table.sort(list, function(a, b) return a.Name:lower() < b.Name:lower() end)

	if targetPlayer and targetPlayer.Parent ~= Players then
		targetPlayer = nil
		targetLbl.Text = "1️⃣ A quién cambiarle la skin:"
	end
	if sourcePlayer and sourcePlayer.Parent ~= Players then
		sourcePlayer = nil
		sourceLbl.Text = "2️⃣ De quién copiar la skin:"
	end

	if #list == 0 then
		mk("TextLabel", {
			Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
			Text = "Sin jugadores", TextColor3 = Color3.fromRGB(150, 120, 180),
			TextSize = 11, Font = Enum.Font.Gotham, ZIndex = 24,
		}, plScroll)
		mk("TextLabel", {
			Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
			Text = "Sin jugadores", TextColor3 = Color3.fromRGB(120, 150, 180),
			TextSize = 11, Font = Enum.Font.Gotham, ZIndex = 24,
		}, srcScroll)
		return #list
	end

	for _, p in ipairs(list) do
		local b1 = mk("TextButton", {
			Name = tostring(p.UserId), Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = (targetPlayer == p) and C_SEL or C_ROW,
			Text = etiquetaDe(p), TextColor3 = C_TEXT, TextSize = 11, Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BorderSizePixel = 0, ZIndex = 24,
		}, plScroll)
		corner(5, b1)
		b1.Activated:Connect(function()
			targetPlayer = p
			targetLbl.Text = "1️⃣ A quién cambiarle la skin: " .. p.Name
			for _, c in ipairs(plScroll:GetChildren()) do
				if c:IsA("TextButton") then
					c.BackgroundColor3 = (c.Name == tostring(p.UserId)) and C_SEL or C_ROW
				end
			end
			setStatus("✅ Objetivo: " .. p.Name)
		end)

		local b2 = mk("TextButton", {
			Name = tostring(p.UserId), Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = (sourcePlayer == p) and C_SEL2 or C_ROW,
			Text = etiquetaDe(p), TextColor3 = C_TEXT, TextSize = 11, Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BorderSizePixel = 0, ZIndex = 24,
		}, srcScroll)
		corner(5, b2)
		b2.Activated:Connect(function()
			sourcePlayer = p
			sourceLbl.Text = "2️⃣ De quién copiar la skin: " .. p.Name
			for _, c in ipairs(srcScroll:GetChildren()) do
				if c:IsA("TextButton") then
					c.BackgroundColor3 = (c.Name == tostring(p.UserId)) and C_SEL2 or C_ROW
				end
			end
			setStatus("✅ Origen de skin: " .. p.Name)
		end)
	end
	return #list
end

local refreshBtn = mk("TextButton", {
	Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 264),
	BackgroundColor3 = Color3.fromRGB(45, 25, 65),
	Text = "🔄  Actualizar listas", TextColor3 = C_TEXT,
	TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 22,
}, panel)
corner(7, refreshBtn)
refreshBtn.Activated:Connect(function()
	local n = refreshListas()
	setStatus("✅ Listas actualizadas — " .. n .. " jugador(es)")
end)

Players.PlayerAdded:Connect(function() refreshListas() end)
Players.PlayerRemoving:Connect(function() task.defer(refreshListas) end)

------------------------------------------------------------
-- Zona de acciones
------------------------------------------------------------
local ACTIONS_Y = 298
local scroll = mk("ScrollingFrame", {
	Size = UDim2.new(1, -12, 0, PANEL_H - ACTIONS_Y - 28),
	Position = UDim2.fromOffset(6, ACTIONS_Y),
	BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C_LINE,
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
		TextColor3 = Color3.fromRGB(190, 120, 255), TextSize = 11, Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	}, scroll)
end

local function mkBtn(icon, label, color, onClick)
	local btn = mk("TextButton", {
		LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = color or Color3.fromRGB(60, 30, 90),
		Text = icon .. "  " .. label, TextColor3 = C_TEXT,
		TextSize = 12, Font = Enum.Font.GothamBold, BorderSizePixel = 0, ZIndex = 22,
	}, scroll)
	corner(8, btn)
	btn.Activated:Connect(function() task.spawn(onClick) end)
	return btn
end

local function necesitaAmbos(fn)
	if not targetPlayer or targetPlayer.Parent ~= Players then
		setStatus("⚠️ Elige primero a quién cambiarle la skin (lista 1)", Color3.fromRGB(255, 160, 0))
		return
	end
	if not sourcePlayer or sourcePlayer.Parent ~= Players then
		setStatus("⚠️ Elige de quién copiar la skin (lista 2)", Color3.fromRGB(255, 160, 0))
		return
	end
	fn(targetPlayer, sourcePlayer)
end

local function necesitaObjetivo(fn)
	if not targetPlayer or targetPlayer.Parent ~= Players then
		setStatus("⚠️ Elige primero a quién cambiarle la skin (lista 1)", Color3.fromRGB(255, 160, 0))
		return
	end
	fn(targetPlayer)
end

local function necesitaOrigen(fn)
	if not sourcePlayer or sourcePlayer.Parent ~= Players then
		setStatus("⚠️ Elige de quién copiar la skin (lista 2)", Color3.fromRGB(255, 160, 0))
		return
	end
	fn(sourcePlayer)
end

------------------------------------------------------------
-- Control del script: pausar / reanudar la protección automática
------------------------------------------------------------
mkDiv("── ⏯️ CONTROL DEL SCRIPT ──")

local pauseBtn
local function pintarPause()
	if pausado then
		pauseBtn.Text = "▶️  Reanudar protección"
		pauseBtn.BackgroundColor3 = Color3.fromRGB(30, 90, 50)
	else
		pauseBtn.Text = "⏸️  Pausar protección (skins y etiquetas)"
		pauseBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 20)
	end
end
pauseBtn = mkBtn("", "", Color3.fromRGB(120, 60, 20), function()
	pausado = not pausado
	pintarPause()
	if pausado then
		setStatus("⏸️ Protección en pausa: todos pueden cambiar su skin libremente", Color3.fromRGB(255, 190, 100))
	else
		setStatus("▶️ Protección reanudada", Color3.fromRGB(150, 255, 150))
	end
end)
pintarPause()

------------------------------------------------------------
-- Acciones (1 contra 1, jugadores del servidor)
------------------------------------------------------------
mkDiv("── 🧍 UNO A UNO ──")

mkBtn("🧍", "Ponerle la skin de (2) a (1)", Color3.fromRGB(90, 40, 130), function()
	necesitaAmbos(function(t, s)
		if t == s then
			setStatus("⚠️ Elige dos jugadores distintos", Color3.fromRGB(255, 160, 0))
			return
		end
		forzarSkin(t, s.UserId)
		setStatus("🧍 " .. s.Name .. " → " .. t.Name .. " (protegida hasta que la restablezcas)")
	end)
end)

mkBtn("🔄", "Intercambiar skins (1) ↔ (2)", Color3.fromRGB(70, 50, 120), function()
	necesitaAmbos(function(t, s)
		if t == s then
			setStatus("⚠️ Elige dos jugadores distintos", Color3.fromRGB(255, 160, 0))
			return
		end
		forzarSkin(t, s.UserId)
		task.wait(3)
		forzarSkin(s, t.UserId)
		setStatus("🔄 Skins intercambiadas: " .. t.Name .. " ↔ " .. s.Name)
	end)
end)

mkBtn("♻️", "Devolverle su skin original a (1)", Color3.fromRGB(35, 70, 45), function()
	necesitaObjetivo(function(t)
		quitarForzado(t)
		run(";char " .. t.Name .. " " .. t.UserId, "♻️ Skin original → " .. t.Name)
	end)
end)

mkBtn("🧍", "Quitar skin a (1) (noob)", Color3.fromRGB(80, 30, 60), function()
	necesitaObjetivo(function(t)
		forzarSkin(t, 1)
		setStatus("🧍 Skin noob → " .. t.Name)
	end)
end)

------------------------------------------------------------
-- Etiqueta de nombre
------------------------------------------------------------
mkDiv("── 🏷️ ETIQUETA DE NOMBRE ──")

local etiquetaBox = mk("TextBox", {
	LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = Color3.fromRGB(25, 18, 38),
	PlaceholderText = "Escribe la etiqueta (ej: SOYPRO 😏)", Text = "",
	PlaceholderColor3 = Color3.fromRGB(140, 110, 170),
	TextColor3 = C_TEXT, TextSize = 12, Font = Enum.Font.Gotham,
	ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 22,
}, scroll)
corner(7, etiquetaBox)

mkBtn("🏷️", "Ponerle esa etiqueta a (1)", Color3.fromRGB(100, 70, 40), function()
	necesitaObjetivo(function(t)
		local texto = etiquetaBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if texto == "" then
			setStatus("⚠️ Escribe una etiqueta primero", Color3.fromRGB(255, 160, 0))
			return
		end
		forzarEtiqueta(t, texto)
		setStatus("🏷️ Etiqueta puesta a " .. t.Name)
	end)
end)

for _, texto in ipairs(ETIQUETAS_RAPIDAS) do
	mkBtn("⭐", texto .. "  →  (1)", Color3.fromRGB(90, 60, 30), function()
		necesitaObjetivo(function(t)
			forzarEtiqueta(t, texto)
			setStatus("🏷️ " .. texto .. " → " .. t.Name)
		end)
	end)
end

mkBtn("♻️", "Quitar etiqueta a (1)", Color3.fromRGB(35, 70, 45), function()
	necesitaObjetivo(function(t)
		quitarEtiqueta(t)
		setStatus("♻️ Etiqueta quitada a " .. t.Name)
	end)
end)

------------------------------------------------------------
-- Búsqueda libre: escribir cualquier usuario de Roblox
------------------------------------------------------------
mkDiv("── 🔍 BUSCAR CUALQUIER USUARIO ──")

local busBox = mk("TextBox", {
	LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = Color3.fromRGB(25, 18, 38),
	PlaceholderText = "Usuario de Roblox (ej: el del payaso)", Text = "",
	PlaceholderColor3 = Color3.fromRGB(140, 110, 170),
	TextColor3 = C_TEXT, TextSize = 12, Font = Enum.Font.Gotham,
	ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 22,
}, scroll)
corner(7, busBox)

mkBtn("🔍", "Ponerle esa skin a (1)", Color3.fromRGB(100, 60, 150), function()
	necesitaObjetivo(function(t)
		local texto = busBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if texto == "" then
			setStatus("⚠️ Escribe un usuario de Roblox", Color3.fromRGB(255, 160, 0))
			return
		end
		local ok, id
		if tonumber(texto) then
			id = tonumber(texto)
			ok = true
		else
			ok, id = pcall(function() return Players:GetUserIdFromNameAsync(texto) end)
		end
		if not ok or not id then
			setStatus("⚠️ No encontré ese usuario de Roblox", Color3.fromRGB(255, 160, 0))
			return
		end
		forzarSkin(t, id)
		setStatus("🔍 " .. texto .. " → " .. t.Name)
	end)
end)

------------------------------------------------------------
-- Skins favoritas
------------------------------------------------------------
mkDiv("── ⭐ SKINS FAVORITAS ──")

if #SKINS_FAVORITAS == 0 then
	mk("TextLabel", {
		LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1, Text = "Agrega usuarios en SKINS_FAVORITAS al inicio del script",
		TextColor3 = Color3.fromRGB(150, 120, 180), TextSize = 10,
		Font = Enum.Font.Gotham, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
	}, scroll)
else
	for _, fav in ipairs(SKINS_FAVORITAS) do
		mkBtn("⭐", fav.apodo .. "  →  (1)", Color3.fromRGB(110, 70, 40), function()
			necesitaObjetivo(function(t)
				local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(fav.usuario) end)
				if not ok or not id then
					setStatus("⚠️ No encontré el usuario de '" .. fav.apodo .. "'", Color3.fromRGB(255, 160, 0))
					return
				end
				forzarSkin(t, id)
				setStatus("⭐ " .. fav.apodo .. " → " .. t.Name)
			end)
		end)
	end
end

------------------------------------------------------------
-- Skin de un amigo tuyo de Roblox
------------------------------------------------------------
mkDiv("── 👫 SKIN DE UN AMIGO TUYO ──")

local amigoElegido = nil

local amigoLbl = mk("TextLabel", {
	LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1, Text = "Amigo elegido: —",
	TextColor3 = Color3.fromRGB(230, 200, 255), TextSize = 11, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
}, scroll)

local amigosScroll = mk("ScrollingFrame", {
	LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 110),
	BackgroundColor3 = Color3.fromRGB(22, 14, 34), BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C_LINE,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 22,
}, scroll)
corner(7, amigosScroll)
mk("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, amigosScroll)
mk("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3),
	PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 3)}, amigosScroll)

local function cargarAmigos()
	for _, c in ipairs(amigosScroll:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
	end
	mk("TextLabel", {
		Name = "cargando", Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1, Text = "Cargando amigos...",
		TextColor3 = Color3.fromRGB(170, 140, 200), TextSize = 11,
		Font = Enum.Font.Gotham, ZIndex = 24,
	}, amigosScroll)

	task.spawn(function()
		local ok, paginas = pcall(function()
			return Players:GetFriendsAsync(player.UserId)
		end)

		for _, c in ipairs(amigosScroll:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
		end

		if not ok then
			mk("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
				Text = "⚠️ No se pudo cargar la lista de amigos",
				TextColor3 = Color3.fromRGB(255, 160, 0), TextSize = 11,
				Font = Enum.Font.Gotham, TextWrapped = true, ZIndex = 24,
			}, amigosScroll)
			setStatus("⚠️ Error al cargar amigos", Color3.fromRGB(255, 160, 0))
			return
		end

		local total = 0
		while true do
			local pagina = paginas:GetCurrentPage()
			for _, amigo in ipairs(pagina) do
				total += 1
				local btn = mk("TextButton", {
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundColor3 = C_ROW,
					Text = "  👫 " .. amigo.Username, TextColor3 = C_TEXT,
					TextSize = 11, Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					BorderSizePixel = 0, ZIndex = 24,
				}, amigosScroll)
				corner(5, btn)
				btn.Activated:Connect(function()
					amigoElegido = {nombre = amigo.Username, userId = amigo.Id}
					amigoLbl.Text = "Amigo elegido: " .. amigo.Username
					for _, c in ipairs(amigosScroll:GetChildren()) do
						if c:IsA("TextButton") then
							c.BackgroundColor3 = (c == btn) and C_SEL2 or C_ROW
						end
					end
					setStatus("✅ Amigo elegido: " .. amigo.Username)
				end)
			end
			if paginas.IsFinished then break end
			local avanzo = pcall(function() paginas:AdvanceToNextPageAsync() end)
			if not avanzo then break end
		end

		if total == 0 then
			mk("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
				Text = "No tienes amigos en Roblox (o la lista es privada)",
				TextColor3 = Color3.fromRGB(150, 120, 180), TextSize = 10,
				Font = Enum.Font.Gotham, TextWrapped = true, ZIndex = 24,
			}, amigosScroll)
		end
		setStatus("👫 " .. total .. " amigo(s) cargado(s)")
	end)
end

mkBtn("👫", "Cargar mis amigos", Color3.fromRGB(80, 50, 120), function()
	cargarAmigos()
end)

mkBtn("🧍", "Ponerle esa skin a (1)", Color3.fromRGB(100, 60, 150), function()
	necesitaObjetivo(function(t)
		if not amigoElegido then
			setStatus("⚠️ Elige primero un amigo de la lista", Color3.fromRGB(255, 160, 0))
			return
		end
		forzarSkin(t, amigoElegido.userId)
		setStatus("👫 " .. amigoElegido.nombre .. " → " .. t.Name)
	end)
end)

------------------------------------------------------------
-- Acciones masivas (a TODOS los jugadores del servidor)
------------------------------------------------------------
mkDiv("── 🌐 A TODOS LOS JUGADORES ──")

mkBtn("🌐", "Ponerle a TODOS la skin de (2)", Color3.fromRGB(120, 50, 160), function()
	necesitaOrigen(function(s)
		local n = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= s then
				local ok = pcall(forzarSkin, p, s.UserId)
				if ok then n += 1 end
				task.wait(DELAY_ENTRE_COMANDOS)
			end
		end
		setStatus("🌐 Skin de " .. s.Name .. " aplicada a " .. n .. " jugador(es)")
	end)
end)

mkBtn("👫", "Ponerle a TODOS la skin del amigo elegido", Color3.fromRGB(100, 60, 150), function()
	if not amigoElegido then
		setStatus("⚠️ Elige primero un amigo de la lista", Color3.fromRGB(255, 160, 0))
		return
	end
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local ok = pcall(forzarSkin, p, amigoElegido.userId)
		if ok then n += 1 end
		task.wait(DELAY_ENTRE_COMANDOS)
	end
	setStatus("👫 Skin de " .. amigoElegido.nombre .. " aplicada a " .. n .. " jugador(es)")
end)

mkBtn("🙋", "Ponerle a TODOS MI skin", Color3.fromRGB(80, 60, 140), function()
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local ok = pcall(forzarSkin, p, player.UserId)
			if ok then n += 1 end
			task.wait(DELAY_ENTRE_COMANDOS)
		end
	end
	setStatus("🙋 Tu skin aplicada a " .. n .. " jugador(es)")
end)

mkBtn("♻️", "Restablecer skin original a TODOS", Color3.fromRGB(30, 90, 50), function()
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		quitarForzado(p)
		local ok = pcall(function() enviar(";char " .. p.Name .. " " .. p.UserId) end)
		if ok then n += 1 end
		task.wait(DELAY_ENTRE_COMANDOS)
	end
	setStatus("♻️ Skin original restablecida a " .. n .. " jugador(es)")
end)

------------------------------------------------------------
-- Inicio
------------------------------------------------------------
refreshListas()
setPanel(false)
print("✅ Skin Changer cargado | toca 🧍 para abrir")
