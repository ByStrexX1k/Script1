-- Servicios
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ==========================================
-- CONFIGURACIÓN
-- ==========================================
local UPTIME_MINIMO = 20
local RUTA_TEXTLABEL = {"IncidentSign", "SurfaceGui", "TextLabel"}
local URL_SCRIPT = "https://raw.githubusercontent.com/ByStrexX1k/Script1/refs/heads/main/script.lua"

-- ==========================================
-- 1. LEER EL TEXTO DEL INCIDENTSIGN
-- ==========================================
local function obtenerTextLabel()
    local actual = workspace
    for _, nombre in ipairs(RUTA_TEXTLABEL) do
        actual = actual:FindFirstChild(nombre)
        if not actual then return nil end
    end
    return actual
end

local function parsearTiempo(texto)
    if not texto or texto == "" then return nil end
    local h, m, s = texto:match("(%d+):(%d+):(%d+)")
    if h then
        return tonumber(h) * 60 + tonumber(m) + tonumber(s) / 60
    end
    local m2, s2 = texto:match("(%d+):(%d+)")
    if m2 then
        return tonumber(m2) + tonumber(s2) / 60
    end
    return nil
end

-- ==========================================
-- 2. LÓGICA PERSISTENTE
-- ==========================================
if getgenv().BuscandoIncident then
    local lista = getgenv().ListaServidores
    local indice = getgenv().IndiceActual or 1
    
    if not game:IsLoaded() then game.Loaded:Wait() end
    task.wait(5)
    
    local label = obtenerTextLabel()
    local texto = label and label.Text or nil
    local minutos = parsearTiempo(texto)
    
    print("🪨 IncidentSign dice: '" .. tostring(texto) .. "' -> " .. tostring(minutos) .. " min")
    
    if minutos and minutos >= UPTIME_MINIMO then
        print("✅ ¡ENCONTRADO! Servidor con " .. math.floor(minutos) .. " minutos sin incidente.")
        getgenv().BuscandoIncident = false
        getgenv().ListaServidores = nil
        getgenv().IndiceActual = nil
    else
        indice = indice + 1
        if indice > #lista then
            warn("❌ Se agotaron los " .. #lista .. " servidores.")
            getgenv().BuscandoIncident = false
            getgenv().ListaServidores = nil
            getgenv().IndiceActual = nil
        else
            getgenv().IndiceActual = indice
            local siguienteJobId = lista[indice]
            
            if queue_on_teleport then
                queue_on_teleport([[
                    getgenv().BuscandoIncident = true
                    getgenv().ListaServidores = ]] .. HttpService:JSONEncode(lista) .. [[
                    getgenv().IndiceActual = ]] .. indice .. [[
                    loadstring(game:HttpGet("]] .. URL_SCRIPT .. [["))()
                ]])
            end
            
            print("⏭️ Saltando al servidor " .. indice .. "/" .. #lista)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, siguienteJobId, player)
        end
    end
end

-- ==========================================
-- 3. OBTENER LISTA DE SERVIDORES
-- ==========================================
local function obtenerServidores()
    local servidores = {}
    local cursor = ""
    
    for i = 1, 4 do
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        
        local exito, respuesta = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        
        if exito and respuesta and respuesta.data then
            for _, srv in ipairs(respuesta.data) do
                if srv.playing < srv.maxPlayers - 1 and srv.id ~= game.JobId then
                    table.insert(servidores, srv.id)
                end
            end
            cursor = respuesta.nextPageCursor or ""
            if cursor == "" then break end
        else
            break
        end
    end
    
    return servidores
end

-- ==========================================
-- 4. INTERFAZ
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BuscadorIncident"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local boton = Instance.new("TextButton")
boton.Size = UDim2.new(0, 280, 0, 60)
boton.Position = UDim2.new(0.5, -140, 0, 20)
boton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
boton.TextColor3 = Color3.fromRGB(255, 255, 255)
boton.Text = "🔍 BUSCAR SERVIDOR +20 MIN"
boton.Font = Enum.Font.SourceSansBold
boton.TextSize = 15
boton.Parent = screenGui

local dragging, dragInput, dragStart, startPos
boton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = boton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
boton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        boton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(0, 280, 0, 40)
infoLabel.Position = UDim2.new(0.5, -140, 0, 85)
infoLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLabel.Font = Enum.Font.Code
infoLabel.TextSize = 13
infoLabel.Text = "Leyendo IncidentSign..."
infoLabel.Parent = screenGui

task.spawn(function()
    while infoLabel.Parent do
        local label = obtenerTextLabel()
        if label then
            local minutos = parsearTiempo(label.Text)
            if minutos then
                infoLabel.Text = string.format("🪨 %.1f min sin incidente", minutos)
                if minutos >= UPTIME_MINIMO then
                    infoLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                else
                    infoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                end
            end
        else
            infoLabel.Text = "⚠️ No se encuentra IncidentSign"
            infoLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
        task.wait(2)
    end
end)

boton.MouseButton1Click:Connect(function()
    boton.Text = "🔍 BUSCANDO..."
    boton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
    
    local lista = obtenerServidores()
    if #lista == 0 then
        boton.Text = "❌ NO HAY SERVIDORES"
        boton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        task.wait(2)
        boton.Text = "🔍 BUSCAR SERVIDOR +20 MIN"
        boton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        return
    end
    
    print("📋 " .. #lista .. " servidores candidatos.")
    
    getgenv().BuscandoIncident = true
    getgenv().ListaServidores = lista
    getgenv().IndiceActual = 1
    
    if queue_on_teleport then
        queue_on_teleport([[
            getgenv().BuscandoIncident = true
            getgenv().ListaServidores = ]] .. HttpService:JSONEncode(lista) .. [[
            getgenv().IndiceActual = 1
            loadstring(game:HttpGet("]] .. URL_SCRIPT .. [["))()
        ]])
    end
    
    TeleportService:TeleportToPlaceInstance(game.PlaceId, lista[1], player)
end)

print("✅ Script cargado. Presiona el botón para buscar el IncidentSign +20 min.")
