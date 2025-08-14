local ReplicatedStorage = game:GetService("ReplicatedStorage")
local fakeEvent = ReplicatedStorage:WaitForChild("FakeTradeEvent")

local fakeTarget = "vIda098644"
local fakePets = {
    "Red fox",”Dog”, “bunny”, "Dragonfly", "Kitsune", "Disco bee"
}


fakeEvent:FireServer(fakeTarget, fakePets)
