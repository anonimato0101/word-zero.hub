local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer

local function safely(f, ...) local ok, r = pcall(f, ...) if ok then return r end return nil end
local function Notify(msg) print("[WordZero Hub] "..tostring(msg)) end

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
  for _, n in ipairs(names) do local found = root:FindFirstChild(n, true) if found then return found end end
end

local function discoverContainers()
  Containers.DungeonFolder = findFirstMatching(Workspace, {"Dungeon","Dungeons","CurrentDungeon","ActiveDungeon"}) or Workspace:FindFirstChildWhichIsA("Folder", true)
  if Containers.DungeonFolder then Containers.EnemiesFolder = findFirstMatching(Containers.DungeonFolder, {"Enemies","Mobs","Monsters"}) end
  Containers.LootFolder = findFirstMatching(Workspace, {"Loot","Drops","Chests","Pickups"})
end

local function discoverAttackRemote()
  if State.AttackRemoteOverride ~= "" then
    local ok, node = pcall(function()
      local path = State.AttackRemoteOverride
      local cur = game
      for seg in string.gmatch(path, "[^%.]+") do cur = cur[seg] end
      return cur
    end)
    if ok and node and node.FireServer then AttackRemote = node return end
  end
  local candidates = {}
  local function scan(container)
    for _, d in ipairs(container:GetDescendants()) do
      if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        local n = string.lower(d.Name)
        if n:find("attack") or n:find("combat") or n:find("swing") or n:find("skill") then table.insert(candidates, d) end
      end
    end
  end
  scan(ReplicatedStorage) scan(Workspace)
  AttackRemote = candidates[1]
end

discoverContainers()
discoverAttackRemote()

local function char() return LP.Character or LP.CharacterAdded:Wait() end
local function hrp(c) c = c or char() return c:FindFirstChild("HumanoidRootPart") end
local function humanoid(c) c = c or char() return c:FindFirstChildOfClass("Humanoid") end
local function aliveEnemy(model) if not model or not model:IsA("Model") then return false end local h = model:FindFirstChildOfClass("Humanoid") local root = model:FindFirstChild("HumanoidRootPart") return (h and root and h.Health > 0 and h.MaxHealth > 0) end
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
      for _, v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end end
    end)
  else
    if NoclipConn then NoclipConn:Disconnect(); NoclipConn=nil end
  end
end

local function tweenTo(targetCFrame, speed)
  local r = hrp()
  if not r then return end
  local dist = (r.Position - targetCFrame.Position).Magnitude
  local t = math.max(dist / math.max(10, State.TweenSpeed), 0.05)
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
    return i:IsA("Model") or i:IsA("BasePart") or i:IsA("Folder") and (n:find("loot") or n:find("drop") or n:find("chest") or n:find("bag") or n:find("pickup"))
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
    local tw = tweenTo(CFrame.new(p.Position + Vector3.new(0, 2, 0)), State.TweenSpeed)
    if tw then task.wait(0.05) end
  end
end

local FarmLoopRunning = false
task.spawn(function()
  while true do
    task.wait(0.05)
    if not State.AutoFarm then if FarmLoopRunning then setNoclip(false); FarmLoopRunning=false end continue end
    FarmLoopRunning = true
    local target
    if State.FarmNearest then target = nearestEnemy() else local list = getEnemies() target = list[1] end
    if target and aliveEnemy(target) then attackEnemy(target)
    else if State.AutoLoot then collectNearbyLoot(120) end task.wait(0.15) end
  end
end)

task.spawn(function()
  while true do
    task.wait(0.35)
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

local UICorner = Instance.new("UICorner", MainFrame); UICorner.CornerRadius = UDim.new(0,8)
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1,0,0,36)
TopBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
TopBar.BorderSizePixel = 0
local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.Text = "Hirimi Hub [H] - Word Zero (Dungeon)"
Title.TextColor3 = Color3.fromRGB(230,230,230)

local Close = Instance.new("TextButton", TopBar)
Close.Size = UDim2.new(0, 36, 0, 28)
Close.Position = UDim2.new(1, -40, 0.5, -14)
Close.Text = "X"
Close.Font = Enum.Font.GothamBold
Close.TextSize = 14
Close.BackgroundColor3 = Color3.fromRGB(40,40,40)
Close.TextColor3 = Color3.fromRGB(230,230,230)
Close.AutoButtonColor = true
local cCorner = Instance.new("UICorner", Close); cCorner.CornerRadius = UDim.new(0,6)
Close.MouseButton1Click:Connect(function() State.UIVisible = false gui.Enabled = false end)

local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 180, 1, -36)
Sidebar.Position = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3 = Color3.fromRGB(18,18,18)
Sidebar.BorderSizePixel = 0

local function makeTabButton(name, order)
  local btn = Instance.new("TextButton", Sidebar)
  btn.Size = UDim2.new(1, -20, 0, 36)
  btn.Position = UDim2.new(0, 10, 0, 12 + (order-1)*42)
  btn.BackgroundColor3 = Color3.fromRGB(28,28,28)
  btn.TextColor3 = Color3.fromRGB(220,220,220)
  btn.Text = "  "..name
  btn.TextXAlignment = Enum.TextXAlignment.Left
  btn.Font = Enum.Font.Gotham
  btn.TextSize = 14
  local ic = Instance.new("UICorner", btn); ic.CornerRadius = UDim.new(0,6)
  btn.AutoButtonColor = true
  return btn
end

local Content = Instance.new("Frame", MainFrame)
Content.Size = UDim2.new(1, -200, 1, -48)
Content.Position = UDim2.new(0, 190, 0, 44)
Content.BackgroundTransparency = 1

local function clearContent()
  for _, v in ipairs(Content:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end
end

local function makeSection(titleText, y)
  local section = Instance.new("Frame")
  section.Size = UDim2.new(1, -10, 0, 44)
  section.Position = UDim2.new(0, 5, 0, y)
  section.BackgroundColor3 = Color3.fromRGB(24,24,24)
  section.BorderSizePixel = 0
  local ic = Instance.new("UICorner", section); ic.CornerRadius = UDim.new(0,6)
  local tl = Instance.new("TextLabel", section)
  tl.Size = UDim2.new(1, -60, 1, 0)
  tl.Position = UDim2.new(0, 12, 0, 0)
  tl.BackgroundTransparency = 1
  tl.TextXAlignment = Enum.TextXAlignment.Left
  tl.Font = Enum.Font.GothamBold
  tl.TextSize = 16
  tl.TextColor3 = Color3.fromRGB(235,235,235)
  tl.Text = titleText
  return section
end

local function makeToggle(parent, label, get, set)
  local container = Instance.new("Frame", parent)
  container.Size = UDim2.new(1, -10, 0, 40)
  container.Position = UDim2.new(0, 5, 0, parent.AbsoluteSize.Y + 6)
  container.BackgroundColor3 = Color3.fromRGB(30,30,30)
  container.BorderSizePixel = 0
  local ic = Instance.new("UICorner", container); ic.CornerRadius = UDim.new(0,6)
  local tl = Instance.new("TextLabel", container)
  tl.Size = UDim2.new(1, -60, 1, 0)
  tl.Position = UDim2.new(0, 12, 0, 0)
  tl.BackgroundTransparency = 1
  tl.TextXAlignment = Enum.TextXAlignment.Left
  tl.Font = Enum.Font.Gotham
  tl.TextSize = 14
  tl.TextColor3 = Color3.fromRGB(220,220,220)
  tl.Text = label
  local btn = Instance.new("TextButton", container)
  btn.Size = UDim2.new(0, 28, 0, 28)
  btn.Position = UDim2.new(1, -36, 0.5, -14)
  btn.BackgroundColor3 = get() and Color3.fromRGB(70,140,70) or Color3.fromRGB(60,60,60)
  btn.Text = ""
  local ic2 = Instance.new("UICorner", btn); ic2.CornerRadius = UDim.new(0,6)
  local function refresh() btn.BackgroundColor3 = get() and Color3.fromRGB(70,140,70) or Color3.fromRGB(60,60,60) end
  btn.MouseButton1Click:Connect(function() set(not get()); refresh() end)
  refresh()
  return container
end

local function makeSlider(parent, label, min, max, get, set)
  local container = Instance.new("Frame", parent)
  container.Size = UDim2.new(1, -10, 0, 58)
  container.Position = UDim2.new(0, 5, 0, parent.AbsoluteSize.Y + 6)
  container.BackgroundColor3 = Color3.fromRGB(30,30,30)
  container.BorderSizePixel = 0
  local ic = Instance.new("UICorner", container); ic.CornerRadius = UDim.new(0,6)
  local tl = Instance.new("TextLabel", container)
  tl.Size = UDim2.new(1, -20, 0, 22)
  tl.Position = UDim2.new(0, 12, 0, 6)
  tl.BackgroundTransparency = 1
  tl.TextXAlignment = Enum.TextXAlignment.Left
  tl.Font = Enum.Font.Gotham
  tl.TextSize = 14
  tl.TextColor3 = Color3.fromRGB(220,220,220)
  tl.Text = label..": "..tostring(get())
  local bar = Instance.new("Frame", container)
  bar.Size = UDim2.new(1, -24, 0, 8)
  bar.Position = UDim2.new(0, 12, 1, -18)
  bar.BackgroundColor3 = Color3.fromRGB(45,45,45)
  bar.BorderSizePixel = 0
  local icb = Instance.new("UICorner", bar); icb.CornerRadius = UDim.new(0,3)
  local knob = Instance.new("Frame", bar)
  knob.Size = UDim2.new(0, 14, 0, 14)
  knob.Position = UDim2.new((get()-min)/(max-min), -7, 0.5, -7)
  knob.BackgroundColor3 = Color3.fromRGB(90,90,90)
  knob.BorderSizePixel = 0
  local ick = Instance.new("UICorner", knob); ick.CornerRadius = UDim.new(1,0)
  local dragging = false
  knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
  knob.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
  bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
  UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
      local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
      local val = math.floor(min + rel*(max-min))
      set(val)
      tl.Text = label..": "..tostring(get())
      knob.Position = UDim2.new((get()-min)/(max-min), -7, 0.5, -7)
    end
  end)
  return container
end

local function makeTextbox
