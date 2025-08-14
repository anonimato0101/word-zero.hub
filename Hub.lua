local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local GameName = ""

local GameIds = {
    [6137321701] = "Blair (Lobby)",
    [6348640020] = "Blair",
    [18199615050] = "Demonology [Lobby]",
    [18794863104] = "Demonology [Game]",
    [8260276694] = "Ability Wars",
    [126884695634066] = "Grow A Garden [BETA]",
    [14518422161] = "Gunfight Arena [BETA]",
    [8267733039] = "Specter [Lobby]",
    [8417221956] = "Specter [GAME]",
    [79546208627805] = "99 Night in the forest [LOBBY]",
    [126509999114328] = "99 Night in the forest [GAME]",
    [111989938562194] = "Brainrot Evolution",
}

GameName = GameIds[game.PlaceId] or "Universal"

-- Carregando Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Criar Janela principal já com o novo nome
local Window = Rayfield:CreateWindow({
    Name = "Tavin Hub 99 Noites - " .. GameName,
    Icon = 0,
    LoadingTitle = "Tavin Hub",
    LoadingSubtitle = "by Tavin",
    Theme = "Default",
    
    ToggleUIKeybind = "K",
    
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "TavinHub99Noites",
        FileName = "TavinHub_Config"
    },
    
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    }
})

-- Aba de Informações
local InfoTab = Window:CreateTab("Info", "info")
local InfoSection = InfoTab:CreateSection("Informações")
local GameLabel = InfoTab:CreateLabel("Jogo Detectado: " .. GameName, "gamepad-2")
local MaintenanceParagraph = InfoTab:CreateParagraph({
    Title = "Bem-vindo",
    Content = "Obrigado por usar o Tavin Hub 99 Noites!"
})

-- Aba principal para scripts
local MainTab = Window:CreateTab("Scripts", "code")

-- Botão para executar seu script principal
MainTab:CreateButton({
    Name = "Executar Script",
    Callback = function()
        Rayfield:Notify({
            Title = "Carregando",
            Content = "Seu script está sendo carregado...",
            Duration = 3,
            Image = "clock",
        })

        
 

