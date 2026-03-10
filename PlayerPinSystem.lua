-- ╔═══════════════════════════════════════════════════════════════╗
-- ║               PLAYER PIN SYSTEM v3.1                         ║
-- ║           Place in: StarterPlayerScripts                     ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════
--  CONSTANTS
-- ══════════════════════════════════════════════════════════════
local BUTTON_IMAGE  = "rbxassetid://118356804611389"
local BG_IMAGE      = "rbxassetid://71857719940851"
local SPIN_SPEED    = 99999999
local PIN_OFFSET_Y  = 3.2
local LEAD_MULT     = 1.5
local ATTACK_DELAY  = 0.18

-- ══════════════════════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════════════════════
local State = {
    Target        = nil,
    Pinning       = false,
    SpinAngle     = 0,
    NoclipEnabled = true,
    CameraLock    = true,
    AttackEnabled = true,
    RangeEnabled  = true,
    SpinPaused    = false,
    GuiOpen       = false,
    AttackKeys    = {
        Enum.KeyCode.One,
        Enum.KeyCode.Two,
        Enum.KeyCode.Three,
        Enum.KeyCode.Four,
    },
}

-- ══════════════════════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════════════════════
local function getRoot(plr)
    local c = plr and plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getMyRoot() return getRoot(LocalPlayer) end
local function getMyHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function resetMovement()
    local h = getMyHum()
    if h then h.PlatformStand = false; h.AutoRotate = true end
end
local function resetCamera()
    Camera.CameraType = Enum.CameraType.Custom
    local h = getMyHum()
    if h then Camera.CameraSubject = h end
end

local GUI  -- forward declare

local function stopPin()
    State.Target     = nil
    State.Pinning    = false
    State.SpinPaused = false
    resetMovement()
    resetCamera()
    if GUI then
        GUI.StatusLabel.Text          = "Target: None"
        GUI.StatusLabel.TextColor3    = Color3.fromRGB(150,150,150)
        GUI.PauseBtn.Text             = "⏸  Pause Pin"
        GUI.PauseBtn.BackgroundColor3 = Color3.fromRGB(160,120,15)
    end
end

-- ══════════════════════════════════════════════════════════════
--  DRAG
-- ══════════════════════════════════════════════════════════════
local function makeDraggable(f)
    local drag, di, ds, sp
    f.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = i.Position; sp = f.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    f.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then di = i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i == di then
            local d = i.Position - ds
            f.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  GUI  —  Menu: 280 × 430
-- ══════════════════════════════════════════════════════════════
local function makeGui()
    if PlayerGui:FindFirstChild("PinSystemGui") then
        PlayerGui.PinSystemGui:Destroy()
    end

    local SG            = Instance.new("ScreenGui")
    SG.Name             = "PinSystemGui"
    SG.ResetOnSpawn     = false
    SG.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
    SG.IgnoreGuiInset   = true
    SG.Parent           = PlayerGui

    -- Main button 60×60
    local MB            = Instance.new("ImageButton")
    MB.Name             = "MainButton"
    MB.Size             = UDim2.new(0, 60, 0, 60)
    MB.Position         = UDim2.new(0, 16, 0.5, -30)
    MB.BackgroundTransparency = 1
    MB.Image            = BUTTON_IMAGE
    MB.ZIndex           = 10
    MB.Parent           = SG
    Instance.new("UICorner", MB).CornerRadius = UDim.new(1, 0)
    makeDraggable(MB)

    -- Menu frame 280×430
    local MF            = Instance.new("Frame")
    MF.Name             = "MenuFrame"
    MF.Size             = UDim2.new(0, 280, 0, 430)
    MF.Position         = UDim2.new(0.5, -140, 0.5, -215)
    MF.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    MF.BackgroundTransparency = 0.05
    MF.BorderSizePixel  = 0
    MF.Visible          = false
    MF.ZIndex           = 5
    MF.Parent           = SG
    Instance.new("UICorner", MF).CornerRadius = UDim.new(0, 12)
    Instance.new("UIStroke", MF).Color        = Color3.fromRGB(70,110,255)
    Instance.new("UIStroke", MF).Thickness    = 1.5

    local BgImg         = Instance.new("ImageLabel", MF)
    BgImg.Size          = UDim2.new(1,0,1,0)
    BgImg.BackgroundTransparency = 1
    BgImg.Image         = BG_IMAGE
    BgImg.ImageTransparency = 0.45
    BgImg.ZIndex        = 5

    makeDraggable(MF)

    -- Title bar 32px
    local TB            = Instance.new("Frame", MF)
    TB.Size             = UDim2.new(1, 0, 0, 32)
    TB.BackgroundColor3 = Color3.fromRGB(15, 15, 32)
    TB.BorderSizePixel  = 0
    TB.ZIndex           = 6
    Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 12)

    local TL            = Instance.new("TextLabel", TB)
    TL.Size             = UDim2.new(1,-36,1,0)
    TL.Position         = UDim2.new(0, 10, 0, 0)
    TL.BackgroundTransparency = 1
    TL.Text             = "⚙ Pin System v3.1"
    TL.TextColor3       = Color3.fromRGB(200,215,255)
    TL.TextSize         = 13
    TL.Font             = Enum.Font.GothamBold
    TL.TextXAlignment   = Enum.TextXAlignment.Left
    TL.ZIndex           = 7

    local XBtn          = Instance.new("TextButton", TB)
    XBtn.Size           = UDim2.new(0, 24, 0, 24)
    XBtn.Position       = UDim2.new(1, -28, 0, 4)
    XBtn.BackgroundColor3 = Color3.fromRGB(190,45,45)
    XBtn.Text           = "✕"
    XBtn.TextColor3     = Color3.new(1,1,1)
    XBtn.TextSize       = 12
    XBtn.Font           = Enum.Font.GothamBold
    XBtn.BorderSizePixel = 0
    XBtn.ZIndex         = 8
    Instance.new("UICorner", XBtn).CornerRadius = UDim.new(0, 5)

    -- Status 26px at y=38
    local SL            = Instance.new("TextLabel", MF)
    SL.Name             = "StatusLabel"
    SL.Size             = UDim2.new(1, -16, 0, 24)
    SL.Position         = UDim2.new(0, 8, 0, 38)
    SL.BackgroundColor3 = Color3.fromRGB(8,8,18)
    SL.BackgroundTransparency = 0.2
    SL.Text             = "Target: None"
    SL.TextColor3       = Color3.fromRGB(150,150,150)
    SL.TextSize         = 12
    SL.Font             = Enum.Font.Gotham
    SL.ZIndex           = 7
    Instance.new("UICorner", SL).CornerRadius = UDim.new(0, 5)

    -- Toggle helper: w=126, h=26
    local function mkToggle(text, x, y, on)
        local b         = Instance.new("TextButton", MF)
        b.Size          = UDim2.new(0, 126, 0, 26)
        b.Position      = UDim2.new(0, x, 0, y)
        b.BackgroundColor3 = on and Color3.fromRGB(28,85,28) or Color3.fromRGB(85,25,25)
        b.Text          = text..(on and ":ON" or ":OFF")
        b.TextColor3    = Color3.new(1,1,1)
        b.TextSize      = 11
        b.Font          = Enum.Font.Gotham
        b.BorderSizePixel = 0
        b.ZIndex        = 7
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    -- y=68: Noclip | CamLock
    local NoclipBtn  = mkToggle("Noclip",   8,  68, State.NoclipEnabled)
    local CamLockBtn = mkToggle("CamLock", 146,  68, State.CameraLock)

    -- y=100: AutoAttack | Range
    local AttackBtn  = mkToggle("AutoAtk",  8, 100, State.AttackEnabled)
    local RangeBtn   = mkToggle("Range x1000", 146, 100, State.RangeEnabled)

    -- List header y=132
    local LH        = Instance.new("TextLabel", MF)
    LH.Size         = UDim2.new(1,-16,0,18)
    LH.Position     = UDim2.new(0, 8, 0, 132)
    LH.BackgroundTransparency = 1
    LH.Text         = "── Players ──"
    LH.TextColor3   = Color3.fromRGB(100,130,255)
    LH.TextSize     = 11
    LH.Font         = Enum.Font.GothamBold
    LH.ZIndex       = 7

    -- Scroll frame y=154, height=180
    local SF        = Instance.new("ScrollingFrame", MF)
    SF.Name         = "PlayerList"
    SF.Size         = UDim2.new(1, -16, 0, 178)
    SF.Position     = UDim2.new(0, 8, 0, 152)
    SF.BackgroundColor3 = Color3.fromRGB(7,7,18)
    SF.BackgroundTransparency = 0.2
    SF.BorderSizePixel = 0
    SF.ScrollBarThickness = 3
    SF.ScrollBarImageColor3 = Color3.fromRGB(70,110,255)
    SF.ZIndex       = 7
    Instance.new("UICorner", SF).CornerRadius = UDim.new(0, 8)

    local LL        = Instance.new("UIListLayout", SF)
    LL.SortOrder    = Enum.SortOrder.LayoutOrder
    LL.Padding      = UDim.new(0, 3)

    local LP        = Instance.new("UIPadding", SF)
    LP.PaddingLeft  = UDim.new(0, 5)
    LP.PaddingTop   = UDim.new(0, 4)
    LP.PaddingRight = UDim.new(0, 5)

    -- Pause btn y=338 h=38
    local PauseBtn  = Instance.new("TextButton", MF)
    PauseBtn.Name   = "PauseBtn"
    PauseBtn.Size   = UDim2.new(1, -16, 0, 36)
    PauseBtn.Position = UDim2.new(0, 8, 0, 338)
    PauseBtn.BackgroundColor3 = Color3.fromRGB(160,120,15)
    PauseBtn.Text   = "⏸  Pause Pin"
    PauseBtn.TextColor3 = Color3.new(1,1,1)
    PauseBtn.TextSize   = 13
    PauseBtn.Font       = Enum.Font.GothamBold
    PauseBtn.BorderSizePixel = 0
    PauseBtn.ZIndex = 7
    Instance.new("UICorner", PauseBtn).CornerRadius = UDim.new(0, 8)

    -- Stop btn y=382 h=38
    local StopBtn   = Instance.new("TextButton", MF)
    StopBtn.Name    = "StopBtn"
    StopBtn.Size    = UDim2.new(1, -16, 0, 36)
    StopBtn.Position = UDim2.new(0, 8, 0, 382)
    StopBtn.BackgroundColor3 = Color3.fromRGB(170,35,35)
    StopBtn.Text    = "⛔  Stop Pin"
    StopBtn.TextColor3  = Color3.new(1,1,1)
    StopBtn.TextSize    = 13
    StopBtn.Font        = Enum.Font.GothamBold
    StopBtn.BorderSizePixel = 0
    StopBtn.ZIndex  = 7
    Instance.new("UICorner", StopBtn).CornerRadius = UDim.new(0, 8)

    return {
        ScreenGui   = SG,
        MainButton  = MB,
        MenuFrame   = MF,
        StatusLabel = SL,
        ScrollFrame = SF,
        NoclipBtn   = NoclipBtn,
        CamLockBtn  = CamLockBtn,
        AttackBtn   = AttackBtn,
        RangeBtn    = RangeBtn,
        PauseBtn    = PauseBtn,
        StopBtn     = StopBtn,
        CloseBtn    = XBtn,
    }
end

-- ══════════════════════════════════════════════════════════════
--  PLAYER LIST
-- ══════════════════════════════════════════════════════════════
local function buildPlayerList()
    if not GUI then return end
    local scroll = GUI.ScrollFrame
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local isTgt = (State.Target == plr)
        local btn   = Instance.new("TextButton", scroll)
        btn.Size    = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = isTgt
            and Color3.fromRGB(35,70,185) or Color3.fromRGB(16,16,40)
        btn.BackgroundTransparency = 0.15
        btn.Text    = "👤 "..plr.DisplayName.." (@"..plr.Name..")"
        btn.TextColor3  = Color3.fromRGB(210,218,255)
        btn.TextSize    = 12
        btn.Font        = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.BorderSizePixel = 0
        btn.ZIndex      = 8
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local p = Instance.new("UIPadding", btn)
        p.PaddingLeft = UDim.new(0, 7)

        btn.MouseButton1Click:Connect(function()
            State.Target     = plr
            State.Pinning    = true
            State.SpinPaused = false
            GUI.StatusLabel.Text          = "📌 "..plr.Name
            GUI.StatusLabel.TextColor3    = Color3.fromRGB(80,220,80)
            GUI.PauseBtn.Text             = "⏸  Pause Pin"
            GUI.PauseBtn.BackgroundColor3 = Color3.fromRGB(160,120,15)
            buildPlayerList()
        end)
    end
    local ll = scroll:FindFirstChildOfClass("UIListLayout")
    if ll then scroll.CanvasSize = UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+8) end
end

-- ══════════════════════════════════════════════════════════════
--  INIT + EVENTS
-- ══════════════════════════════════════════════════════════════
GUI = makeGui()

GUI.MainButton.MouseButton1Click:Connect(function()
    State.GuiOpen         = not State.GuiOpen
    GUI.MenuFrame.Visible = State.GuiOpen
    if State.GuiOpen then buildPlayerList() end
end)

GUI.CloseBtn.MouseButton1Click:Connect(function()
    State.GuiOpen = false; GUI.MenuFrame.Visible = false
end)

GUI.StopBtn.MouseButton1Click:Connect(function()
    stopPin(); buildPlayerList()
end)

GUI.PauseBtn.MouseButton1Click:Connect(function()
    State.SpinPaused = not State.SpinPaused
    if State.SpinPaused then
        State.Pinning = false
        resetMovement()
        GUI.PauseBtn.Text             = "▶  Resume Pin"
        GUI.PauseBtn.BackgroundColor3 = Color3.fromRGB(25,145,25)
        GUI.StatusLabel.Text          = "⏸ Paused"
        GUI.StatusLabel.TextColor3    = Color3.fromRGB(255,195,50)
    else
        if State.Target then
            State.Pinning = true
            GUI.StatusLabel.Text       = "📌 "..State.Target.Name
            GUI.StatusLabel.TextColor3 = Color3.fromRGB(80,220,80)
        end
        GUI.PauseBtn.Text             = "⏸  Pause Pin"
        GUI.PauseBtn.BackgroundColor3 = Color3.fromRGB(160,120,15)
    end
end)

GUI.NoclipBtn.MouseButton1Click:Connect(function()
    State.NoclipEnabled = not State.NoclipEnabled
    GUI.NoclipBtn.BackgroundColor3 = State.NoclipEnabled
        and Color3.fromRGB(28,85,28) or Color3.fromRGB(85,25,25)
    GUI.NoclipBtn.Text = "Noclip:"..(State.NoclipEnabled and "ON" or "OFF")
    if not State.NoclipEnabled then
        local c = LocalPlayer.Character
        if c then for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end end
    end
end)

GUI.CamLockBtn.MouseButton1Click:Connect(function()
    State.CameraLock = not State.CameraLock
    GUI.CamLockBtn.BackgroundColor3 = State.CameraLock
        and Color3.fromRGB(28,85,28) or Color3.fromRGB(85,25,25)
    GUI.CamLockBtn.Text = "CamLock:"..(State.CameraLock and "ON" or "OFF")
    if not State.CameraLock then resetCamera() end
end)

GUI.AttackBtn.MouseButton1Click:Connect(function()
    State.AttackEnabled = not State.AttackEnabled
    GUI.AttackBtn.BackgroundColor3 = State.AttackEnabled
        and Color3.fromRGB(28,85,28) or Color3.fromRGB(85,25,25)
    GUI.AttackBtn.Text = "AutoAtk:"..(State.AttackEnabled and "ON" or "OFF")
end)

GUI.RangeBtn.MouseButton1Click:Connect(function()
    State.RangeEnabled = not State.RangeEnabled
    GUI.RangeBtn.BackgroundColor3 = State.RangeEnabled
        and Color3.fromRGB(28,85,28) or Color3.fromRGB(85,25,25)
    GUI.RangeBtn.Text = "Range x1000:"..(State.RangeEnabled and "ON" or "OFF")
end)

-- ══════════════════════════════════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════════════════════════════════
RunService.Stepped:Connect(function()
    if not State.NoclipEnabled then return end
    local c = LocalPlayer.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  PIN + SPIN
-- ══════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function(dt)
    if not State.Pinning or not State.Target then return end

    local tRoot = getRoot(State.Target)
    local mRoot = getMyRoot()
    if not tRoot or not mRoot then return end

    local tp  = tRoot.Position
    local pos = Vector3.new(tp.X, tp.Y - PIN_OFFSET_Y, tp.Z)

    -- Đi trước x1.5
    local vel = tRoot.AssemblyLinearVelocity
    if vel.Magnitude > 0.1 then
        pos = pos + vel.Unit * (vel.Magnitude * LEAD_MULT * dt)
    end

    State.SpinAngle = State.SpinAngle + SPIN_SPEED * dt

    -- Quạt trần: nằm ngửa + xoay quanh Y thế giới
    mRoot.CFrame = CFrame.new(pos)
        * CFrame.fromEulerAnglesYXZ(0, State.SpinAngle, 0)
        * CFrame.Angles(math.pi / 2, 0, 0)

    local hum = getMyHum()
    if hum then
        hum.PlatformStand = true
        hum.AutoRotate    = false
    end
end)

-- ══════════════════════════════════════════════════════════════
--  RANGE x1000 (handle → target, hitbox thật)
-- ══════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    if not State.RangeEnabled or not State.Pinning or not State.Target then return end
    local tRoot = getRoot(State.Target)
    if not tRoot then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local handle = child:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                handle.CFrame = CFrame.new(tRoot.Position)
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  ATTACK SPAM
-- ══════════════════════════════════════════════════════════════
local lastAtk = 0
RunService.Heartbeat:Connect(function()
    if not State.AttackEnabled or not State.Pinning or not State.Target then return end
    local now = tick()
    if now - lastAtk < ATTACK_DELAY then return end
    lastAtk = now

    local idx = math.floor((now / ATTACK_DELAY) % #State.AttackKeys) + 1
    pcall(function()
        local io          = Instance.new("InputObject")
        io.KeyCode        = State.AttackKeys[idx]
        io.UserInputType  = Enum.UserInputType.Keyboard
        io.UserInputState = Enum.UserInputState.Begin
        UserInputService:FireInputEvent(io)
    end)
    if math.floor(now / ATTACK_DELAY) % 4 == 0 then
        pcall(function()
            local io2          = Instance.new("InputObject")
            io2.UserInputType  = Enum.UserInputType.MouseButton1
            io2.UserInputState = Enum.UserInputState.Begin
            UserInputService:FireInputEvent(io2)
        end)
    end
end)

-- ══════════════════════════════════════════════════════════════
--  CAMERA LOCK
-- ══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    if not State.CameraLock or not State.Target then return end
    local tRoot = getRoot(State.Target)
    if not tRoot then return end
    local offset = Camera.CFrame.Position - Camera.Focus.Position
    Camera.Focus  = CFrame.new(tRoot.Position)
    Camera.CFrame = CFrame.new(tRoot.Position + offset)
                  * (Camera.CFrame - Camera.CFrame.Position)
end)

-- ══════════════════════════════════════════════════════════════
--  WATCH TARGET RESPAWN
-- ══════════════════════════════════════════════════════════════
local function watchTarget(plr)
    plr.CharacterAdded:Connect(function(char)
        if State.Target ~= plr or not State.Pinning then return end
        task.wait(1)
        local nr = char:FindFirstChild("HumanoidRootPart")
        local mr = getMyRoot()
        if nr and mr then
            mr.CFrame = CFrame.new(nr.Position - Vector3.new(0, PIN_OFFSET_Y, 0))
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then watchTarget(p) end
end
Players.PlayerAdded:Connect(function(p)   watchTarget(p); buildPlayerList() end)
Players.PlayerRemoving:Connect(function(p)
    if State.Target == p then stopPin() end
    buildPlayerList()
end)

-- ══════════════════════════════════════════════════════════════
--  MY RESPAWN
-- ══════════════════════════════════════════════════════════════
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.8)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if State.Pinning then
        hum.PlatformStand = true; hum.AutoRotate = false
    else
        hum.PlatformStand = false; hum.AutoRotate = true
    end
end)

-- Auto refresh
task.spawn(function()
    while true do task.wait(5)
        if State.GuiOpen then buildPlayerList() end
    end
end)

print("[PinSystem v3.1] Loaded ✓")
