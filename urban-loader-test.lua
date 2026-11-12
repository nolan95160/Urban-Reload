-- URBAN RELOAD - Chargeur de test des licences (V33 conservee)
-- A executer avec Real. Aucune cle n'est stockee localement.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local API_URL = "https://51.255.205.163:3005/activate"
local SCRIPT_URL = "https://raw.githubusercontent.com/nolan95160/Urban-Reload/main/urban-v33-payload.lua?v=33"

local player = Players.LocalPlayer
if not player then
    warn("[URBAN RELOAD] Joueur local introuvable")
    return
end

local parent
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and typeof(result) == "Instance" then
        parent = result
    end
end
parent = parent or player:WaitForChild("PlayerGui")

local old = parent:FindFirstChild("UrbanReloadAuthTest")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "UrbanReloadAuthTest"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local function rounded(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
end

local frame = Instance.new("Frame")
frame.Name = "AuthPanel"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(390, 234)
frame.BackgroundColor3 = Color3.fromRGB(19, 20, 27)
frame.BorderSizePixel = 0
frame.Parent = gui
rounded(frame, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(156, 37, 52)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 17)
title.Size = UDim2.new(1, -44, 0, 35)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "URBAN RELOAD"
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(22, 52)
subtitle.Size = UDim2.new(1, -44, 0, 25)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = Color3.fromRGB(175, 176, 187)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "Entre ta cle personnelle pour lancer la V33"
subtitle.Parent = frame

local keyBox = Instance.new("TextBox")
keyBox.Name = "LicenseInput"
keyBox.Position = UDim2.fromOffset(22, 89)
keyBox.Size = UDim2.new(1, -44, 0, 40)
keyBox.BackgroundColor3 = Color3.fromRGB(34, 35, 45)
keyBox.BorderSizePixel = 0
keyBox.Font = Enum.Font.Code
keyBox.TextSize = 13
keyBox.TextColor3 = Color3.fromRGB(245, 245, 245)
keyBox.PlaceholderColor3 = Color3.fromRGB(126, 128, 141)
keyBox.PlaceholderText = "Colle ta cle ici (ex. pseudo-...)"
keyBox.Text = ""
keyBox.ClearTextOnFocus = false
keyBox.Parent = frame
rounded(keyBox, 7)

local button = Instance.new("TextButton")
button.Position = UDim2.fromOffset(22, 143)
button.Size = UDim2.new(1, -44, 0, 39)
button.BackgroundColor3 = Color3.fromRGB(176, 41, 60)
button.BorderSizePixel = 0
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Text = "ACTIVER"
button.Parent = frame
rounded(button, 7)

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(22, 190)
status.Size = UDim2.new(1, -44, 0, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(180, 183, 194)
status.TextWrapped = true
status.Text = "Une cle = un appareil. La cle reste illimitee."
status.Parent = frame

local busy = false
local function setStatus(message, good)
    status.Text = message
    status.TextColor3 = good and Color3.fromRGB(117, 225, 162)
        or Color3.fromRGB(245, 135, 138)
end

local function activate()
    if busy then return end
    local key = keyBox.Text:match("^%s*(.-)%s*$")
    if not key or #key < 20 then
        setStatus("Cle trop courte ou vide.", false)
        return
    end

    local requestFn = request or http_request or (http and http.request)
    if type(requestFn) ~= "function" then
        setStatus("Real: fonction request() indisponible.", false)
        return
    end
    if type(gethwid) ~= "function" then
        setStatus("Real: fonction gethwid() indisponible.", false)
        return
    end
    local hwidOK, hwid = pcall(gethwid)
    if not hwidOK or type(hwid) ~= "string" or #hwid < 8 then
        setStatus("Identifiant d'appareil Real invalide.", false)
        return
    end

    busy = true
    button.Text = "VERIFICATION..."
    button.AutoButtonColor = false

    local ok, response = pcall(function()
        return requestFn({
            Url = API_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ key = key, hwid = hwid })
        })
    end)

    if not ok or type(response) ~= "table" then
        setStatus("Connexion HTTPS impossible ou bloquee par Real.", false)
    else
        local decodedOK, data = pcall(function()
            return HttpService:JSONDecode(response.Body or "")
        end)
        if decodedOK and type(data) == "table"
            and response.StatusCode == 200 and data.ok == true and data.allowed == true then
            setStatus("Cle valide ! Lancement de la V33...", true)
            local loaded, err = pcall(function()
                local source = game:HttpGet(SCRIPT_URL, false)
                local execute, compileError = loadstring(source)
                if type(execute) ~= "function" then
                    error(tostring(compileError or "Compilation impossible"))
                end
                execute()
            end)
            if loaded then
                gui:Destroy()
                return
            end
            warn("[URBAN RELOAD] Erreur de lancement V33:", tostring(err))
            setStatus("Cle valide, mais erreur au chargement V33.", false)
        elseif response.StatusCode == 401 then
            setStatus("Cle invalide ou desactivee.", false)
        elseif response.StatusCode == 403 then
            setStatus("Cle deja associee a un autre appareil.", false)
        elseif response.StatusCode == 429 then
            setStatus("Trop de tentatives. Reessaie dans une minute.", false)
        else
            setStatus("API indisponible (HTTP " .. tostring(response.StatusCode) .. ").", false)
        end
    end

    busy = false
    button.Text = "ACTIVER"
    button.AutoButtonColor = true
end

button.MouseButton1Click:Connect(activate)
keyBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then activate() end
end)
