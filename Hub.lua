getgenv().settings = {
    autoDungeon = false,
    autoLoot = false,
    autoBoss = false,
    autoReplay = false
}

local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local MinimizeButton = Instance.new("TextButton")
local IconButton = Instance.new("TextButton")

ScreenGui.Name = "WordZeroTavinHub"
ScreenGui.Parent = game.CoreGui

Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Frame.Size = UDim2.new(0, 230, 0, 220)
Frame.Position = UDim2.new(0.4, 0, 0.4, 0)
Frame.Active = true
Frame.Draggable = true

Title.Parent = Frame
Title.Text = "word zero tavin"
Title.Size = UDim2.new(0.85, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true

MinimizeButton.Parent = Frame
MinimizeButton.Size = UDim2.new(0.15, 0, 0, 30)
MinimizeButton.Position = UDim2.new(0.85, 0, 0, 0)
MinimizeButton.Text = "-"
MinimizeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextScaled = true

IconButton.Parent = ScreenGui
IconButton.Size = UDim2.new(0, 50, 0, 50)
IconButton.Position = UDim2.new(0.05, 0, 0.8, 0)
IconButton.Text = "T"
IconButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
IconButton.TextColor3 = Color3.fromRGB(255, 255, 255)
IconButton.TextScaled = true
IconButton.Visible = false

local function createButton(name, pos, toggleVar)
    local btn = Instance.new("TextButton")
    btn.Parent = Frame
    btn.Text = name
    btn.Size = UDim2.new(1, -20, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, pos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.MouseButton1Click:Connect(function()
        getgenv().settings[toggleVar] = not getgenv().settings[toggleVar]
    end)
end

createButton("Auto Dungeon", 40, "autoDungeon")
createButton("Auto Loot", 80, "autoLoot")
createButton("Auto Boss", 120, "autoBoss")
createButton("Auto Replay", 160, "autoReplay")

MinimizeButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
    IconButton.Visible = true
end)

IconButton.MouseButton1Click:Connect(function()
    Frame.Visible = true
    IconButton.Visible = false
end)

local function atacarInimigos()
    for _, v in pairs(game.Workspace.Enemies:GetChildren()) do
        if v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            pcall(function()
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame =
                    v.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
                game:GetService("ReplicatedStorage").Events.Attack:FireServer()
            end)
        end
    end
end

local function pegarLoot()
    for _, obj in pairs(game.Workspace:GetChildren()) do
        if obj.Name:lower():find("chest") or obj.Name:lower():find("loot") then
            pcall(function()
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame =
                    obj.CFrame + Vector3.new(0, 2, 0)
            end)
        end
    end
end

local function matarBoss()
    local boss = game.Workspace:FindFirstChild("Boss")
    if boss and boss:FindFirstChild("Humanoid") then
        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame =
            boss.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
        game:GetService("ReplicatedStorage").Events.Attack:FireServer()
    end
end

local function replayDungeon()
    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Events"):FindFirstChild("Replay")
    if remote then
        remote:FireServer()
    end
end

spawn(function()
    while wait(0.5) do
        if getgenv().settings.autoDungeon then atacarInimigos() end
        if getgenv().settings.autoLoot then pegarLoot() end
        if getgenv().settings.autoBoss then matarBoss() end
        if getgenv().settings.autoReplay then replayDungeon() end
    end
end)
