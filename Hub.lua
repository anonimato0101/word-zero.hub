local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local function safely(f, ...) local ok, r = pcall(f, ...) if ok then return r end return nil end

local State = {
    UIVisible = true,
    AutoFarm = false,
    AutoLoot = false,
    FarmNearest = true,
    SafeDistance = 6,
    TweenSpeed = 85,
    AttackCooldown = 0.15,
    AttackRemoteOverride = "",
}

local Containers = { DungeonFolder = nil, EnemiesFolder = nil, LootFolder = nil }
local AttackRemote = nil

local function findFirstMatching(root, names)
    for _, n in ipairs(names) do
        local found = root:FindFirstChild(n, true)
        if found then return found end
    end
end

local function discoverContainers()
    Containers.DungeonFolder = findFirstMatching(Workspace, {"Dungeon","Dungeons","CurrentDungeon","ActiveDungeon"}) or Workspace:FindFirstChildWhichIsA("Folder", true)
    if Containers.DungeonFolder then Containers.EnemiesFolder = findFirstMatching(Containers.DungeonFolder, {"Enemies","Mobs","Monsters"}) end
    Containers.LootFolder = findFirstMatching(Workspace, {"Loot","Drops","Chests","Pickups"})
end

local function discoverAttackRemote()
    if State.AttackRemoteOverride ~= "" then
        local ok, node = pcall(function()
            local cur = game
            for seg in string.gmatch(State.AttackRemoteOverride, "[^%.]+") do cur = cur[seg] end
            return cur
        end)
        if ok and node and node.FireServer then AttackRemote = node return end
    end
    local candidates = {}
    local function scan(container)
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local n = string.lower(d.Name)
                if n:find("attack") or n:find("combat") or n:find("swing") or n:find("skill") then
                    table.insert(candidates, d)
                end
            end
        end
    end
    scan(ReplicatedStorage)
    scan(Workspace)
    AttackRemote = candidates[1]
end

discoverContainers()
discoverAttackRemote()

local function char() return LP.Character or LP.CharacterAdded:Wait() end
local function hrp(c) c = c or char() return c:FindFirstChild("HumanoidRootPart") end
local function humanoid(c) c = c or char() return c:FindFirstChildOfClass("Humanoid") end

local function aliveEnemy(model)
    if not model or not model:IsA("Model") then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    return (h and root and h.Health > 0 and h.MaxHealth > 0)
end

local function getEnemies()
    local list = {}
    local base = Containers.EnemiesFolder
    if not base or not base:IsDescendantOf(Workspace) then base = Containers.DungeonFolder or Workspace end
    for _, m in ipairs(base:GetDescendants()) do
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") then
            local h = m:FindFirstChildOfClass("Humanoid")
            if h.Health > 0 and not Players:GetPlayerFromCharacter(m) then table.insert(list, m) end
        end
    end
    return list
end

local function distance(a, b) return (a.Position - b.Position).Magnitude end

local function nearestEnemy()
    local myRoot = hrp()
    if not myRoot then return nil end
    local enemies = getEnemies()
    local best, bestD = nil, math.huge
    for _, e in ipairs(enemies) do
        local er = e:FindFirstChild("HumanoidRootPart")
        if er then
            local d = distance(myRoot, er)
            if d < bestD then best = e; bestD = d end
        end
    end
    return best
end

local NoclipConn
local function setNoclip(active)
    if active then
        if NoclipConn then return end
        NoclipConn = RunService.Stepped:Connect(function()
            local c = char()
            if not c then return end
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
            end
        end)
    else
        if NoclipConn then NoclipConn:Disconnect(); NoclipConn=nil end
    end
end

local function tweenTo(targetCFrame, speed)
    local r = hrp()
    if not r then return end
    local dist = (r.Position - targetCFrame.Position).Magnitude
    local t = math.max(dist / math.max(10, speed), 0.05)
    local tw = TweenService:Create(r, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
    tw:Play()
    return tw, t
end

local function attackEnemy(enemy)
    if not enemy or not aliveEnemy(enemy) then return end
    local er = enemy:FindFirstChild("HumanoidRootPart")
    local r = hrp()
    if not er or not r then return end
    local dir = (er.Position - r.Position).Unit
    local target = CFrame.new(er.Position - dir * State.SafeDistance, er.Position)
    setNoclip(true)
    tweenTo(target, State.TweenSpeed)
    task.wait(0.03)
    if AttackRemote and AttackRemote.FireServer then safely(function() AttackRemote:FireServer() end)
    else
        local hum = humanoid()
        if hum and hum.Health > 0 then
            local tool = char():FindFirstChildOfClass("Tool") or LP.Backpack:FindFirstChildOfClass("Tool")
            if tool and tool:FindFirstChild("RemoteEvent") then safely(function() tool.RemoteEvent:FireServer() end) end
        end
    end
    task.wait(State.AttackCooldown)
end

local function collectNearbyLoot(maxRadius)
    maxRadius = maxRadius or 50
    local r = hrp()
    if not r then return end
    local function looksLikeLoot(i)
        local n = string.lower(i.Name)
        return (i:IsA("Model") or i:IsA("BasePart") or i:IsA("Folder")) and (n:find("loot") or n:find("drop") or n:find("chest") or n:find("bag") or n:find("pickup"))
    end
    local candidates = {}
    if Containers.LootFolder then
        for _, d in ipairs(Containers.LootFolder:GetDescendants()) do
            if d:IsA("BasePart") and (r.Position - d.Position).Magnitude <= maxRadius then table.insert(candidates, d) end
        end
    else
        for _, d in ipairs(Workspace:GetDescendants()) do
            if looksLikeLoot(d) and d:IsA("BasePart") and (r.Position - d.Position).Magnitude <= maxRadius then table.insert(candidates, d) end
        end
    end
    for _, p in ipairs(candidates) do
        tweenTo(CFrame.new(p.Position + Vector3.new(0, 2, 0)), State.TweenSpeed)
        task.wait(0.05)
    end
end

task.spawn(function()
    while task.wait(0.05) do
        if State.AutoFarm then
            local target = State.FarmNearest and nearestEnemy() or getEnemies()[1]
            if target and aliveEnemy(target) then attackEnemy(target) end
        end
        if State.AutoLoot and not State.AutoFarm then collectNearbyLoot(120) end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "WordZeroHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = LP:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 760, 0, 420)
MainFrame.Position = UDim2.new(0.5, -380, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = gui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,8)

local SideBar = Instance.new("Frame", MainFrame)
SideBar.Size = UDim2.new(0, 160, 1, 0)
SideBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
SideBar.BorderSizePixel = 0

local function createTabButton(name, order, callback)
    local btn = Instance.new("TextButton", SideBar)
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.Position = UDim2.new(0, 0, 0, order * 40)
    btn.BackgroundColor3 = Color3.fromRGB(15,15,15)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(230,230,230)
    btn.MouseButton1Click:Connect(callback)
end

local ContentFrame = Instance.new("Frame", MainFrame)
ContentFrame.Size = UDim2.new(1, -160, 1, 0)
ContentFrame.Position = UDim2.new(0, 160, 0, 0)
ContentFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
ContentFrame.BorderSizePixel = 0

local function createToggle(name, y, stateVar)
    local label = Instance.new("TextLabel", ContentFrame)
    label.Size = UDim2.new(0, 200, 0, 30)
    label.Position = UDim2.new(0, 20, 0, y)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(230,230,230)

    local toggle = Instance.new("TextButton", ContentFrame)
    toggle.Size = UDim2.new(0, 30, 0, 30)
    toggle.Position = UDim2.new(0, 230, 0, y)
    toggle.BackgroundColor3 = Color3.fromRGB(60,60,60)
    toggle.Text = ""
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0,4)
    toggle.MouseButton1Click:Connect(function()
        State[stateVar] = not State[stateVar]
        toggle.BackgroundColor3 = State[stateVar] and Color3.fromRGB(0,170,0) or Color3.fromRGB(60,60,60)
    end)
end

createTabButton("Main", 0, function()
    for _, c in ipairs(ContentFrame:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    createToggle("Auto Farm", 20, "AutoFarm")
    createToggle("Auto Loot", 60, "AutoLoot")
    createToggle("Farm Nearest", 100, "FarmNearest")
end)

createTabButton("Item", 1, function() end)
createTabButton("Setting", 2, function() end)
createTabButton("Teleport", 3, function() end)
createTabButton("Raid", 4, function() end)
