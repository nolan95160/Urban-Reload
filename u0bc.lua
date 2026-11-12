local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local VIM = game:GetService("VirtualInputManager")
local joueurLocal = Players.LocalPlayer
local rng = Random.new()

-- ================= ESP ZOMBIE =================
local zombieActif = false
local zombieGlows = {}
local zombieConns = {}
-- Couleur configurable depuis VISUAL ; conservee si les zombies reapparaissent.
local zombieGlowColor = Color3.fromRGB(255, 0, 0)

local function ajouterGlowZombie(objet)
    if zombieGlows[objet] then return end
    local glow = Instance.new("Highlight")
    glow.Name = "GlowZombie"
    glow.Adornee = objet
    glow.FillColor = zombieGlowColor
    glow.OutlineColor = zombieGlowColor
    glow.FillTransparency = 0.3
    glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    glow.Parent = objet
    zombieGlows[objet] = glow
end

local function verifierZombie(objet)
    if objet.Name:upper():find("HOOD") then ajouterGlowZombie(objet) end
end

local function activerZombie()
    for _, o in ipairs(workspace:GetDescendants()) do verifierZombie(o) end
    table.insert(zombieConns, workspace.DescendantAdded:Connect(function(o)
        task.wait(0.5)
        if zombieActif then verifierZombie(o) end
    end))
end

local function desactiverZombie()
    for _, c in ipairs(zombieConns) do c:Disconnect() end
    zombieConns = {}
    for o, g in pairs(zombieGlows) do g:Destroy() zombieGlows[o] = nil end
end

-- ================= ESP PLAYER : CONTOUR UNIQUEMENT / 2 COULEURS =================
-- Un Highlight par personnage, sans remplissage. La couleur est choisie
-- suivant la ligne de vue et reste reglable depuis les deux barres RGB.
local playerActif = false
local playerGlowColorVisible = Color3.fromRGB(53, 219, 225)
local playerGlowColorCache = Color3.fromRGB(255, 55, 70)
local playerGlows = {}
local playerConns = {}
local ESP_REFRESH_INTERVAL = 0.30
local ESP_OUTLINE_TRANSPARENCY = 0 -- 0 = contour opaque / 1 = invisible
local glowFolder = nil
local playerGuiESP = joueurLocal:WaitForChild("PlayerGui")

local espVisibiliteRaycast = RaycastParams.new()
espVisibiliteRaycast.FilterType = Enum.RaycastFilterType.Exclude
espVisibiliteRaycast.IgnoreWater = true

local function joueurVisibleSansMur(personnage)
    local camera = workspace.CurrentCamera
    if not camera or not personnage or not personnage.Parent then return false end

    local personnageLocal = joueurLocal.Character
    espVisibiliteRaycast.FilterDescendantsInstances = personnageLocal and {personnageLocal} or {}
    local origine = camera.CFrame.Position
    local points = {"Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso"}
    local testes = {}
    for _, nom in ipairs(points) do
        local partie = personnage:FindFirstChild(nom)
        if partie and partie:IsA("BasePart") and not testes[partie] then
            testes[partie] = true
            local direction = partie.Position - origine
            if direction.Magnitude < 0.01 then return true end
            local impact = workspace:Raycast(origine, direction, espVisibiliteRaycast)
            if not impact or impact.Instance:IsDescendantOf(personnage) then
                return true
            end
        end
    end
    return false
end

local function nettoyerAnciensGlow()
    -- Les anciennes versions utilisaient des blocs opaques dans PlayerGui.
    for _, nom in ipairs({"U0BC_ESPPlayerUniforme", "U0BC_ESPPlayerSecours"}) do
        local dossier = playerGuiESP:FindFirstChild(nom)
        if dossier then dossier:Destroy() end
    end
    for _, joueur in ipairs(Players:GetPlayers()) do
        local perso = joueur.Character
        if perso then
            for _, enfant in ipairs(perso:GetChildren()) do
                if enfant:IsA("Highlight") and enfant.Name == "U0BC_PlayerChams" then
                    enfant:Destroy()
                end
            end
        end
    end
end

local function obtenirDossierGlow()
    if glowFolder and glowFolder.Parent then return glowFolder end
    local ancien = workspace:FindFirstChild("U0BC_ESPPlayerContours")
    if ancien then ancien:Destroy() end
    glowFolder = Instance.new("Folder")
    glowFolder.Name = "U0BC_ESPPlayerContours"
    glowFolder.Parent = workspace
    return glowFolder
end

local function retirerGlowJoueur(joueur)
    local entree = playerGlows[joueur]
    if not entree then return end
    playerGlows[joueur] = nil
    if entree.highlight then
        pcall(function() entree.highlight:Destroy() end)
    end
end

local function creerGlowJoueur(joueur, personnage)
    if not playerActif or joueur == joueurLocal then return end
    if not personnage or not personnage:IsA("Model") or not personnage.Parent then
        retirerGlowJoueur(joueur)
        return
    end
    local entree = playerGlows[joueur]
    if entree and entree.personnage ~= personnage then
        retirerGlowJoueur(joueur)
        entree = nil
    end
    if not entree then
        entree = {personnage = personnage, highlight = nil, estVisible = false}
        playerGlows[joueur] = entree
    end

    local glow = entree.highlight
    if not glow or not glow.Parent then
        glow = Instance.new("Highlight")
        glow.Name = "U0BC_PlayerContour"
        glow.Adornee = personnage
        glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        glow.FillTransparency = 1 -- NE REMPLIT PAS le corps
        glow.OutlineTransparency = ESP_OUTLINE_TRANSPARENCY
        glow.Enabled = true
        glow.Parent = obtenirDossierGlow()
        entree.highlight = glow
    end

    entree.estVisible = joueurVisibleSansMur(personnage)
    local couleur = entree.estVisible and playerGlowColorVisible or playerGlowColorCache
    glow.Adornee = personnage
    glow.FillTransparency = 1
    glow.OutlineColor = couleur
    glow.OutlineTransparency = ESP_OUTLINE_TRANSPARENCY
    glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    glow.Enabled = true
end

local function rafraichirESPJoueurs()
    if not playerActif then return end
    local presents = {}
    for _, joueur in ipairs(Players:GetPlayers()) do
        if joueur ~= joueurLocal then
            presents[joueur] = true
            creerGlowJoueur(joueur, joueur.Character)
        end
    end
    for joueur in pairs(playerGlows) do
        if not presents[joueur] then retirerGlowJoueur(joueur) end
    end
end

local function activerPlayer()
    for _, connexion in ipairs(playerConns) do connexion:Disconnect() end
    playerConns = {}
    nettoyerAnciensGlow()
    local temps = 0
    table.insert(playerConns, RunService.Heartbeat:Connect(function(dt)
        temps += dt
        if temps >= ESP_REFRESH_INTERVAL then
            temps = 0
            rafraichirESPJoueurs()
        end
    end))
    table.insert(playerConns, Players.PlayerRemoving:Connect(retirerGlowJoueur))
    rafraichirESPJoueurs()
end

local function desactiverPlayer()
    for _, connexion in ipairs(playerConns) do connexion:Disconnect() end
    playerConns = {}
    for joueur in pairs(playerGlows) do retirerGlowJoueur(joueur) end
    if glowFolder then
        pcall(function() glowFolder:Destroy() end)
        glowFolder = nil
    end
end

-- ================= AIM : FARM ZOMBIE (ciblage Local S) =================
-- Les autres fonctions du menu ne sont pas modifiées.
-- Seuls les PNJ dont le modèle contient "HOOD" sont pris en compte.
-- Contrairement à Local S, on exige une vraie pièce Head : aucun tir sur le torse.

local CFG = {
    DureeCombat = 15,          -- Seulement quand le mode Undetect est actif
    PauseCycle = 40,           -- Seulement quand le mode Undetect est actif
    DistScan = 5000,           -- Rayon de recherche de Local S
    DistLock = 380,            -- Portée de verrouillage de Local S
    DistTir = 320,             -- Portée de tir de Local S
    FOV = 95,                  -- FOV de Local S (passe à 160 si beaucoup de PNJ)
    FOVLarge = 160,
    FOVLargeApres = 6,
    Sensibilite = 1.3,
    DeltaMax = 24,            -- Plus rapide, mais avec vitesse progressivement amortie
    CameraAssist = 0.085,    -- Recalage camera plus vif, sans teleporter le regard
    ReactionMin = 0.045,     -- Petit temps de reaction variable
    ReactionMax = 0.11,
    Acceleration = 0.20,     -- Acceleration plus courte, toujours progressive
    MicroAmplitude = 0.045, -- Corrections discretes pour ne pas sortir de Head
    MicroMin = 0.17,
    MicroMax = 0.28,
    Tolerance = 26,          -- Systeme de tir classique, pas le blocage strict V6
    DelaiTir = 0.085,
    VisibleFireDelay = 0.09,
    ReactionSansDegats = 2.2,
    MaxTirsParCible = 12,
    Blacklist = 4,
    ScanInterval = 0.10,
    MoveRate = 0.012,
    OffscreenPull = true,
    LootRange = 45,          -- Identique a Local S
    LootCooldown = 0.05,     -- Delai entre deux essais sur un meme prompt
    LootCheckRate = 0.04,    -- Frequence d'appui E du script Local S
    LootKeyHold = 0.015,     -- Duree de chaque appui E de Local S
    LootFinVague = 0,       -- Aucun E durant les 40 secondes de pause
}

local farmId = 0
local farmActif = false
local backgroundAimEnabled = false

-- Camera independante de la souris : appliquee APRES les CameraScripts du jeu.
-- La boucle de visée ne fait que choisir une cible ; c'est ce contrôleur qui
-- déplace réellement la caméra, même si le script du jeu la réinitialise.
-- V26 : un seul pilote camera avec position, cible et rotation filtrees.
-- Detacher les anciennes versions de BindToRenderStep.
for _, nom in ipairs({
    "U0BC_BackgroundCamera_V24",
    "U0BC_BackgroundCamera_V25",
    "U0BC_BackgroundCamera",
}) do
    pcall(function() RunService:UnbindFromRenderStep(nom) end)
end

local CAMERA_BIND_NAME = "U0BC_BackgroundCamera"
local cameraControlee, cameraTypeSauve, cameraOffsetSauve = nil, nil, nil
local cameraPositionFiltree, cameraRotationFiltree = nil, nil
local cameraCibleFiltree, cameraTetePrecedente = nil, nil
local cameraRenderBound = false
local backgroundHead = nil
local appliquerCameraBackground

-- Nettoyage partage entre executions V26+.
local registreCamera = nil
pcall(function()
    if type(getgenv) == "function" then
        local env = getgenv()
        if type(env) == "table" then registreCamera = env end
    end
    if not registreCamera and type(shared) == "table" then registreCamera = shared end
end)
if registreCamera and type(registreCamera.U0BC_ReleaseBackgroundCamera) == "function" then
    pcall(registreCamera.U0BC_ReleaseBackgroundCamera)
end

local function racineLocale()
    local personnage = joueurLocal.Character
    return personnage and personnage:FindFirstChild("HumanoidRootPart")
end

local function libererCameraBackground()
    if cameraRenderBound then
        pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND_NAME) end)
        cameraRenderBound = false
    end
    if cameraControlee and cameraControlee.Parent then
        pcall(function()
            cameraControlee.CameraType = cameraTypeSauve or Enum.CameraType.Custom
        end)
    end
    cameraControlee, cameraTypeSauve, cameraOffsetSauve = nil, nil, nil
    cameraPositionFiltree, cameraRotationFiltree = nil, nil
    cameraCibleFiltree, cameraTetePrecedente = nil, nil
    backgroundHead = nil
end
if registreCamera then
    registreCamera.U0BC_ReleaseBackgroundCamera = libererCameraBackground
end

local function activerCameraBackground()
    if not (backgroundAimEnabled and farmActif) then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    if camera ~= cameraControlee then
        if cameraControlee and cameraControlee.Parent then
            pcall(function()
                cameraControlee.CameraType = cameraTypeSauve or Enum.CameraType.Custom
            end)
        end
        cameraControlee = camera
        cameraTypeSauve = camera.CameraType
        local racine = racineLocale()
        cameraOffsetSauve = racine and (camera.CFrame.Position - racine.Position) or nil
        cameraPositionFiltree = camera.CFrame.Position
        cameraRotationFiltree = camera.CFrame.Rotation
        cameraCibleFiltree, cameraTetePrecedente = nil, nil
    end
    if not cameraRenderBound then
        local ok = pcall(function()
            RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
            RunService:BindToRenderStep(
                CAMERA_BIND_NAME,
                Enum.RenderPriority.Last.Value,
                function(dt)
                    if appliquerCameraBackground then appliquerCameraBackground(dt) end
                end
            )
        end)
        cameraRenderBound = ok
    end
end

appliquerCameraBackground = function(dt)
    if not (backgroundAimEnabled and farmActif) then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    if camera ~= cameraControlee then
        activerCameraBackground()
        if camera ~= cameraControlee then return end
    end
    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end

    local pas = math.clamp(dt or (1 / 60), 1 / 240, 0.05)
    local racine = racineLocale()
    if racine and not cameraOffsetSauve then
        cameraOffsetSauve = camera.CFrame.Position - racine.Position
    end

    -- Position posee sur la racine physique, avec amortissement anti-jitter.
    local souhait = cameraPositionFiltree or camera.CFrame.Position
    if racine and cameraOffsetSauve then
        souhait = racine.Position + cameraOffsetSauve
    end
    cameraPositionFiltree = (cameraPositionFiltree or souhait):Lerp(
        souhait, 1 - math.exp(-pas * 14)
    )

    local tete = backgroundHead
    if tete and tete.Parent and tete:IsA("BasePart") then
        if tete ~= cameraTetePrecedente or not cameraCibleFiltree then
            cameraTetePrecedente = tete
            cameraCibleFiltree = tete.Position
        else
            cameraCibleFiltree = cameraCibleFiltree:Lerp(
                tete.Position, 1 - math.exp(-pas * 18)
            )
        end

        if (cameraCibleFiltree - cameraPositionFiltree).Magnitude > 0.05 then
            local cibleRotation = CFrame.lookAt(
                cameraPositionFiltree, cameraCibleFiltree
            ).Rotation
            cameraRotationFiltree = (cameraRotationFiltree or cibleRotation):Lerp(
                cibleRotation, 1 - math.exp(-pas * 11)
            )
        end
    else
        cameraTetePrecedente, cameraCibleFiltree = nil, nil
    end

    -- Ne jamais se synchroniser sur la rotation du jeu : elle peut etre ecrasee.
    if not cameraRotationFiltree then
        cameraRotationFiltree = camera.CFrame.Rotation
    end
    camera.CFrame = CFrame.new(cameraPositionFiltree) * cameraRotationFiltree
    camera.Focus = CFrame.new(
        cameraCibleFiltree or (cameraPositionFiltree + cameraRotationFiltree.LookVector * 20)
    )
end

local function coordonneesFarm()
    if backgroundAimEnabled and farmActif then
        local camera = workspace.CurrentCamera
        if camera then
            return camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5
        end
    end
    local souris = UserInputService:GetMouseLocation()
    return souris.X, souris.Y
end

local modePauseActif = false -- FARM seul : continu. FARM + Undetect : 15 s / 40 s.
local cache = {}
local blacklist = {}
local premierVisible = {}
local scanEnCours = false
local dernierTir = 0
local tirEnCours = false
local dernierAppui = 0
local clicDroitMaintenu = false
local vagueEnCours = false
local premierTirDeLaVague = false
local lootEnCours = false
local dernierLoot = 0
local promptsLoot = {}
local dernierPrompt = setmetatable({}, {__mode = "k"})
local connexionsPrompts = {}
-- Branchement de l'indicateur du menu (le menu est construit plus bas).
local afficherEtatFarm = function() end
local visee = {
    tete = nil,
    debut = 0,
    dernierTemps = 0,
    reaction = 0,
    vx = 0, vy = 0,
    microX = 0, microY = 0,
    cibleMicroX = 0, cibleMicroY = 0,
    prochaineMicro = 0,
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = false

local function headDuHood(modele)
    -- IMPORTANT : ne jamais remplacer Head par HumanoidRootPart, Torso, etc.
    local tete = modele:FindFirstChild("Head")
    if tete and tete:IsA("BasePart") then
        return tete
    end
    return nil
end

local function estHood(modele)
    return modele and modele:IsA("Model")
        and modele.Name:upper():find("HOOD", 1, true) ~= nil
        and Players:GetPlayerFromCharacter(modele) == nil
end

local function estIgnore(modele)
    local jusqua = blacklist[modele]
    if not jusqua then return false end
    if os.clock() >= jusqua then
        blacklist[modele] = nil
        return false
    end
    return true
end

local function ignorerHood(modele)
    if modele then
        blacklist[modele] = os.clock() + CFG.Blacklist
        premierVisible[modele] = nil
    end
end

local function personnagesJoueurs()
    local liste = {}
    for _, joueur in ipairs(Players:GetPlayers()) do
        if joueur.Character then
            table.insert(liste, joueur.Character)
        end
    end
    return liste
end

-- On refuse une cible cachee par un mur depuis la camera ET depuis
-- la tete du personnage. Aucune exception pour les obstacles proches de Head.
-- On exclut notre propre personnage pour ne pas bloquer le raycast.
local function visible(tete, modele)
    if not tete or not tete.Parent or not modele or not modele.Parent then
        return false
    end
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local personnage = joueurLocal.Character
    local teteLocale = personnage and personnage:FindFirstChild("Head")
    rayParams.FilterDescendantsInstances = personnage and {personnage} or {}

    local function rayonLibre(origine)
        local direction = tete.Position - origine
        if direction.Magnitude <= 0.02 then return true end
        local impact = workspace:Raycast(origine, direction, rayParams)
        return (impact == nil) or impact.Instance:IsDescendantOf(modele)
    end

    if not rayonLibre(camera.CFrame.Position) then return false end
    if teteLocale and not rayonLibre(teteLocale.Position) then return false end
    return true
end

local function dansFOV(position)
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local direction = position - camera.CFrame.Position
    if direction.Magnitude < 0.1 then return true end

    local angle = CFG.FOV
    if #cache > CFG.FOVLargeApres then
        angle = math.max(angle, CFG.FOVLarge)
    end
    return camera.CFrame.LookVector:Dot(direction.Unit)
        >= math.cos(math.rad(angle))
end

local function scanner(id)
    if scanEnCours then return end
    scanEnCours = true

    task.spawn(function()
        local ok, liste = pcall(function()
            local trouves = {}
            local perso = joueurLocal.Character
            local teteLocale = perso and perso:FindFirstChild("Head")
            local camera = workspace.CurrentCamera
            local origine = teteLocale and teteLocale.Position
                or (camera and camera.CFrame.Position)
            if not origine then return trouves end

            local personnages = {}
            for _, joueur in ipairs(Players:GetPlayers()) do
                if joueur.Character then personnages[joueur.Character] = true end
            end

            local objets = workspace:GetDescendants()
            for index, objet in ipairs(objets) do
                if farmId ~= id then return trouves end

                if objet:IsA("Humanoid") and objet.Health > 0 then
                    local modele = objet.Parent
                    if estHood(modele) and not personnages[modele] then
                        local tete = headDuHood(modele)
                        if tete then
                            local distance = (tete.Position - origine).Magnitude
                            if distance <= CFG.DistScan then
                                table.insert(trouves, {
                                    model = modele,
                                    hum = objet,
                                    head = tete,
                                    dist = distance,
                                })
                            end
                        end
                    end
                end

                -- Comme Local S, on répartit les scans volumineux sur plusieurs frames.
                if index % 600 == 0 then task.wait() end
            end
            table.sort(trouves, function(a, b) return a.dist < b.dist end)
            return trouves
        end)

        if ok and farmId == id then
            cache = liste
            local presents = {}
            for _, cible in ipairs(liste) do presents[cible.model] = true end
            for modele in pairs(premierVisible) do
                if not presents[modele] then premierVisible[modele] = nil end
            end
        end
        scanEnCours = false
    end)
end

local function cibleValide(cible)
    return cible and cible.model and cible.model.Parent
        and cible.hum and cible.hum.Parent and cible.hum.Health > 0
        and cible.head and cible.head.Parent
        and cible.head.Name == "Head"
        and cible.head:IsDescendantOf(cible.model)
        and not estIgnore(cible.model)
end

local function nbVivants()
    -- Le seuil de 10 doit compter tous les Hood en vie, meme ceux places
    -- temporairement en blacklist pour manque de degats.
    local total = 0
    for _, cible in ipairs(cache) do
        if cible.model and cible.model.Parent
            and cible.hum and cible.hum.Parent and cible.hum.Health > 0
            and cible.head and cible.head.Parent then
            total += 1
        end
    end
    return total
end

-- Ne choisit que les Hood dans le FOV ET dont la tete est visible.
-- Aucun retour vers le Hood le plus proche s'il se trouve derriere un mur.
local function choisirCible(modeleVerrouille)
    local camera = workspace.CurrentCamera
    local personnage = joueurLocal.Character
    local teteLocale = personnage and personnage:FindFirstChild("Head")
    if not camera or not teteLocale then return nil end

    -- Eviter de changer de Hood chaque image quand les scores sont proches.
    if modeleVerrouille then
        for _, actuelle in ipairs(cache) do
            if actuelle.model == modeleVerrouille and cibleValide(actuelle) then
                local dist = (actuelle.head.Position - teteLocale.Position).Magnitude
                if dist <= CFG.DistLock and dansFOV(actuelle.head.Position)
                    and visible(actuelle.head, actuelle.model) then
                    return actuelle
                end
            end
        end
    end

    local meilleure, meilleurScore = nil, math.huge
    for _, cible in ipairs(cache) do
        if cibleValide(cible) then
            local direction = cible.head.Position - teteLocale.Position
            local distance = direction.Magnitude
            if distance <= CFG.DistLock and dansFOV(cible.head.Position)
                and visible(cible.head, cible.model) then
                local depuisCamera = cible.head.Position - camera.CFrame.Position
                if depuisCamera.Magnitude > 0 then
                    local ecartAngle = 1 - camera.CFrame.LookVector:Dot(depuisCamera.Unit)
                    local score = distance + ecartAngle * 18
                    if score < meilleurScore then
                        meilleurScore, meilleure = score, cible
                    end
                end
            end
        end
    end
    return meilleure
end

-- Reprise de la logique souris/camera de Local S avec une trajectoire plus
-- souple : temps de reaction, acceleration progressive et micro-corrections.
-- On conserve les verifications de Head / curseur pour le tir.
local function preparerVisee(tete)
    local maintenant = os.clock()
    if not tete then
        backgroundHead = nil
    end
    visee.tete = tete
    visee.debut = maintenant
    visee.dernierTemps = maintenant
    visee.reaction = rng:NextNumber(CFG.ReactionMin, CFG.ReactionMax)
    visee.vx, visee.vy = 0, 0
    visee.microX, visee.microY = 0, 0
    visee.cibleMicroX = rng:NextNumber(-CFG.MicroAmplitude, CFG.MicroAmplitude)
    visee.cibleMicroY = rng:NextNumber(-CFG.MicroAmplitude, CFG.MicroAmplitude)
    visee.prochaineMicro = maintenant + rng:NextNumber(CFG.MicroMin, CFG.MicroMax)
end

local function viserTete(tete)
    local camera = workspace.CurrentCamera
    if not camera or not tete or not tete.Parent then return false end
    if visee.tete ~= tete then preparerVisee(tete) end

    local maintenant = os.clock()
    local dt = math.clamp(maintenant - visee.dernierTemps, 0.004, 0.06)
    visee.dernierTemps = maintenant
    local tempsVisee = maintenant - visee.debut - visee.reaction
    if tempsVisee < 0 then return false end

    local progression = math.clamp(tempsVisee / CFG.Acceleration, 0, 1)
    local acceleration = progression * progression * (3 - 2 * progression)

    if maintenant >= visee.prochaineMicro then
        visee.cibleMicroX = rng:NextNumber(-CFG.MicroAmplitude, CFG.MicroAmplitude)
        visee.cibleMicroY = rng:NextNumber(-CFG.MicroAmplitude, CFG.MicroAmplitude)
        visee.prochaineMicro = maintenant + rng:NextNumber(CFG.MicroMin, CFG.MicroMax)
    end
    local progressionMicro = 1 - math.exp(-dt * 5)
    visee.microX += (visee.cibleMicroX - visee.microX) * progressionMicro
    visee.microY += (visee.cibleMicroY - visee.microY) * progressionMicro

    local positionVisee = tete.Position
        + camera.CFrame.RightVector * visee.microX
        + camera.CFrame.UpVector * visee.microY

    if backgroundAimEnabled and farmActif then
        -- L'orientation est uniquement appliquee dans la boucle de rendu.
        backgroundHead = tete
        if not cameraRenderBound then activerCameraBackground() end
        return true
    end

    local ecran, dansEcran = camera:WorldToViewportPoint(positionVisee)
    if not dansEcran and not CFG.OffscreenPull then return false end

    local centreX = camera.ViewportSize.X * 0.5
    local centreY = camera.ViewportSize.Y * 0.5
    local x, y = ecran.X, ecran.Y
    if ecran.Z < 0 then
        x = centreX - (x - centreX)
        y = centreY - (y - centreY)
    end
    local dx, dy = x - centreX, y - centreY
    local distance = math.sqrt(dx * dx + dy * dy)

    local gain = math.clamp(distance / 90, 0.05, 0.8)
    local montee = 0.18 + 0.82 * acceleration
    local vitesseX = math.clamp(dx * CFG.Sensibilite * gain, -CFG.DeltaMax, CFG.DeltaMax) * montee
    local vitesseY = math.clamp(dy * CFG.Sensibilite * gain, -CFG.DeltaMax, CFG.DeltaMax) * montee
    -- La vitesse met du temps a rejoindre la vitesse desiree : aucun teleport/snap.
    local amortissement = 1 - math.exp(-dt * (9 + 13 * acceleration))
    visee.vx += (vitesseX - visee.vx) * amortissement
    visee.vy += (vitesseY - visee.vy) * amortissement
    if distance < 10 then
        visee.vx *= 0.55
        visee.vy *= 0.55
    end

    if distance > 2 then
        local mx = visee.vx * math.clamp(dt * 60, 0.6, 1.4)
        local my = visee.vy * math.clamp(dt * 60, 0.6, 1.4)
        local deplacee = false
        if typeof(mousemoverel) == "function" then
            deplacee = pcall(mousemoverel, mx, my)
        end
        if not deplacee and typeof(mousemoveabs) == "function" then
            local souris = UserInputService:GetMouseLocation()
            deplacee = pcall(mousemoveabs, souris.X + mx, souris.Y + my)
        end
        -- Un seul deplacement par frame : evite depassements et secousses.
        if not deplacee then
            pcall(function()
                local souris = UserInputService:GetMouseLocation()
                VIM:SendMouseMoveEvent(souris.X + mx, souris.Y + my, game)
            end)
        end
    end

    if CFG.CameraAssist > 0 then
        pcall(function()
            local vitesseCamera = CFG.CameraAssist * (0.20 + 0.80 * acceleration)
            local alpha = math.clamp(vitesseCamera * dt * 60, 0.004, 0.075)
            camera.CFrame = camera.CFrame:Lerp(
                CFrame.new(camera.CFrame.Position, positionVisee), alpha
            )
        end)
    end
    return true
end

-- Différence essentielle avec l'ancien Farm : Local S vérifie la position
-- de la souris par rapport à la projection de Head, pas au centre de l'écran.
local function curseurSurTete(tete)
    local camera = workspace.CurrentCamera
    if not camera or not tete or not tete.Parent then return false end

    local pixel, visibleEcran = camera:WorldToViewportPoint(tete.Position)
    if not visibleEcran or pixel.Z <= 0 then return false end

    if backgroundAimEnabled and farmActif then
        -- En mode sans souris, l'alignement se mesure au centre du viseur.
        local centreX = camera.ViewportSize.X * 0.5
        local centreY = camera.ViewportSize.Y * 0.5
        local dx = centreX - pixel.X
        local dy = centreY - pixel.Y
        return math.sqrt(dx * dx + dy * dy) < math.min(CFG.Tolerance, 18)
    end
    local souris = UserInputService:GetMouseLocation()
    local dx = souris.X - pixel.X
    local dy = souris.Y - pixel.Y
    return math.sqrt(dx * dx + dy * dy) < CFG.Tolerance
end

-- Comme dans Local S : maintenir le bouton droit (index 1) tant qu'une
-- cible est verrouillee. Le bouton gauche (index 0) reste reserve au tir.
local function relacherClicDroit()
    if not clicDroitMaintenu then return end
    clicDroitMaintenu = false
    pcall(function()
        local mouseX, mouseY = coordonneesFarm()
        VIM:SendMouseButtonEvent(mouseX, mouseY, 1, false, game, 0)
    end)
end

local function activerClicDroit()
    if clicDroitMaintenu then return true end
    local ok = pcall(function()
        local mouseX, mouseY = coordonneesFarm()
        VIM:SendMouseButtonEvent(mouseX, mouseY, 1, true, game, 0)
    end)
    clicDroitMaintenu = ok
    return ok
end

local function relacherTir()
    pcall(function()
        local mouseX, mouseY = coordonneesFarm()
        VIM:SendMouseButtonEvent(mouseX, mouseY, 0, false, game, 0)
    end)
    tirEnCours = false
end

local function tirer(id)
    local maintenant = os.clock()
    if maintenant - dernierTir < CFG.DelaiTir then return false end
    if tirEnCours then return false end

    dernierTir = maintenant
    tirEnCours = true
    local mouseX, mouseY = coordonneesFarm()
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(mouseX, mouseY, 0, true, game, 0)
    end)
    if not ok then
        tirEnCours = false
        return false
    end

    local appui = dernierAppui + 1
    dernierAppui = appui
    task.delay(0.040, function()
        if farmId == id and dernierAppui == appui then
            relacherTir()
        end
    end)
    return true
end

-- Systeme de recuperation de Local S, pendant le combat continu ou temporise.
-- Le script source envoyait E (15 ms) toutes les 0.04 seconde et tentait tous
-- les ProximityPrompt actifs a moins de 45 studs, avec cooldown de 0.05 s.
-- Ici le systeme demarre au PREMIER tir de la vague et cesse des la pause.
local function libererE()
    pcall(function()
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function enregistrerPrompts()
    for _, objet in ipairs(workspace:GetDescendants()) do
        if objet:IsA("ProximityPrompt") then
            promptsLoot[objet] = true
        end
    end
    table.insert(connexionsPrompts, workspace.DescendantAdded:Connect(function(objet)
        if objet:IsA("ProximityPrompt") then promptsLoot[objet] = true end
    end))
    table.insert(connexionsPrompts, workspace.DescendantRemoving:Connect(function(objet)
        promptsLoot[objet] = nil
        dernierPrompt[objet] = nil
    end))
end

local function nettoyerPrompts()
    for _, connexion in ipairs(connexionsPrompts) do
        connexion:Disconnect()
    end
    connexionsPrompts = {}
    promptsLoot = {}
    dernierPrompt = setmetatable({}, {__mode = "k"})
end

local function positionPrompt(prompt)
    local parent = prompt.Parent
    if not parent then return nil end
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("Model") then
        local part = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
        return part and part.Position or nil
    end
    return nil
end

local function spamEUneFois(id)
    if farmId ~= id or not vagueEnCours or not premierTirDeLaVague then return end
    local maintenant = os.clock()
    if lootEnCours or maintenant - dernierLoot < CFG.LootCheckRate then return end
    dernierLoot = maintenant
    lootEnCours = true

    task.spawn(function()
        pcall(function()
            local perso = joueurLocal.Character
            local racine = perso and perso:FindFirstChild("HumanoidRootPart")
            if not racine then return end
            if farmId ~= id or not vagueEnCours or not premierTirDeLaVague then return end

            -- Identique a la source : un appui court sur E, suivi d'un relachement.
            VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(CFG.LootKeyHold)
            libererE()
            if farmId ~= id or not vagueEnCours then return end

            local position = racine.Position
            local instant = os.clock()
            for prompt in pairs(promptsLoot) do
                if farmId ~= id or not vagueEnCours then break end
                if prompt and prompt.Parent and prompt.Enabled then
                    local precedent = dernierPrompt[prompt]
                    if not precedent or instant - precedent > CFG.LootCooldown then
                        local positionObjet = positionPrompt(prompt)
                        if positionObjet and (positionObjet - position).Magnitude <= CFG.LootRange then
                            dernierPrompt[prompt] = instant
                            pcall(function()
                                prompt.HoldDuration = 0
                                prompt.RequiresLineOfSight = false
                                prompt.MaxActivationDistance = math.max(
                                    prompt.MaxActivationDistance, CFG.LootRange
                                )
                            end)
                            if typeof(fireproximityprompt) == "function" then
                                pcall(fireproximityprompt, prompt)
                            end
                        end
                    end
                else
                    promptsLoot[prompt] = nil
                    dernierPrompt[prompt] = nil
                end
            end
        end)
        -- Toujours liberer la touche meme en cas d'erreur ou d'arret.
        libererE()
        lootEnCours = false
    end)
end

-- Un unique appui sur R entre deux cycles, sans appuyer si le farm est coupe.
local function rechargerEntreVagues(id)
    if farmId ~= id then return end
    afficherEtatFarm(0, "Rechargement : R")
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
    end)
    task.wait(0.09)
    -- Liberation garantie meme si le farm a ete desactive pendant l'appui.
    pcall(function()
        VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
    end)
end

local function boucleFarm(id)
    -- FARM seul : combat continu, sans rechargement automatique ni pause.
    -- Si Undetect est actif : 15 secondes de combat / R / 40 secondes de pause.
    -- Un changement d'option pendant le farm redemarre proprement le cycle
    -- sans desactiver le toggle FARM ZOMBIE.
    while farmId == id do
        local cycleAvecPauses = modePauseActif
        local cibleActuelle, viePrecedente = nil, 0
        local depuisDegats, tirsSurCible = 0, 0
        local debutCombat = os.clock()
        local prochainStatut = 0

        blacklist = {}
        premierVisible = {}
        preparerVisee(nil)
        vagueEnCours = true
        premierTirDeLaVague = false
        if cycleAvecPauses then
            afficherEtatFarm(0, "Combat : 15 s | E apres le 1er tir")
        else
            afficherEtatFarm(0, "Continu | E apres le 1er tir")
        end

        while farmId == id and modePauseActif == cycleAvecPauses
            and (not cycleAvecPauses or os.clock() - debutCombat < CFG.DureeCombat) do
            local cible = choisirCible(cibleActuelle) -- Conserver le verrou si possible.
            local maintenant = os.clock()

            if maintenant >= prochainStatut then
                if cycleAvecPauses then
                    local restantes = math.max(0, math.ceil(CFG.DureeCombat - (maintenant - debutCombat)))
                    afficherEtatFarm(0, string.format("Combat : %ds | E %s",
                        restantes, premierTirDeLaVague and "ON" or "OFF"))
                else
                    afficherEtatFarm(0, string.format("Continu | E %s",
                        premierTirDeLaVague and "ON" or "OFF"))
                end
                prochainStatut = maintenant + 0.25
            end

            if cible then
                activerClicDroit()
                if cible.model ~= cibleActuelle then
                    cibleActuelle = cible.model
                    viePrecedente = cible.hum.Health
                    depuisDegats = maintenant
                    tirsSurCible = 0
                    preparerVisee(cible.head)
                end

                if not premierVisible[cible.model] then
                    premierVisible[cible.model] = maintenant
                end

                local viseeActive = viserTete(cible.head)
                if cible.hum.Health < viePrecedente then
                    viePrecedente = cible.hum.Health
                    depuisDegats = maintenant
                elseif maintenant - depuisDegats >= CFG.ReactionSansDegats then
                    ignorerHood(cible.model)
                    cibleActuelle = nil
                end

                if cibleActuelle == cible.model and cibleValide(cible)
                    and viseeActive
                    and maintenant - premierVisible[cible.model] >= CFG.VisibleFireDelay
                    and curseurSurTete(cible.head)
                    and visible(cible.head, cible.model) then
                    local perso = joueurLocal.Character
                    local teteLocale = perso and perso:FindFirstChild("Head")
                    if teteLocale
                        and (cible.head.Position - teteLocale.Position).Magnitude <= CFG.DistTir then
                        if tirer(id) then
                            premierTirDeLaVague = true
                            tirsSurCible += 1
                            if tirsSurCible >= CFG.MaxTirsParCible then
                                ignorerHood(cible.model)
                                cibleActuelle = nil
                            end
                        end
                    end
                end
            else
                cibleActuelle = nil
                relacherClicDroit()
                preparerVisee(nil)
            end
            task.wait(CFG.MoveRate)
        end
        if farmId ~= id then break end

        -- Fin d'un cycle ou changement de mode : relacher toutes les touches.
        vagueEnCours = false
        premierTirDeLaVague = false
        libererE()
        relacherTir()
        relacherClicDroit()
        preparerVisee(nil)

        -- On ne recharge et ne fait la pause QUE si le combat temporise
        -- s'est acheve, et si Undetect est toujours actif.
        if cycleAvecPauses and modePauseActif and farmId == id then
            rechargerEntreVagues(id)
            if farmId ~= id then break end

            local debutPause = os.clock()
            while farmId == id and modePauseActif
                and os.clock() - debutPause < CFG.PauseCycle do
                local restantes = math.max(0, math.ceil(CFG.PauseCycle - (os.clock() - debutPause)))
                afficherEtatFarm(0, string.format("Pause : %ds | E OFF", restantes))
                task.wait(0.12)
            end
        end
    end
end

local function demarrerFarm()
    -- Invalider toutes les anciennes boucles et relancer un cycle de 15/40 s.
    farmActif = true
    activerCameraBackground()
    farmId += 1
    local id = farmId
    nettoyerPrompts()
    cache = {}
    blacklist = {}
    premierVisible = {}
    dernierTir = 0
    dernierAppui += 1
    dernierLoot = 0
    lootEnCours = false
    vagueEnCours = false
    premierTirDeLaVague = false
    preparerVisee(nil)
    libererE()
    relacherTir()
    relacherClicDroit()
    enregistrerPrompts()
    afficherEtatFarm(0, "Demarrage du combat")

    scanner(id)
    task.spawn(function()
        while farmId == id do
            scanner(id)
            task.wait(CFG.ScanInterval)
        end
    end)
    task.spawn(function()
        while farmId == id do
            if vagueEnCours and premierTirDeLaVague then
                spamEUneFois(id)
            end
            task.wait(0.012)
        end
    end)
    task.spawn(boucleFarm, id)
end

local function arreterFarm()
    farmActif = false
    libererCameraBackground()
    farmId += 1
    afficherEtatFarm(0, "Arrete | E OFF")
    vagueEnCours = false
    premierTirDeLaVague = false
    dernierAppui += 1
    libererE()
    relacherTir()
    relacherClicDroit()
    pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game) end)
    nettoyerPrompts()
    cache = {}
    blacklist = {}
    premierVisible = {}
    preparerVisee(nil)
end

-- ================= ANTI DANCE (inspire de Local S) =================
-- Observe l'attribut DanceId et simule "2" si une danse est en cours.
-- Fonction indépendante du farm, activable et désactivable par l'interface / F3.
local antiDanceActif = false
local antiDanceGeneration = 0
local DANCE_DELAY = 0.35
local DANCE_CHECK = 0.12
local dernierAntiDance = 0

local function danseEnCours()
    local personnage = joueurLocal.Character
    if not personnage then return false end
    local id = personnage:GetAttribute("DanceId")
    if id == nil then return false end
    if type(id) == "number" then return id ~= 0 end
    if type(id) == "string" then
        local v = string.lower(id)
        return v ~= "" and v ~= "0" and v ~= "qmod" and v ~= "none" and v ~= "nil"
    end
    return false
end

local function antiDanceAppui()
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Two, false, game)
        task.wait(0.04)
        VIM:SendKeyEvent(false, Enum.KeyCode.Two, false, game)
    end)
end

local function configurerAntiDance(active)
    active = (active == true)
    if antiDanceActif == active then return end
    antiDanceActif = active
    antiDanceGeneration += 1
    local id = antiDanceGeneration
    if not active then return end
    dernierAntiDance = 0
    task.spawn(function()
        while antiDanceActif and id == antiDanceGeneration do
            local maintenant = os.clock()
            if danseEnCours() and maintenant - dernierAntiDance >= DANCE_DELAY then
                dernierAntiDance = maintenant
                antiDanceAppui()
            end
            task.wait(DANCE_CHECK)
        end
    end)
end

-- ================= WORLD : MODES GRAPHIQUES REVERSIBLES V27 =================
-- FULL FPS : sans ombres globales, post-effets et particules.
-- POTATO   : simplifie les materiaux/textures en plus des effets.
-- NORMAL   : restaure les valeurs sauvegardees (sans detruire d'objets).
-- Ne modifie jamais collision, raycasts, scripts ou simulation Roblox.
local Lighting = game:GetService("Lighting")
local worldMode = "NORMAL"
local worldGeneration = 0
local worldSnapshots = setmetatable({}, {__mode = "k"})
local worldConnections = {}
local worldFPSAvant = nil
local worldFPSModifie = false

local function worldChanger(objet, propriete, nouvelleValeur)
    if not objet then return end
    local okLecture, valeurAvant = pcall(function() return objet[propriete] end)
    if not okLecture or valeurAvant == nouvelleValeur then return end
    local okEcriture = pcall(function() objet[propriete] = nouvelleValeur end)
    if not okEcriture then return end
    local sauvegarde = worldSnapshots[objet]
    if not sauvegarde then
        sauvegarde = {}
        worldSnapshots[objet] = sauvegarde
    end
    if sauvegarde[propriete] == nil then
        sauvegarde[propriete] = valeurAvant
    end
end

local function worldAppliquerObjet(objet, mode)
    if not objet or not objet.Parent or mode == "NORMAL" then return end
    local potato = mode == "POTATO"

    if objet == Lighting then
        worldChanger(objet, "GlobalShadows", false)
        worldChanger(objet, "ShadowSoftness", 0)
        if potato then
            worldChanger(objet, "EnvironmentDiffuseScale", 0)
            worldChanger(objet, "EnvironmentSpecularScale", 0)
        end
    elseif objet:IsA("BasePart") then
        worldChanger(objet, "CastShadow", false)
        if potato then
            -- Materiaux des decors fixes uniquement : aucune physique modifiee.
            if objet.Anchored then
                worldChanger(objet, "Material", Enum.Material.SmoothPlastic)
                worldChanger(objet, "MaterialVariant", "")
            end
            worldChanger(objet, "Reflectance", 0)
            if objet:IsA("MeshPart") then
                worldChanger(objet, "TextureID", "")
                worldChanger(objet, "RenderFidelity", Enum.RenderFidelity.Performance)
            end
        end
    elseif objet:IsA("PostEffect")
        or objet:IsA("ParticleEmitter") or objet:IsA("Trail")
        or objet:IsA("Beam") or objet:IsA("Fire")
        or objet:IsA("Smoke") or objet:IsA("Sparkles") then
        worldChanger(objet, "Enabled", false)
    elseif potato then
        if objet:IsA("Decal") or objet:IsA("Texture") then
            worldChanger(objet, "Transparency", 1)
        elseif objet:IsA("SpecialMesh") then
            worldChanger(objet, "TextureId", "")
        elseif objet:IsA("SurfaceAppearance") then
            for _, propriete in ipairs({"ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap"}) do
                worldChanger(objet, propriete, "")
            end
        elseif objet:IsA("Atmosphere") then
            worldChanger(objet, "Density", 0)
            worldChanger(objet, "Haze", 0)
            worldChanger(objet, "Glare", 0)
        elseif objet:IsA("Clouds") then
            worldChanger(objet, "Cover", 0)
        elseif objet:IsA("Sky") then
            worldChanger(objet, "CelestialBodiesShown", false)
            worldChanger(objet, "StarCount", 0)
        elseif objet:IsA("Terrain") then
            worldChanger(objet, "Decoration", false)
            worldChanger(objet, "WaterWaveSize", 0)
            worldChanger(objet, "WaterWaveSpeed", 0)
            worldChanger(objet, "WaterReflectance", 0)
        elseif objet:IsA("PointLight") or objet:IsA("SpotLight")
            or objet:IsA("SurfaceLight") then
            worldChanger(objet, "Enabled", false)
        end
    end
end

local function restaurerWorld()
    worldGeneration += 1
    worldMode = "NORMAL"

    for _, connexion in ipairs(worldConnections) do
        pcall(function() connexion:Disconnect() end)
    end
    worldConnections = {}

    local copies = worldSnapshots
    worldSnapshots = setmetatable({}, {__mode = "k"})
    for objet, proprietes in pairs(copies) do
        if objet and objet.Parent then
            for propriete, valeur in pairs(proprietes) do
                pcall(function() objet[propriete] = valeur end)
            end
        end
    end

    if worldFPSModifie and type(setfpscap) == "function"
        and type(worldFPSAvant) == "number" then
        pcall(setfpscap, worldFPSAvant)
    end
    worldFPSAvant = nil
    worldFPSModifie = false
end

-- Si une V27+ tourne deja, restaurer son World avant d'enregistrer la nouvelle.
local registreWorld = nil
pcall(function()
    if type(getgenv) == "function" then
        local environnement = getgenv()
        if type(environnement) == "table" then registreWorld = environnement end
    end
    if not registreWorld and type(shared) == "table" then registreWorld = shared end
end)
if registreWorld and type(registreWorld.U0BC_RestoreWorld) == "function" then
    pcall(registreWorld.U0BC_RestoreWorld)
end
if registreWorld then registreWorld.U0BC_RestoreWorld = restaurerWorld end

local function definirWorldMode(mode)
    if mode ~= "NORMAL" and mode ~= "FULL FPS" and mode ~= "POTATO" then return end
    if worldMode == mode then return end

    restaurerWorld()
    if mode == "NORMAL" then return end

    worldMode = mode
    worldGeneration += 1
    local generation = worldGeneration
    worldAppliquerObjet(Lighting, mode)

    -- Limiter les FPS en POTATO seulement si l'ancienne limite est lisible,
    -- afin de pouvoir la restaurer exactement en mode NORMAL.
    if mode == "POTATO" and type(getfpscap) == "function"
        and type(setfpscap) == "function" then
        local ok, limite = pcall(getfpscap)
        if ok and type(limite) == "number"
            and (limite > 20 or limite <= 0) then
            local applique = pcall(setfpscap, 20)
            if applique then
                worldFPSAvant = limite
                worldFPSModifie = true
            end
        end
    end

    local function surveillerAjouts(parent)
        table.insert(worldConnections, parent.DescendantAdded:Connect(function(objet)
            task.defer(function()
                if worldGeneration == generation and worldMode == mode then
                    worldAppliquerObjet(objet, mode)
                end
            end)
        end))
    end
    surveillerAjouts(workspace)
    surveillerAjouts(Lighting)

    -- Parcours progressif : ne pas bloquer le menu sur les grandes maps.
    task.spawn(function()
        local function balayer(parent)
            local objets = parent:GetDescendants()
            for index, objet in ipairs(objets) do
                if worldGeneration ~= generation or worldMode ~= mode then return false end
                worldAppliquerObjet(objet, mode)
                if index % 300 == 0 then task.wait() end
            end
            return true
        end
        if not balayer(Lighting) then return end
        balayer(workspace)
    end)
end

-- ================= U0BC | INTERFACE V27 =================
-- Menus : AIM, VISUAL, WORLD, MISC. Art original inspire de la structure verre/neon
-- de Local S, avec une palette ardoise/violet/cyan et un fond anime.
local T = {
    bg = Color3.fromRGB(7, 7, 9),
    surface = Color3.fromRGB(14, 14, 18),
    surface2 = Color3.fromRGB(20, 20, 26),
    row = Color3.fromRGB(18, 18, 23),
    hover = Color3.fromRGB(34, 16, 20),
    border = Color3.fromRGB(120, 25, 33),
    text = Color3.fromRGB(245, 245, 248),
    muted = Color3.fromRGB(170, 145, 150),
    cyan = Color3.fromRGB(226, 30, 48),
    purple = Color3.fromRGB(120, 16, 28),
    green = Color3.fromRGB(255, 76, 92),
    red = Color3.fromRGB(255, 64, 82),
    off = Color3.fromRGB(54, 26, 30),
}

local function corner(obj, px)
    local v = Instance.new("UICorner")
    v.CornerRadius = UDim.new(0, px)
    v.Parent = obj
    return v
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or T.border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = obj
    return s
end

local function addGui(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function tween(obj, duration, properties, easing)
    if not obj or not obj.Parent then return end
    local animation = TweenService:Create(obj,
        TweenInfo.new(duration, easing or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        properties)
    animation:Play()
    return animation
end

local racineGui
pcall(function()
    if type(gethui) == "function" then racineGui = gethui() end
end)
if not racineGui then racineGui = joueurLocal:WaitForChild("PlayerGui") end

local ancienne = racineGui:FindFirstChild("U0BC_ControlCenter")
if ancienne then ancienne:Destroy() end
local ancienESP = racineGui:FindFirstChild("U0BC_PlayerESP_UI")
if ancienESP then ancienESP:Destroy() end
local ancienneMenu = racineGui:FindFirstChild("MenuModerne")
if ancienneMenu then ancienneMenu:Destroy() end

local gui = addGui("ScreenGui", racineGui, {
    Name = "U0BC_ControlCenter",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 998,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local window = addGui("Frame", gui, {
    Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(650, 448),
    BackgroundColor3 = T.bg, BorderSizePixel = 0,
    ClipsDescendants = true,
})
corner(window, 18)
-- Dimension compacte : contenu base 650x448 mis a l'echelle 80 % (520x358).
-- UIScale evite de casser les alignements, animations et espacements internes.
local uiScale = Instance.new("UIScale")
uiScale.Name = "CompactScale"
uiScale.Scale = 0.80
uiScale.Parent = window
local windowStroke = stroke(window, T.border, 1.3, 0.25)

local backgroundGradient = addGui("UIGradient", window, {
    Rotation = 32,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 5)),
        ColorSequenceKeypoint.new(0.38, Color3.fromRGB(18, 8, 11)),
        ColorSequenceKeypoint.new(0.72, Color3.fromRGB(42, 10, 16)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 6, 8)),
    }),
})
-- Mouvement discret permanent du fond, sans images externes.
TweenService:Create(backgroundGradient,
    TweenInfo.new(18, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
    {Rotation = 392}):Play()

local auraViolette = addGui("Frame", window, {
    Name = "AuraViolet", Position = UDim2.fromOffset(370, -170),
    Size = UDim2.fromOffset(290, 290),
    BackgroundColor3 = Color3.fromRGB(140, 16, 28), BackgroundTransparency = 0.88,
    BorderSizePixel = 0,
})
corner(auraViolette, 200)
local auraCyan = addGui("Frame", window, {
    Name = "AuraCyan", Position = UDim2.fromOffset(-135, 260),
    Size = UDim2.fromOffset(305, 305),
    BackgroundColor3 = Color3.fromRGB(255, 40, 60), BackgroundTransparency = 0.90,
    BorderSizePixel = 0,
})
corner(auraCyan, 200)
TweenService:Create(auraViolette,
    TweenInfo.new(8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {Position = UDim2.fromOffset(290, -105), BackgroundTransparency = 0.955}):Play()
TweenService:Create(auraCyan,
    TweenInfo.new(11, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {Position = UDim2.fromOffset(-40, 165), BackgroundTransparency = 0.97}):Play()

local scanField = addGui("Frame", window, {
    Name = "ScanField", Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1, BorderSizePixel = 0,
})
for i = 0, 18 do
    local line = addGui("Frame", scanField, {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, i * 24),
        BackgroundColor3 = Color3.fromRGB(255, 32, 52),
        BackgroundTransparency = 0.965 + ((i % 3) * 0.008),
        BorderSizePixel = 0,
    })
    line.ZIndex = 0
end
local sweep = addGui("Frame", scanField, {
    Name = "Sweep", Size = UDim2.new(1, 0, 0, 52),
    Position = UDim2.fromOffset(0, -70),
    BackgroundColor3 = Color3.fromRGB(255, 36, 58),
    BackgroundTransparency = 0.965, BorderSizePixel = 0,
})
addGui("UIGradient", sweep, {
    Rotation = 90,
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.45),
        NumberSequenceKeypoint.new(1, 1),
    })
})
TweenService:Create(sweep,
    TweenInfo.new(4.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
    {Position = UDim2.new(0, 0, 1, 18)}):Play()

local header = addGui("Frame", window, {
    Name = "Header", Size = UDim2.new(1, 0, 0, 80),
    BackgroundTransparency = 1,
})
local headerLine = addGui("Frame", header, {
    Position = UDim2.new(0, 23, 1, -1), Size = UDim2.new(1, -46, 0, 1),
    BackgroundColor3 = T.border, BackgroundTransparency = 0.64, BorderSizePixel = 0,
})
local logo = addGui("Frame", header, {
    Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(22, 18),
    BackgroundColor3 = T.surface2, BorderSizePixel = 0,
})
corner(logo, 13)
stroke(logo, T.red, 1.5, 0.16)
addGui("TextLabel", logo, {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Font = Enum.Font.SciFi, Text = "U", TextSize = 24, TextColor3 = T.cyan,
})
addGui("TextLabel", header, {
    Position = UDim2.fromOffset(79, 17), Size = UDim2.fromOffset(310, 28),
    BackgroundTransparency = 1, Text = "URBAN RELOAD",
    Font = Enum.Font.Arcade, TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.text,
})
addGui("TextLabel", header, {
    Position = UDim2.fromOffset(80, 43), Size = UDim2.fromOffset(300, 18),
    BackgroundTransparency = 1, Text = "BY u0bc",
    Font = Enum.Font.Code, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.muted,
})
local version = addGui("TextLabel", header, {
    Position = UDim2.new(1, -169, 0, 27), Size = UDim2.fromOffset(61, 23),
    BackgroundColor3 = T.surface2, BackgroundTransparency = 0.04,
    Font = Enum.Font.Code, TextSize = 10, Text = "V28.0",
    TextColor3 = T.cyan,
})
corner(version, 8)
stroke(version, T.red, 1, 0.52)

local minimizeBtn = addGui("TextButton", header, {
    Position = UDim2.new(1, -92, 0, 23), Size = UDim2.fromOffset(28, 30),
    BackgroundColor3 = T.surface2, BorderSizePixel = 0,
    Text = "–", TextSize = 20, Font = Enum.Font.SciFi,
    TextColor3 = T.muted, AutoButtonColor = false,
})
corner(minimizeBtn, 8)
local closeBtn = addGui("TextButton", header, {
    Position = UDim2.new(1, -54, 0, 23), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = Color3.fromRGB(55, 14, 20), BorderSizePixel = 0,
    Text = "×", TextSize = 23, Font = Enum.Font.SciFi,
    TextColor3 = T.red, AutoButtonColor = false,
})
corner(closeBtn, 8)

local content = addGui("Frame", window, {
    Name = "Content", Position = UDim2.fromOffset(0, 80),
    Size = UDim2.new(1, 0, 1, -115), BackgroundTransparency = 1,
})
local sidebar = addGui("Frame", content, {
    Size = UDim2.fromOffset(164, 328), Position = UDim2.fromOffset(15, 6),
    BackgroundColor3 = T.surface, BackgroundTransparency = 0.23, BorderSizePixel = 0,
})
corner(sidebar, 13)
stroke(sidebar, T.red, 1, 0.68)
addGui("TextLabel", sidebar, {
    Size = UDim2.new(1, -25, 0, 30), Position = UDim2.fromOffset(17, 14),
    BackgroundTransparency = 1, Text = "NAVIGATION", TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = T.muted, TextSize = 10, Font = Enum.Font.Code,
})

local main = addGui("Frame", content, {
    Position = UDim2.fromOffset(189, 6), Size = UDim2.fromOffset(445, 328),
    BackgroundColor3 = T.surface, BackgroundTransparency = 0.12,
    BorderSizePixel = 0, ClipsDescendants = true,
})
corner(main, 14)
stroke(main, T.red, 1, 0.64)

-- Trame de fond très fine dans les panneaux de droite.
for i = 1, 12 do
    addGui("Frame", main, {
        Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(i * 36, 0),
        BackgroundColor3 = T.cyan, BackgroundTransparency = 0.983,
        BorderSizePixel = 0,
    })
end

local footer = addGui("Frame", window, {
    Position = UDim2.new(0, 0, 1, -35), Size = UDim2.new(1, 0, 0, 35),
    BackgroundColor3 = T.surface, BackgroundTransparency = 0.34,
    BorderSizePixel = 0,
})
addGui("Frame", footer, {
    Size = UDim2.new(1, -46, 0, 1), Position = UDim2.fromOffset(23, 0),
    BackgroundColor3 = T.border, BackgroundTransparency = 0.71,
    BorderSizePixel = 0,
})
addGui("TextLabel", footer, {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Font = Enum.Font.Code, Text = "BY u0bc", TextSize = 12,
    TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Center,
})

local pages = {}
local tabs = {}
local currentPage = nil
local tabLabels = {
    AIM = {title = "AIM", subtitle = ""},
    VISUAL = {title = "VISUAL", subtitle = ""},
    WORLD = {title = "WORLD", subtitle = "OPTIMISATION DU RENDU"},
    MISC = {title = "MISC", subtitle = ""},
}

local function selectPage(name)
    if currentPage == name then return end
    currentPage = name
    for pageName, page in pairs(pages) do
        local isCurrent = pageName == name
        page.Visible = isCurrent
        local tab = tabs[pageName]
        tween(tab, 0.24, {
            BackgroundColor3 = isCurrent and T.hover or T.surface2,
            BackgroundTransparency = isCurrent and 0.02 or 0.58,
        })
        tween(tab:FindFirstChild("AccentRail"), 0.2, {
            BackgroundTransparency = isCurrent and 0 or 1,
        })
        local textLabel = tab:FindFirstChild("Title")
        if textLabel then tween(textLabel, 0.22, {TextColor3 = isCurrent and T.text or T.muted}) end
        if isCurrent then
            page.Position = UDim2.fromOffset(13, 19)
            tween(page, 0.32, {Position = UDim2.fromOffset(13, 12)})
        end
    end
end

local function newTab(name, subtitle, row)
    local button = addGui("TextButton", sidebar, {
        Name = "Tab_" .. name,
        Size = UDim2.new(1, -22, 0, 52), Position = UDim2.fromOffset(11, 51 + row * 59),
        BackgroundColor3 = T.surface2, BackgroundTransparency = 0.58,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    })
    corner(button, 10)
    addGui("Frame", button, {
        Name = "AccentRail", Position = UDim2.new(0, 0, 0, 10),
        Size = UDim2.fromOffset(3, 32), BackgroundColor3 = T.cyan,
        BackgroundTransparency = 1, BorderSizePixel = 0,
    })
    addGui("TextLabel", button, {
        Name = "Title", Size = UDim2.new(1, -20, 0, 23),
        Position = UDim2.fromOffset(14, 7), BackgroundTransparency = 1,
        Text = name, Font = Enum.Font.GothamBlack,
        TextSize = 13, TextColor3 = T.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    addGui("TextLabel", button, {
        Size = UDim2.new(1, -18, 0, 16), Position = UDim2.fromOffset(14, 29),
        BackgroundTransparency = 1, Text = subtitle,
        Font = Enum.Font.Code, TextSize = 9, TextColor3 = T.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    tabs[name] = button
    local page = addGui("Frame", main, {
        Name = "Page_" .. name, Position = UDim2.fromOffset(13, 12),
        Size = UDim2.new(1, -26, 1, -24), BackgroundTransparency = 1,
        Visible = false,
    })
    addGui("TextLabel", page, {
        Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 25),
        BackgroundTransparency = 1, Text = tabLabels[name].title,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Arcade, TextSize = 15,
        TextColor3 = T.text,
    })
    addGui("TextLabel", page, {
        Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 19),
        BackgroundTransparency = 1, Text = tabLabels[name].subtitle,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Code, TextSize = 10,
        TextColor3 = T.muted,
    })
    pages[name] = page
    button.MouseButton1Click:Connect(function() selectPage(name) end)
    button.MouseEnter:Connect(function()
        if currentPage ~= name then tween(button, 0.17, {BackgroundTransparency = 0.35}) end
    end)
    button.MouseLeave:Connect(function()
        if currentPage ~= name then tween(button, 0.17, {BackgroundTransparency = 0.58}) end
    end)
    return page
end

local pageAim = newTab("AIM", "", 0)
local pageVisual = newTab("VISUAL", "", 1)
local pageWorld = newTab("WORLD", "", 2)
local pageMisc = newTab("MISC", "", 3)

local function newRow(page, y, height)
    local r = addGui("Frame", page, {
        Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, height or 72),
        BackgroundColor3 = T.row, BackgroundTransparency = 0.10,
        BorderSizePixel = 0,
    })
    corner(r, 11)
    stroke(r, T.border, 1, 0.80)
    return r
end

local function newToggle(page, y, title, subtitle, onChange, keyLabel)
    local row = newRow(page, y, 75)
    addGui("TextLabel", row, {
        Size = UDim2.new(1, -165, 0, 23), Position = UDim2.fromOffset(17, 12),
        BackgroundTransparency = 1, Text = title,
        Font = Enum.Font.GothamBlack, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.text,
    })
    addGui("TextLabel", row, {
        Size = UDim2.new(1, -105, 0, 20), Position = UDim2.fromOffset(17, 39),
        BackgroundTransparency = 1, Text = subtitle,
        Font = Enum.Font.Code, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.muted,
    })
    local toggle = addGui("TextButton", row, {
        Size = UDim2.fromOffset(61, 31),
        Position = UDim2.new(1, -76, 0.5, -15),
        BackgroundColor3 = T.off, Text = "", BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    corner(toggle, 16)
    local knob = addGui("Frame", toggle, {
        Size = UDim2.fromOffset(23, 23), Position = UDim2.fromOffset(4, 4),
        BackgroundColor3 = T.text, BorderSizePixel = 0,
    })
    corner(knob, 12)
    local bind
    if keyLabel then
        bind = addGui("TextButton", row, {
            Size = UDim2.fromOffset(62, 30), Position = UDim2.new(1, -151, 0.5, -15),
            BackgroundColor3 = T.surface2, BorderSizePixel = 0,
            Text = keyLabel, TextSize = 12, Font = Enum.Font.Code,
            TextColor3 = T.cyan, AutoButtonColor = false,
        })
        corner(bind, 8)
        stroke(bind, T.border, 1, 0.64)
    end
    local isOn = false
    local function setOn(yes)
        yes = (yes == true)
        if yes == isOn then return end
        isOn = yes
        tween(toggle, 0.22, {BackgroundColor3 = yes and T.cyan or T.off})
        tween(knob, 0.21, {Position = UDim2.fromOffset(yes and 34 or 4, 4)})
        onChange(yes)
    end
    toggle.MouseButton1Click:Connect(function() setOn(not isOn) end)
    row.MouseEnter:Connect(function() tween(row, 0.16, {BackgroundColor3 = T.hover}) end)
    row.MouseLeave:Connect(function() tween(row, 0.18, {BackgroundColor3 = T.row}) end)
    return {set = setOn, get = function() return isOn end, bind = bind, row = row}
end

-- ================= WORLD : 3 PROFILS EXCLUSIFS =================
local worldButtons = {}
local worldEtatTexte = nil

local function actualiserWorldBoutons()
    for nomMode, bouton in pairs(worldButtons) do
        local actif = worldMode == nomMode
        tween(bouton, 0.18, {
            BackgroundColor3 = actif and T.cyan or T.surface2,
            TextColor3 = actif and T.text or T.muted,
        })
    end
    if worldEtatTexte then
        local infoFPS = worldFPSModifie and " | 20 FPS" or ""
        worldEtatTexte.Text = "MODE ACTIF : " .. worldMode .. infoFPS
    end
end

local function creerBoutonWorld(y, nom, titre, description)
    local ligne = newRow(pageWorld, y, 75)
    addGui("TextLabel", ligne, {
        Position = UDim2.fromOffset(15, 10),
        Size = UDim2.new(1, -135, 0, 25),
        BackgroundTransparency = 1, Text = titre,
        Font = Enum.Font.GothamBlack, TextSize = 13,
        TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
    })
    addGui("TextLabel", ligne, {
        Position = UDim2.fromOffset(15, 39),
        Size = UDim2.new(1, -126, 0, 18),
        BackgroundTransparency = 1, Text = description,
        Font = Enum.Font.Code, TextSize = 10,
        TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left,
    })
    local bouton = addGui("TextButton", ligne, {
        Position = UDim2.new(1, -116, 0.5, -16),
        Size = UDim2.fromOffset(100, 32),
        BackgroundColor3 = T.surface2, BorderSizePixel = 0,
        Text = nom == "NORMAL" and "RESTORE" or "ACTIVER",
        TextColor3 = T.muted, TextSize = 11,
        Font = Enum.Font.Code, AutoButtonColor = false,
    })
    corner(bouton, 9)
    stroke(bouton, T.border, 1, 0.45)
    worldButtons[nom] = bouton
    bouton.MouseButton1Click:Connect(function()
        definirWorldMode(nom)
        actualiserWorldBoutons()
    end)
    return ligne
end

creerBoutonWorld(50, "FULL FPS", "FULL FPS", "Sans ombres / effets, visuel propre")
creerBoutonWorld(133, "POTATO", "POTATO", "Textures OFF, details minimum")
creerBoutonWorld(216, "NORMAL", "NORMAL", "Remet les reglages initiaux")
worldEtatTexte = addGui("TextLabel", pageWorld, {
    Position = UDim2.fromOffset(9, 296),
    Size = UDim2.new(1, -18, 0, 16),
    BackgroundTransparency = 1, Text = "MODE ACTIF : NORMAL",
    Font = Enum.Font.Code, TextSize = 10,
    TextColor3 = T.cyan, TextXAlignment = Enum.TextXAlignment.Center,
})
actualiserWorldBoutons()

-- Applique la couleur aux ESP deja presents SANS les desactiver/recreer.
local function appliquerCouleurZombie(couleur)
    zombieGlowColor = couleur
    for _, highlight in pairs(zombieGlows) do
        if highlight and highlight.Parent then
            highlight.FillColor = couleur
            highlight.OutlineColor = couleur
        end
    end
end

local function rafraichirCouleursJoueurs()
    -- Les reglages RGB changent la couleur du contour immediatement.
    for _, entree in pairs(playerGlows) do
        local glow = entree.highlight
        if glow and glow.Parent then
            glow.OutlineColor = entree.estVisible and playerGlowColorVisible or playerGlowColorCache
            glow.FillTransparency = 1
            glow.OutlineTransparency = ESP_OUTLINE_TRANSPARENCY
        end
    end
end

local function appliquerCouleurJoueurVisible(couleur)
    playerGlowColorVisible = couleur
    rafraichirCouleursJoueurs()
end

local function appliquerCouleurJoueurCache(couleur)
    playerGlowColorCache = couleur
    rafraichirCouleursJoueurs()
end

-- Bande RGB avec selecteur glissable (souris et tactile) + apercu + chiffres RGB.
-- Chaque bande conserve ses propres interactions et sa couleur.
local colorBarConnections = {}
local function newRGBBar(page, y, initialColor, setColor, nomCouleur)
    local panel = newRow(page, y, 39)
    local labelRGB = addGui("TextLabel", panel, {
        Position = UDim2.fromOffset(12, 3),
        Size = UDim2.fromOffset(172, 12),
        BackgroundTransparency = 1,
        Text = nomCouleur or "COULEUR GLOW / RGB",
        Font = Enum.Font.GothamBold,
        TextSize = 9, TextColor3 = T.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local values = addGui("TextLabel", panel, {
        Position = UDim2.new(1, -171, 0, 3),
        Size = UDim2.fromOffset(126, 12),
        BackgroundTransparency = 1,
        Text = "", Font = Enum.Font.Code,
        TextSize = 9, TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local preview = addGui("Frame", panel, {
        Position = UDim2.new(1, -34, 0, 9),
        Size = UDim2.fromOffset(23, 23),
        BackgroundColor3 = initialColor, BorderSizePixel = 0,
    })
    corner(preview, 7)
    stroke(preview, T.text, 1.3, 0.52)
    -- Rail suffisamment haut pour etre utilisable aussi avec le toucher.
    local track = addGui("TextButton", panel, {
        Name = "RGBSlider", Position = UDim2.fromOffset(12, 19),
        Size = UDim2.new(1, -58, 0, 13),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Text = "", AutoButtonColor = false,
        ClipsDescendants = false,
    })
    corner(track, 7)
    local gradient = addGui("UIGradient", track, {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
            ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6, 1, 1)),
            ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6, 1, 1)),
            ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6, 1, 1)),
            ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6, 1, 1)),
            ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
        }),
    })
    local cursor = addGui("Frame", track, {
        Name = "Selection", AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(9, 19),
        Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = T.text, BorderSizePixel = 0,
        ZIndex = 5,
    })
    corner(cursor, 4)
    stroke(cursor, T.bg, 1.4, 0)

    local function afficher(couleur, hue)
        preview.BackgroundColor3 = couleur
        cursor.Position = UDim2.new(hue, 0, 0.5, 0)
        local r = math.floor(couleur.R * 255 + 0.5)
        local g = math.floor(couleur.G * 255 + 0.5)
        local b = math.floor(couleur.B * 255 + 0.5)
        values.Text = string.format("R %03d  G %03d  B %03d", r, g, b)
    end
    local initialHue = select(1, initialColor:ToHSV())
    afficher(initialColor, initialHue)

    local function moveTo(screenX)
        local width = track.AbsoluteSize.X
        if width <= 0 then return end
        local hue = math.clamp((screenX - track.AbsolutePosition.X) / width, 0, 1)
        local chosen = Color3.fromHSV(hue, 1, 1)
        afficher(chosen, hue)
        setColor(chosen)
    end
    local dragMouse = false
    local dragTouch = nil
    table.insert(colorBarConnections, track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragMouse = true
            moveTo(input.Position.X)
        elseif input.UserInputType == Enum.UserInputType.Touch then
            dragTouch = input
            moveTo(input.Position.X)
        end
    end))
    table.insert(colorBarConnections, UserInputService.InputChanged:Connect(function(input)
        if dragMouse and input.UserInputType == Enum.UserInputType.MouseMovement then
            moveTo(input.Position.X)
        elseif dragTouch == input then
            moveTo(input.Position.X)
        end
    end))
    table.insert(colorBarConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragMouse = false
        elseif input == dragTouch then
            dragTouch = nil
        end
    end))
    return panel
end

-- Trois reglettes RGB (zombies + joueurs visibles + joueurs derriere les murs).
-- On conserve la taille du menu : les deux toggles sont plus compacts.
local espZombie = newToggle(pageVisual, 50,
    "ESP ZOMBIE", "Glow personnalisable sur les Hood", function(active)
        zombieActif = active
        if active then activerZombie() else desactiverZombie() end
    end)
espZombie.row.Size = UDim2.new(1, 0, 0, 59)
local zombieRGBBar = newRGBBar(pageVisual, 113, zombieGlowColor,
    appliquerCouleurZombie, "ZOMBIES / RGB")

local espPlayer = newToggle(pageVisual, 156,
    "ESP PLAYER", "2 couleurs selon les murs", function(active)
        playerActif = active
        if active then activerPlayer() else desactiverPlayer() end
    end)
espPlayer.row.Size = UDim2.new(1, 0, 0, 59)
local playerRGBVisible = newRGBBar(pageVisual, 220, playerGlowColorVisible,
    appliquerCouleurJoueurVisible, "JOUEUR VISIBLE")
local playerRGBCache = newRGBBar(pageVisual, 263, playerGlowColorCache,
    appliquerCouleurJoueurCache, "DERRIERE UN MUR")

local farmToggle = newToggle(pageAim, 61,
    "FARM ZOMBIE", "Combat continu · tir + recuperation E",
    function(active)
        if active then demarrerFarm() else arreterFarm() end
    end, "F4")

-- Le bouton OPTIONS ouvre un sous-menu. Le mode "Undetect" designe ici
-- uniquement le cycle temporise, sans promesse d'eviter une detection.
local optionsExpanded = false
local optionsButton = addGui("TextButton", farmToggle.row, {
    Name = "FarmOptions", Position = UDim2.new(1, -268, 0, 9),
    Size = UDim2.fromOffset(111, 26),
    BackgroundColor3 = T.surface2, BorderSizePixel = 0,
    Text = "OPTIONS  ▾", TextSize = 10, Font = Enum.Font.Code,
    TextColor3 = T.cyan, AutoButtonColor = false,
})
corner(optionsButton, 8)
stroke(optionsButton, T.border, 1, 0.7)

local undetectToggle = newToggle(pageAim, 121,
    "Undetect", "15s combat / R / 40s pause",
    function(active)
        modePauseActif = active
        -- boucleFarm lit ce booleen et passe au nouveau mode pendant l'execution.
    end, nil)
undetectToggle.row.Size = UDim2.new(1, -20, 0, 60)
undetectToggle.row.Position = UDim2.fromOffset(20, 121)
undetectToggle.row.BackgroundColor3 = T.surface2
undetectToggle.row.BackgroundTransparency = 0.14
undetectToggle.row.ClipsDescendants = true
undetectToggle.row.Visible = false

-- La seconde option du FARM est maintenant BACKGROUND AIM.
-- Elle suit les memes transitions que Undetect dans OPTIONS.
local backgroundToggle = newToggle(pageAim, 168,
    "BACKGROUND AIM", "Camera sans souris / experimental",
    function(active)
        backgroundAimEnabled = active
        if active then activerCameraBackground() else libererCameraBackground() end
    end)
backgroundToggle.row.Size = UDim2.new(1, -20, 0, 47)
backgroundToggle.row.Position = UDim2.fromOffset(20, 168)
backgroundToggle.row.BackgroundColor3 = T.surface2
backgroundToggle.row.BackgroundTransparency = 0.14
backgroundToggle.row.ClipsDescendants = true
backgroundToggle.row.Visible = false

-- Les deux sous-options font 47px pour tenir dans la page AIM sans scroll.
local function ajusterLigneFarm(toggle, titre)
    for _, enfant in ipairs(toggle.row:GetChildren()) do
        if enfant:IsA("TextLabel") then
            if enfant.Text == titre then
                enfant.Position = UDim2.fromOffset(17, 5)
                enfant.Size = UDim2.new(1, -125, 0, 21)
            else
                enfant.Position = UDim2.fromOffset(17, 27)
                enfant.Size = UDim2.new(1, -105, 0, 17)
            end
        end
    end
end
ajusterLigneFarm(undetectToggle, "Undetect")
ajusterLigneFarm(backgroundToggle, "BACKGROUND AIM")

local danceToggle = newToggle(pageAim, 144,
    "ANTI DANCE", "Stoppe les danses via touche 2",
    function(active) configurerAntiDance(active) end, "F3")

local statusRow = newRow(pageAim, 229, 70)
local statusDot = addGui("Frame", statusRow, {
    Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(9, 9),
    BackgroundColor3 = T.off, BorderSizePixel = 0,
})
corner(statusDot, 6)
local statusText = addGui("TextLabel", statusRow, {
    Position = UDim2.fromOffset(33, 7), Size = UDim2.new(1, -42, 0, 32),
    Text = "Arrete | E OFF", BackgroundTransparency = 1,
    TextColor3 = T.muted, Font = Enum.Font.Code,
    TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
})
local progressBg = addGui("Frame", statusRow, {
    Position = UDim2.new(0, 16, 1, -17), Size = UDim2.new(1, -32, 0, 5),
    BackgroundColor3 = T.off, BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
})
corner(progressBg, 4)
local progressFill = addGui("Frame", progressBg, {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.cyan,
    BorderSizePixel = 0,
})
corner(progressFill, 4)

-- Quand les options sont ouvertes, tous les elements restent dans la
-- fenetre compacte (pas d'agrandissement general du menu).
local expansionNumero = 0
local function afficherOptionsFarm(ouvrir)
    if optionsExpanded == ouvrir then return end
    optionsExpanded = ouvrir
    expansionNumero += 1
    local numero = expansionNumero
    optionsButton.Text = ouvrir and "OPTIONS  ▴" or "OPTIONS  ▾"
    tween(optionsButton, 0.18, {TextColor3 = ouvrir and T.purple or T.cyan})

    if ouvrir then
        for _, donnee in ipairs({
            {toggle = undetectToggle, y = 115},
            {toggle = backgroundToggle, y = 168},
        }) do
            local ligne = donnee.toggle.row
            ligne.Visible = true
            ligne.Position = UDim2.fromOffset(20, donnee.y - 5)
            ligne.Size = UDim2.new(1, -20, 0, 2)
            ligne.BackgroundTransparency = 1
            tween(ligne, 0.26, {
                Position = UDim2.fromOffset(20, donnee.y),
                Size = UDim2.new(1, -20, 0, 47),
                BackgroundTransparency = 0.14,
            })
        end
    else
        for _, donnee in ipairs({
            {toggle = undetectToggle, y = 115},
            {toggle = backgroundToggle, y = 168},
        }) do
            tween(donnee.toggle.row, 0.21, {
                Position = UDim2.fromOffset(20, donnee.y - 5),
                Size = UDim2.new(1, -20, 0, 2),
                BackgroundTransparency = 1,
            })
        end
        task.delay(0.23, function()
            if not optionsExpanded and expansionNumero == numero and gui.Parent then
                undetectToggle.row.Visible = false
                backgroundToggle.row.Visible = false
            end
        end)
    end

    -- L'ANTI DANCE conserve son bouton, son sous-titre se cache dans le mode compact.
    for _, enfant in ipairs(danceToggle.row:GetChildren()) do
        if enfant:IsA("TextLabel") then
            if enfant.Text == "ANTI DANCE" then
                enfant.Position = UDim2.fromOffset(17, ouvrir and 4 or 12)
            elseif enfant.Text == "Stoppe les danses via touche 2" then
                enfant.Visible = not ouvrir
            end
        end
    end
    tween(farmToggle.row, 0.27, {
        Position = UDim2.fromOffset(0, ouvrir and 50 or 61),
        Size = UDim2.new(1, 0, 0, ouvrir and 60 or 75),
    })
    tween(danceToggle.row, 0.27, {
        Position = UDim2.fromOffset(0, ouvrir and 220 or 144),
        Size = UDim2.new(1, 0, 0, ouvrir and 35 or 75),
    })
    tween(statusRow, 0.27, {
        Position = UDim2.fromOffset(0, ouvrir and 260 or 229),
        Size = UDim2.new(1, 0, 0, ouvrir and 40 or 70),
    })
    tween(statusText, 0.27, {
        Position = UDim2.fromOffset(33, ouvrir and 0 or 7),
        Size = UDim2.new(1, -42, 0, ouvrir and 26 or 32),
    })
end
optionsButton.MouseButton1Click:Connect(function()
    afficherOptionsFarm(not optionsExpanded)
end)

-- Renvoi de l'état du farm existant vers le nouvel indicateur.
afficherEtatFarm = function(_, description)
    if not statusText or not statusText.Parent then return end
    statusText.Text = description or "Arrete | E OFF"
    local combat = string.match(statusText.Text, "Combat : (%d+)s")
    local pause = string.match(statusText.Text, "Pause : (%d+)s")
    if combat then
        tween(statusDot, 0.12, {BackgroundColor3 = T.green})
        progressFill.BackgroundColor3 = T.cyan
        progressFill.Size = UDim2.fromScale(math.clamp((15 - tonumber(combat)) / 15, 0, 1), 1)
    elseif pause then
        tween(statusDot, 0.12, {BackgroundColor3 = T.purple})
        progressFill.BackgroundColor3 = T.purple
        progressFill.Size = UDim2.fromScale(math.clamp((40 - tonumber(pause)) / 40, 0, 1), 1)
    elseif string.find(statusText.Text, "Continu", 1, true) then
        tween(statusDot, 0.12, {BackgroundColor3 = T.green})
        progressFill.BackgroundColor3 = T.cyan
        progressFill.Size = UDim2.fromScale(1, 1)
    else
        tween(statusDot, 0.12, {BackgroundColor3 = T.off})
        progressFill.Size = UDim2.fromScale(0, 1)
    end
end

-- ================= STREAMPOOF : MASQUE AU-DESSUS DE LA TETE =================
-- Un BillboardGui cache visuellement la zone au-dessus de notre propre tete.
-- Ce n'est PAS un flou reel de la capture : Roblox ne propose pas de
-- flou gaussien localise par-dessus le rendu 3D en BillboardGui.
local streamPoofActif = false
local streamPoofMasque = nil
local streamPoofConnexions = {}

local function supprimerMasqueStreamPoof()
    if streamPoofMasque then
        pcall(function() streamPoofMasque:Destroy() end)
        streamPoofMasque = nil
    end
end

local function creerMasqueStreamPoof(personnage)
    if not streamPoofActif or not personnage then return end
    local tete = personnage:FindFirstChild("Head") or personnage:WaitForChild("Head", 5)
    if not streamPoofActif or not tete or not tete:IsA("BasePart") then return end
    supprimerMasqueStreamPoof()

    local masque = Instance.new("BillboardGui")
    masque.Name = "U0BC_StreamPoof_Mask"
    masque.Adornee = tete
    masque.Size = UDim2.fromOffset(240, 66)
    masque.StudsOffsetWorldSpace = Vector3.new(0, 2.55, 0)
    masque.AlwaysOnTop = true
    masque.MaxDistance = 800
    masque.ResetOnSpawn = false
    masque.Parent = joueurLocal:WaitForChild("PlayerGui")

    -- Coeur opaque qui masque les noms, avec bordures adoucies.
    local fond = Instance.new("Frame")
    fond.Size = UDim2.fromScale(1, 1)
    fond.BackgroundColor3 = Color3.fromRGB(26, 29, 36)
    fond.BorderSizePixel = 0
    fond.Parent = masque
    local arrondi = Instance.new("UICorner")
    arrondi.CornerRadius = UDim.new(0, 24)
    arrondi.Parent = fond

    local degrade = Instance.new("UIGradient")
    degrade.Rotation = 0
    degrade.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 76, 88)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(31, 34, 42)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(31, 34, 42)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 76, 88)),
    })
    degrade.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.74),
        NumberSequenceKeypoint.new(0.10, 0.04),
        NumberSequenceKeypoint.new(0.90, 0.04),
        NumberSequenceKeypoint.new(1, 0.74),
    })
    degrade.Parent = fond

    local bordure = Instance.new("UIStroke")
    bordure.Color = Color3.fromRGB(113, 120, 135)
    bordure.Thickness = 1.5
    bordure.Transparency = 0.55
    bordure.Parent = fond

    streamPoofMasque = masque
end

local function desactiverStreamPoof()
    streamPoofActif = false
    for _, connexion in ipairs(streamPoofConnexions) do
        connexion:Disconnect()
    end
    streamPoofConnexions = {}
    supprimerMasqueStreamPoof()
end

local function activerStreamPoof()
    if streamPoofActif then return end
    streamPoofActif = true
    local ancienMasque = joueurLocal:WaitForChild("PlayerGui"):FindFirstChild("U0BC_StreamPoof_Mask")
    if ancienMasque then ancienMasque:Destroy() end
    table.insert(streamPoofConnexions, joueurLocal.CharacterAdded:Connect(function(personnage)
        task.defer(creerMasqueStreamPoof, personnage)
    end))
    table.insert(streamPoofConnexions, joueurLocal.CharacterRemoving:Connect(supprimerMasqueStreamPoof))
    if joueurLocal.Character then
        task.defer(creerMasqueStreamPoof, joueurLocal.Character)
    end
end

local streamPoofToggle = newToggle(pageMisc, 70,
    "STREAMPOOF", "Masque au-dessus de ta tete",
    function(active)
        if active then activerStreamPoof() else desactiverStreamPoof() end
    end)

local binds = {farm = Enum.KeyCode.F4, dance = Enum.KeyCode.F3}
local capture = nil
local lastKey = {farm = 0, dance = 0}
local actionNames = {farm = "U0BC_StopFarm_V11", dance = "U0BC_ToggleDance_V11"}
local controls = {farm = farmToggle, dance = danceToggle}
local wasHeld = {farm = false, dance = false}

local function activateHotkey(which, key)
    if capture or key ~= binds[which] then return end
    if UserInputService:GetFocusedTextBox() then return end
    local now = os.clock()
    if now - lastKey[which] < 0.24 then return end
    lastKey[which] = now
    if which == "farm" then
        controls.farm.set(false) -- F4 = stop uniquement, pas de restart accidentel.
    elseif which == "dance" then
        controls.dance.set(not controls.dance.get())
    end
end

local function registerBind(which)
    pcall(function() ContextActionService:UnbindAction(actionNames[which]) end)
    pcall(function()
        ContextActionService:BindActionAtPriority(actionNames[which],
            function(_, state, input)
                if capture then return Enum.ContextActionResult.Pass end
                if state == Enum.UserInputState.Begin then
                    activateHotkey(which, input.KeyCode)
                end
                return Enum.ContextActionResult.Sink
            end,
            false, Enum.ContextActionPriority.High.Value + 1000, binds[which])
    end)
end

local function keyName(code)
    return code.Name:gsub("^Left", "L-"):gsub("^Right", "R-")
end

for which, control in pairs(controls) do
    control.bind.MouseButton1Click:Connect(function()
        if capture then
            controls[capture].bind.Text = keyName(binds[capture])
            tween(controls[capture].bind, 0.15, {TextColor3 = T.cyan})
        end
        capture = which
        control.bind.Text = "..."
        tween(control.bind, 0.15, {TextColor3 = T.purple})
    end)
end

local keyboardConnection = UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if capture then
        local which = capture
        capture = nil
        local key = input.KeyCode
        if key ~= Enum.KeyCode.Escape and key ~= Enum.KeyCode.Unknown then
            local other = (which == "farm") and "dance" or "farm"
            if key ~= binds[other] then
                binds[which] = key
                wasHeld[which] = false
                registerBind(which)
            else
                -- Evite de configurer deux actions sur la meme touche.
                controls[which].bind.Text = "USED"
                task.delay(0.7, function()
                    if gui.Parent then controls[which].bind.Text = keyName(binds[which]) end
                end)
                return
            end
        end
        controls[which].bind.Text = keyName(binds[which])
        tween(controls[which].bind, 0.16, {TextColor3 = T.cyan})
        return
    end
    activateHotkey("farm", input.KeyCode)
    activateHotkey("dance", input.KeyCode)
end)
registerBind("farm")
registerBind("dance")

-- Troisieme chemin pour le raccourci : l'etat de la touche est lu a chaque frame.
-- Utile lorsque la touche F3 est consommee par une autre action prioritaire
-- et que l'evenement InputBegan n'arrive pas au callback de notre menu.
-- 'lastKey' evite de declencher deux fois via InputBegan/CAS/sondage.
local hotkeyPoll = RunService.Heartbeat:Connect(function()
    if not gui.Parent then return end
    for which, key in pairs(binds) do
        local down = false
        pcall(function() down = UserInputService:IsKeyDown(key) end)
        if down and not wasHeld[which] then
            activateHotkey(which, key)
        end
        wasHeld[which] = down
    end
end)

-- V14: la fenetre peut etre deplacee depuis TOUTES ses zones non interactives.
-- On ignore boutons (onglets, toggles, touches, fermeture) et barres RGB.
-- Ecoute globale pour fonctionner aussi sur le fond, les labels et les panneaux.
local dragging = false
local dragInput = nil
local dragStart = nil
local originalPosition = nil

local function dansRectangle(pos, guiObject)
    local origine = guiObject.AbsolutePosition
    local taille = guiObject.AbsoluteSize
    return pos.X >= origine.X and pos.X <= origine.X + taille.X
        and pos.Y >= origine.Y and pos.Y <= origine.Y + taille.Y
end

local function elementVisible(obj)
    -- Respecte les pages masquees, la minimisation et les ancetres invisibles.
    local parent = obj
    while parent and parent ~= window do
        if parent:IsA("GuiObject") and not parent.Visible then return false end
        parent = parent.Parent
    end
    return parent == window and window.Visible and gui.Enabled
end

local function auDessusDUnControle(pos)
    -- Toutes les commandes existantes sont des GuiButton. Le test couvre
    -- aussi leurs enfants visuels (texte, rond des toggles, curseur RGB).
    for _, obj in ipairs(window:GetDescendants()) do
        if (obj:IsA("GuiButton") or obj:IsA("TextBox") or obj:IsA("ScrollingFrame"))
            and elementVisible(obj) and dansRectangle(pos, obj) then
            return true
        end
    end
    return false
end

local dragStartConnection = UserInputService.InputBegan:Connect(function(input)
    if dragging or not gui.Parent or not window.Visible or not gui.Enabled then return end
    local kind = input.UserInputType
    if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then return end
    if UserInputService:GetFocusedTextBox() then return end
    local pos = Vector2.new(input.Position.X, input.Position.Y)
    if not dansRectangle(pos, window) or auDessusDUnControle(pos) then return end
    dragging = true
    dragInput = input
    dragStart = pos
    originalPosition = window.Position
end)

local dragConnection = UserInputService.InputChanged:Connect(function(input)
    if not dragging or not dragStart or not originalPosition then return end
    local isMouse = dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement
    local isTouch = input == dragInput and input.UserInputType == Enum.UserInputType.Touch
    if not isMouse and not isTouch then return end
    local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
    window.Position = UDim2.new(
        originalPosition.X.Scale, originalPosition.X.Offset + delta.X,
        originalPosition.Y.Scale, originalPosition.Y.Offset + delta.Y
    )
end)

local dragEndConnection = UserInputService.InputEnded:Connect(function(input)
    if not dragging then return end
    if input == dragInput or (dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging, dragInput, dragStart, originalPosition = false, nil, nil, nil
    end
end)

-- V17 : la minimisation masque completement la fenetre et fait apparaitre
-- une petite icone ronde noire avec un U rouge. Le farm continue normalement.
-- L'icone est deplacable ; un clic simple restaure le menu.
local minimized = false
local minimizeGeneration = 0
local orbMovedAt = -10

local miniOrb = addGui("Frame", gui, {
    Name = "UrbanReload_MiniOrb",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = window.Position,
    Size = UDim2.fromOffset(76, 76),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 30,
})

local orbAura = addGui("Frame", miniOrb, {
    Name = "RedGlow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(72, 72),
    BackgroundColor3 = Color3.fromRGB(245, 22, 49),
    BackgroundTransparency = 0.92,
    BorderSizePixel = 0,
    ZIndex = 30,
})
corner(orbAura, 100)
TweenService:Create(orbAura,
    TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    {BackgroundTransparency = 0.97, Size = UDim2.fromOffset(76, 76)}):Play()

local orbButton = addGui("TextButton", miniOrb, {
    Name = "OpenUrbanReload",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(56, 56),
    BackgroundColor3 = Color3.fromRGB(9, 9, 12),
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 31,
})
corner(orbButton, 100)
local orbOutline = stroke(orbButton, T.red, 2.2, 0.08)
local orbGradient = addGui("UIGradient", orbButton, {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 5, 7)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(41, 8, 14)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 10)),
    }),
    Rotation = 30,
})
TweenService:Create(orbGradient,
    TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
    {Rotation = 390}):Play()

-- Un U diffus sous le U net pour simuler une typographie neon.
addGui("TextLabel", orbButton, {
    Name = "UGlow",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "U",
    Font = Enum.Font.SciFi,
    TextSize = 39,
    TextColor3 = Color3.fromRGB(255, 30, 55),
    TextTransparency = 0.73,
    ZIndex = 32,
})
addGui("TextLabel", orbButton, {
    Name = "ULogo",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "U",
    Font = Enum.Font.SciFi,
    TextSize = 32,
    TextColor3 = Color3.fromRGB(255, 55, 73),
    ZIndex = 33,
})

orbButton.MouseEnter:Connect(function()
    tween(orbButton, 0.14, {BackgroundColor3 = Color3.fromRGB(48, 10, 17)})
    tween(orbOutline, 0.14, {Thickness = 3, Transparency = 0})
end)
orbButton.MouseLeave:Connect(function()
    tween(orbButton, 0.18, {BackgroundColor3 = Color3.fromRGB(9, 9, 12)})
    tween(orbOutline, 0.18, {Thickness = 2.2, Transparency = 0.08})
end)

-- Permet de glisser le rond sans declencher une restauration involontaire.
local orbDragging = false
local orbInput = nil
local orbDragStart = nil
local orbOriginalPosition = nil
local orbHasMoved = false

orbButton.InputBegan:Connect(function(input)
    if not minimized then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    orbDragging = true
    orbInput = input
    orbDragStart = Vector2.new(input.Position.X, input.Position.Y)
    orbOriginalPosition = miniOrb.Position
    orbHasMoved = false
end)

local orbDragMoveConnection = UserInputService.InputChanged:Connect(function(input)
    if not orbDragging or not orbInput then return end
    local mouse = orbInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement
    local touch = orbInput.UserInputType == Enum.UserInputType.Touch and input == orbInput
    if not mouse and not touch then return end
    local delta = Vector2.new(input.Position.X, input.Position.Y) - orbDragStart
    if delta.Magnitude > 5 then orbHasMoved = true end
    if not orbHasMoved then return end
    miniOrb.Position = UDim2.new(
        orbOriginalPosition.X.Scale, orbOriginalPosition.X.Offset + delta.X,
        orbOriginalPosition.Y.Scale, orbOriginalPosition.Y.Offset + delta.Y
    )
end)

local orbDragEndConnection = UserInputService.InputEnded:Connect(function(input)
    if not orbDragging then return end
    if input == orbInput or
        (orbInput and orbInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1) then
        if orbHasMoved then orbMovedAt = os.clock() end
        orbDragging = false
        orbInput = nil
        orbDragStart = nil
        orbOriginalPosition = nil
    end
end)

minimizeBtn.MouseButton1Click:Connect(function()
    if minimized then return end
    minimized = true
    minimizeGeneration += 1
    local generation = minimizeGeneration
    miniOrb.Position = window.Position
    orbDragging = false
    content.Visible = false
    footer.Visible = false
    header.Visible = false
    tween(window, 0.17, {
        Size = UDim2.fromOffset(82, 82), BackgroundTransparency = 0.9
    })
    task.delay(0.16, function()
        if not gui.Parent or not minimized or generation ~= minimizeGeneration then return end
        window.Visible = false
        miniOrb.Visible = true
    end)
end)

orbButton.MouseButton1Click:Connect(function()
    if not minimized or os.clock() - orbMovedAt < 0.25 then return end
    minimized = false
    minimizeGeneration += 1
    miniOrb.Visible = false
    window.Position = miniOrb.Position
    window.Visible = true
    window.Size = UDim2.fromOffset(82, 82)
    window.BackgroundTransparency = 0.78
    header.Visible = true
    tween(window, 0.30, {
        Size = UDim2.fromOffset(650, 448), BackgroundTransparency = 0
    })
    local generation = minimizeGeneration
    task.delay(0.21, function()
        if gui.Parent and not minimized and generation == minimizeGeneration then
            content.Visible = true
            footer.Visible = true
        end
    end)
end)

local closed = false
local function closeAll()
    if closed then return end
    closed = true
    restaurerWorld()
    farmToggle.set(false)
    backgroundToggle.set(false)
    streamPoofToggle.set(false)
    undetectToggle.set(false)
    danceToggle.set(false)
    espZombie.set(false)
    espPlayer.set(false)
    -- Si des fonctions ont ete activees hors des toggles, les arreter aussi.
    arreterFarm()
    configurerAntiDance(false)
    desactiverZombie()
    desactiverPlayer()
    keyboardConnection:Disconnect()
    hotkeyPoll:Disconnect()
    for _, conn in ipairs(colorBarConnections) do conn:Disconnect() end
    dragStartConnection:Disconnect()
    dragConnection:Disconnect()
    dragEndConnection:Disconnect()
    orbDragMoveConnection:Disconnect()
    orbDragEndConnection:Disconnect()
    pcall(function() ContextActionService:UnbindAction(actionNames.farm) end)
    pcall(function() ContextActionService:UnbindAction(actionNames.dance) end)
    gui:Destroy()
end
closeBtn.MouseButton1Click:Connect(closeAll)
-- Restaurer meme si le menu est detruit par une nouvelle execution.
gui.Destroying:Connect(restaurerWorld)
gui.Destroying:Connect(desactiverStreamPoof)

-- Les callbacks du menu ne sont pas sauvegardes dans l'ancien script V9.
-- Desactivez l'ancienne execution avant d'executer cette version.
selectPage("AIM")
window.Size = UDim2.fromOffset(620, 420)
window.BackgroundTransparency = 0.42
tween(window, 0.48, {
    Size = UDim2.fromOffset(650, 448), BackgroundTransparency = 0,
})
