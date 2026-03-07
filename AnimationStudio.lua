--[[
╔══════════════════════════════════════════════════════════════════╗
║         ROBLOX ANIMATION STUDIO - FULL SYSTEM                   ║
║         Version 1.0 | By Claude                                 ║
║                                                                  ║
║  SYSTEMS:                                                        ║
║  1.  Project Manager                                             ║
║  2.  Workspace / Animation Studio                                ║
║  3.  Viewport 3D                                                 ║
║  4.  Object / Rig System                                         ║
║  5.  Rig & Bone System                                           ║
║  6.  Gizmo System (Move/Rotate/Scale/Pivot)                      ║
║  7.  Pose System                                                 ║
║  8.  Frame & Timeline System                                     ║
║  9.  Keyframe & Interpolation                                    ║
║  10. Onion Skin / Layer System                                   ║
║  11. Object & Camera Animation                                   ║
║  12. Effect & Sound System                                       ║
║  13. Playback & FPS System                                       ║
║  14. Pose & Animation Library                                    ║
║  15. Save / Export System (DataStore)                            ║
╚══════════════════════════════════════════════════════════════════╝

SETUP INSTRUCTIONS:
  1. Place this LocalScript inside StarterPlayerScripts
  2. Create a ScreenGui named "AnimationStudioGui" in StarterGui
     (or let the script auto-create it)
  3. For DataStore (Save System), create a Script in ServerScriptService
     named "AnimationStudioServer" with the server code at the bottom
  4. Required Services are auto-referenced

NOTE: This is a LocalScript. Run in StarterPlayerScripts.
--]]

-- ╔══════════════════════════════════════════════════════╗
-- ║                   SERVICES                          ║
-- ╚══════════════════════════════════════════════════════╝
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local SoundService       = game:GetService("SoundService")

local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")
local Mouse              = LocalPlayer:GetMouse()
local Camera             = workspace.CurrentCamera

-- ╔══════════════════════════════════════════════════════╗
-- ║                GLOBAL STATE                         ║
-- ╚══════════════════════════════════════════════════════╝
local Studio = {
	-- Project
	Projects        = {},        -- { [name] = ProjectData }
	CurrentProject  = nil,       -- Active ProjectData
	IsOpen          = false,     -- Studio window open

	-- Animation State
	CurrentFrame    = 1,
	TotalFrames     = 60,
	FPS             = 24,
	IsPlaying       = false,
	PlayConnection  = nil,
	FrameTimer      = 0,

	-- Selection
	SelectedObject  = nil,       -- Selected rig part / object
	SelectedBone    = nil,
	GizmoMode       = "Move",    -- Move / Rotate / Scale

	-- Layers
	Layers          = {},

	-- Onion Skin
	OnionSkinEnabled  = false,
	OnionGhosts       = {},

	-- Camera control
	CamDragging     = false,
	CamLastPos      = nil,
	CamDist         = 15,
	CamAngleX       = 20,
	CamAngleY       = 0,
	CamTarget       = Vector3.new(0, 3, 0),

	-- Pose Library
	PoseLibrary      = {},       -- { [name] = PoseData }

	-- Animation Library
	AnimLibrary      = {},       -- { [name] = AnimData }

	-- Sound events { [frame] = soundId }
	SoundEvents      = {},

	-- Snap settings
	SnapMove         = 1,
	SnapRotate       = 15,
	SnapScale        = 0.1,
	SnapEnabled      = false,
}

-- ╔══════════════════════════════════════════════════════╗
-- ║             PROJECT DATA STRUCTURE                  ║
-- ╚══════════════════════════════════════════════════════╝
--[[
ProjectData = {
	Name        = "Sword Fight",
	Rig         = "R15",            -- R6 / R15 / Custom
	FPS         = 24,
	Map         = "Studio Map",
	Animation   = {                 -- Keyframes per bone
		-- [boneName] = { [frame] = {CFrame} }
	},
	Layers      = { "Character", "Weapon", "Effects", "Camera" },
	Objects     = {                 -- Scene objects
		-- { Name, Type, BasePart, Layer }
	},
	SoundEvents = {},               -- { [frame] = soundId }
	TotalFrames = 60,
}
--]]

-- ╔══════════════════════════════════════════════════════╗
-- ║               GUI CONSTRUCTION                      ║
-- ╚══════════════════════════════════════════════════════╝

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "AnimationStudioGui"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

-- Colour palette
local C = {
	BG          = Color3.fromRGB(28, 28, 35),
	Panel       = Color3.fromRGB(38, 38, 48),
	Header      = Color3.fromRGB(20, 20, 28),
	Accent      = Color3.fromRGB(100, 149, 237),
	AccentHover = Color3.fromRGB(130, 170, 255),
	Danger      = Color3.fromRGB(220, 60,  60),
	Success     = Color3.fromRGB(60,  200, 100),
	Warning     = Color3.fromRGB(255, 180, 50),
	TextMain    = Color3.fromRGB(220, 220, 230),
	TextDim     = Color3.fromRGB(140, 140, 155),
	Border      = Color3.fromRGB(60,  60,  80),
	Keyframe    = Color3.fromRGB(255, 200, 50),
	Timeline    = Color3.fromRGB(50,  50,  65),
	PlayHead    = Color3.fromRGB(255, 80,  80),
	XAxis       = Color3.fromRGB(220, 60,  60),
	YAxis       = Color3.fromRGB(60,  200, 80),
	ZAxis       = Color3.fromRGB(60,  120, 220),
}

-- Utility: create a frame
local function MakeFrame(props)
	local f = Instance.new("Frame")
	for k,v in pairs(props) do f[k] = v end
	return f
end

local function MakeLabel(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = C.TextMain
	l.Font       = Enum.Font.GothamMedium
	l.TextSize   = 13
	for k,v in pairs(props) do l[k] = v end
	return l
end

local function MakeButton(props)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = C.Accent
	b.TextColor3       = Color3.fromRGB(255,255,255)
	b.Font             = Enum.Font.GothamBold
	b.TextSize         = 13
	b.BorderSizePixel  = 0
	b.AutoButtonColor  = false
	for k,v in pairs(props) do b[k] = v end
	-- Hover effect
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = C.AccentHover}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = b.BackgroundColor3 == C.AccentHover and C.Accent or b.BackgroundColor3}):Play()
	end)
	return b
end

local function MakeInput(props)
	local t = Instance.new("TextBox")
	t.BackgroundColor3     = C.Header
	t.TextColor3           = C.TextMain
	t.PlaceholderColor3    = C.TextDim
	t.Font                 = Enum.Font.Gotham
	t.TextSize             = 13
	t.BorderSizePixel      = 1
	t.BorderColor3         = C.Border
	t.ClearTextOnFocus     = false
	for k,v in pairs(props) do t[k] = v end
	return t
end

local function RoundFrame(parent, size, pos, color, radius)
	local f = MakeFrame({
		Parent              = parent,
		Size                = size,
		Position            = pos,
		BackgroundColor3    = color or C.Panel,
		BorderSizePixel     = 0,
	})
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius or 8)
	ui.Parent = f
	return f
end

-- ═══════════════════════════════════════════════════════
--  PROJECT MANAGER  (shown at startup)
-- ═══════════════════════════════════════════════════════

local PM = {}       -- Project Manager GUI refs

local function BuildProjectManager()
	local overlay = MakeFrame({
		Parent              = ScreenGui,
		Size                = UDim2.new(1,0,1,0),
		BackgroundColor3    = Color3.fromRGB(0,0,0),
		BackgroundTransparency = 0.5,
		ZIndex              = 100,
		Name                = "PMOverlay",
	})

	local win = RoundFrame(overlay,
		UDim2.new(0,620,0,480),
		UDim2.new(0.5,-310,0.5,-240),
		C.BG, 12)
	win.ZIndex = 101

	-- Title bar
	local titleBar = MakeFrame({
		Parent           = win,
		Size             = UDim2.new(1,0,0,44),
		BackgroundColor3 = C.Header,
		BorderSizePixel  = 0,
	})
	Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0,12)
	MakeLabel({
		Parent    = titleBar,
		Text      = "🎬  Animation Studio  —  Project Manager",
		Size      = UDim2.new(1,-60,1,0),
		Position  = UDim2.new(0,16,0,0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize  = 16,
		Font      = Enum.Font.GothamBold,
		ZIndex    = 102,
	})

	-- ── left panel: project list ──
	local leftPanel = MakeFrame({
		Parent = win, Size = UDim2.new(0,200,1,-44),
		Position = UDim2.new(0,0,0,44),
		BackgroundColor3 = C.Panel, BorderSizePixel = 0,
	})
	MakeLabel({Parent=leftPanel, Text="Projects", Size=UDim2.new(1,0,0,30),
		TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,10,0,5), TextSize=14, Font=Enum.Font.GothamBold})

	local listFrame = MakeFrame({
		Parent = leftPanel, Size = UDim2.new(1,-8,1,-90),
		Position = UDim2.new(0,4,0,38),
		BackgroundColor3 = C.BG, BorderSizePixel=0,
	})
	Instance.new("UICorner",listFrame).CornerRadius=UDim.new(0,6)
	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size               = UDim2.new(1,0,1,0)
	listScroll.BackgroundTransparency = 1
	listScroll.ScrollBarThickness = 4
	listScroll.ScrollBarImageColor3 = C.Accent
	listScroll.BorderSizePixel    = 0
	listScroll.Parent             = listFrame
	Instance.new("UIListLayout", listScroll).Padding = UDim.new(0,2)

	local btnNewProj = MakeButton({
		Parent = leftPanel, Size = UDim2.new(1,-8,0,30),
		Position = UDim2.new(0,4,1,-35),
		Text = "+ New Project", BackgroundColor3 = C.Success,
	})

	-- ── right panel: project details + actions ──
	local rightPanel = MakeFrame({
		Parent = win, Size = UDim2.new(1,-208,1,-44),
		Position = UDim2.new(0,204,0,44),
		BackgroundColor3 = C.BG, BorderSizePixel = 0,
	})

	local function InfoRow(label, default, yOff)
		MakeLabel({Parent=rightPanel, Text=label, Size=UDim2.new(0,120,0,28),
			Position=UDim2.new(0,12,0,yOff), TextXAlignment=Enum.TextXAlignment.Left, TextColor3=C.TextDim})
		local inp = MakeInput({Parent=rightPanel, Size=UDim2.new(1,-140,0,28),
			Position=UDim2.new(0,134,0,yOff), PlaceholderText=default, Text=""})
		return inp
	end

	MakeLabel({Parent=rightPanel, Text="Project Details", Size=UDim2.new(1,0,0,30),
		Position=UDim2.new(0,12,0,8), Font=Enum.Font.GothamBold, TextSize=15,
		TextXAlignment=Enum.TextXAlignment.Left})

	local inpName = InfoRow("Project Name","My Animation",42)
	local inpRig  = InfoRow("Rig (R6/R15)","R15",80)
	local inpFPS  = InfoRow("FPS","24",118)
	local inpMap  = InfoRow("Map","Studio Map",156)

	-- Action buttons
	local function ActionBtn(label, color, yOff)
		local b = MakeButton({
			Parent = rightPanel, Size = UDim2.new(1,-24,0,36),
			Position = UDim2.new(0,12,0,yOff),
			Text = label, BackgroundColor3 = color,
			Font = Enum.Font.GothamBold, TextSize = 14,
		})
		Instance.new("UICorner",b).CornerRadius = UDim.new(0,8)
		return b
	end

	local btnOpen    = ActionBtn("▶  Open Project",  C.Accent,  210)
	local btnRename  = ActionBtn("✏  Rename Project", C.Warning, 254)
	local btnDelete  = ActionBtn("🗑  Delete Project", C.Danger,  298)

	-- Status label
	local statusLbl = MakeLabel({
		Parent = rightPanel, Size = UDim2.new(1,-24,0,28),
		Position = UDim2.new(0,12,0,348), TextColor3 = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left, Text = ""
	})

	PM.overlay    = overlay
	PM.listScroll = listScroll
	PM.inpName    = inpName
	PM.inpRig     = inpRig
	PM.inpFPS     = inpFPS
	PM.inpMap     = inpMap
	PM.statusLbl  = statusLbl
	PM.selected   = nil

	-- ── Helper: refresh project list ──
	local function RefreshList()
		for _,c in ipairs(listScroll:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for name, _ in pairs(Studio.Projects) do
			local btn = MakeButton({
				Parent = listScroll, Size = UDim2.new(1,-4,0,34),
				BackgroundColor3 = C.Panel, Text = name,
				TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.Gotham,
				TextSize = 13,
			})
			Instance.new("UICorner",btn).CornerRadius = UDim.new(0,6)
			local uip = Instance.new("UIPadding",btn)
			uip.PaddingLeft = UDim.new(0,8)
			btn.MouseButton1Click:Connect(function()
				PM.selected = name
				local proj = Studio.Projects[name]
				inpName.Text = proj.Name
				inpRig.Text  = proj.Rig
				inpFPS.Text  = tostring(proj.FPS)
				inpMap.Text  = proj.Map
				statusLbl.Text = "Selected: "..name
			end)
		end
		-- auto-size scroll
		listScroll.CanvasSize = UDim2.new(0,0,0, #listScroll:GetChildren()*36)
	end

	-- ── New Project ──
	btnNewProj.MouseButton1Click:Connect(function()
		local n = inpName.Text ~= "" and inpName.Text or "Project_"..tostring(#Studio.Projects+1)
		if Studio.Projects[n] then
			statusLbl.Text = "⚠ Name already exists!" return
		end
		local fps = tonumber(inpFPS.Text) or 24
		Studio.Projects[n] = {
			Name        = n,
			Rig         = inpRig.Text ~= "" and inpRig.Text or "R15",
			FPS         = fps,
			Map         = inpMap.Text ~= "" and inpMap.Text or "Studio Map",
			Animation   = {},
			Layers      = {"Character","Weapon","Effects","Camera"},
			Objects     = {},
			SoundEvents = {},
			TotalFrames = 60,
		}
		statusLbl.Text = "✅ Created: "..n
		RefreshList()
	end)

	-- ── Open Project ──
	btnOpen.MouseButton1Click:Connect(function()
		if not PM.selected then statusLbl.Text="⚠ Select a project first" return end
		Studio.CurrentProject = Studio.Projects[PM.selected]
		overlay.Visible = false
		Studio.IsOpen = true
		OpenStudio()
	end)

	-- ── Rename Project ──
	btnRename.MouseButton1Click:Connect(function()
		if not PM.selected then statusLbl.Text="⚠ Select a project first" return end
		local newName = inpName.Text
		if newName == "" or Studio.Projects[newName] then
			statusLbl.Text="⚠ Invalid or duplicate name" return
		end
		local data = Studio.Projects[PM.selected]
		Studio.Projects[PM.selected] = nil
		data.Name = newName
		Studio.Projects[newName] = data
		PM.selected = newName
		statusLbl.Text = "✅ Renamed to: "..newName
		RefreshList()
	end)

	-- ── Delete Project ──
	btnDelete.MouseButton1Click:Connect(function()
		if not PM.selected then statusLbl.Text="⚠ Select a project first" return end
		Studio.Projects[PM.selected] = nil
		PM.selected = nil
		statusLbl.Text = "🗑 Project deleted"
		inpName.Text="" inpRig.Text="" inpFPS.Text="" inpMap.Text=""
		RefreshList()
	end)

	RefreshList()
end

-- ═══════════════════════════════════════════════════════
--  ANIMATION STUDIO  MAIN WINDOW
-- ═══════════════════════════════════════════════════════

local AS = {}   -- Animation Studio GUI refs

local function OpenStudio()
	if AS.mainWindow and AS.mainWindow.Parent then
		AS.mainWindow.Visible = true
		return
	end

	local proj = Studio.CurrentProject
	Studio.CurrentFrame = 1
	Studio.TotalFrames  = proj.TotalFrames or 60
	Studio.FPS          = proj.FPS or 24

	-- ── Root window ──
	local win = MakeFrame({
		Parent = ScreenGui, Size = UDim2.new(1,0,1,0),
		BackgroundColor3 = C.BG, BorderSizePixel = 0, Name = "StudioWindow",
	})
	AS.mainWindow = win

	-- ── Header ──
	local header = MakeFrame({
		Parent = win, Size = UDim2.new(1,0,0,44),
		BackgroundColor3 = C.Header, BorderSizePixel = 0,
	})
	MakeLabel({Parent=header, Text="🎬 Animation Studio  |  "..proj.Name.."  ["..proj.Rig.."]  "..proj.FPS.."fps",
		Size=UDim2.new(0.6,0,1,0), Position=UDim2.new(0,12,0,0),
		TextXAlignment=Enum.TextXAlignment.Left, TextSize=15, Font=Enum.Font.GothamBold})

	-- Header buttons
	local function HBtn(label, xOff, color)
		local b = MakeButton({Parent=header,
			Size=UDim2.new(0,90,0,30), Position=UDim2.new(1,-xOff,0.5,-15),
			Text=label, BackgroundColor3=color or C.Panel, TextSize=12,
		})
		Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
		return b
	end
	local btnSave   = HBtn("💾 Save",   375, C.Success)
	local btnExport = HBtn("📤 Export", 278, C.Warning)
	local btnBack   = HBtn("◀ Projects",175, C.Danger)
	btnBack.MouseButton1Click:Connect(function()
		win.Visible = false
		PM.overlay.Visible = true
		Studio.IsOpen = false
		StopPlayback()
	end)

	-- ══════════════════════════════════════════════
	-- LAYOUT:  [Object List | Viewport | Properties]
	--          [        Timeline / Keyframes       ]
	-- ══════════════════════════════════════════════

	local contentH  = UDim2.new(1,0,0,420)
	local timelineH = UDim2.new(1,0,0,200)

	-- ── Object List (left sidebar) ──
	local objPanel = MakeFrame({
		Parent=win, Size=UDim2.new(0,180,0,420), Position=UDim2.new(0,0,0,44),
		BackgroundColor3=C.Panel, BorderSizePixel=0,
	})
	MakeLabel({Parent=objPanel, Text="Objects / Bones", Size=UDim2.new(1,0,0,30),
		Position=UDim2.new(0,8,0,4), TextXAlignment=Enum.TextXAlignment.Left,
		Font=Enum.Font.GothamBold, TextSize=13})

	local objScroll = Instance.new("ScrollingFrame")
	objScroll.Size               = UDim2.new(1,-4,1,-80)
	objScroll.Position           = UDim2.new(0,2,0,34)
	objScroll.BackgroundColor3   = C.BG
	objScroll.BackgroundTransparency = 0
	objScroll.ScrollBarThickness = 4
	objScroll.ScrollBarImageColor3 = C.Accent
	objScroll.BorderSizePixel    = 0
	objScroll.Parent             = objPanel
	Instance.new("UIListLayout",objScroll).Padding = UDim.new(0,1)
	Instance.new("UICorner",objScroll).CornerRadius = UDim.new(0,4)

	local btnAddObj = MakeButton({Parent=objPanel, Size=UDim2.new(1,-8,0,28),
		Position=UDim2.new(0,4,1,-62), Text="+ Add Object", BackgroundColor3=C.Success, TextSize=12})
	Instance.new("UICorner",btnAddObj).CornerRadius=UDim.new(0,6)
	local btnAddRig = MakeButton({Parent=objPanel, Size=UDim2.new(1,-8,0,28),
		Position=UDim2.new(0,4,1,-30), Text="+ Add Rig", BackgroundColor3=C.Accent, TextSize=12})
	Instance.new("UICorner",btnAddRig).CornerRadius=UDim.new(0,6)

	AS.objScroll = objScroll

	-- ── Viewport (centre) ──
	local viewport = MakeFrame({
		Parent=win, Size=UDim2.new(1,-360,0,420), Position=UDim2.new(0,180,0,44),
		BackgroundColor3=Color3.fromRGB(15,15,22), BorderSizePixel=0,
	})
	AS.viewport = viewport

	-- Viewport label overlay
	local vpLabel = MakeLabel({
		Parent=viewport, Text="[Viewport — 3D Scene]",
		Size=UDim2.new(1,0,0,24), Position=UDim2.new(0,0,0,4),
		TextColor3=C.TextDim, TextSize=12,
	})

	-- Grid overlay (cosmetic)
	local gridLbl = MakeLabel({
		Parent=viewport, Text="Grid | Camera: Orbit (Right-drag) | Zoom (Scroll)",
		Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,1,-22),
		TextColor3=C.TextDim, TextSize=11,
	})

	-- ── Gizmo Mode toolbar ──
	local gizmoBar = MakeFrame({
		Parent=viewport, Size=UDim2.new(0,220,0,32), Position=UDim2.new(0,4,0,4),
		BackgroundColor3=C.Header, BorderSizePixel=0,
	})
	Instance.new("UICorner",gizmoBar).CornerRadius=UDim.new(0,6)
	Instance.new("UIListLayout",gizmoBar).FillDirection = Enum.FillDirection.Horizontal
	Instance.new("UIListLayout",gizmoBar).Padding = UDim.new(0,2)

	local gizmoModes = {"Move","Rotate","Scale","Pivot"}
	local gizmoBtns  = {}
	for _,mode in ipairs(gizmoModes) do
		local b = MakeButton({Parent=gizmoBar, Size=UDim2.new(0,52,1,0),
			Text=mode, BackgroundColor3=C.Panel, TextSize=11,})
		b.MouseButton1Click:Connect(function()
			Studio.GizmoMode = mode
			for _,gb in pairs(gizmoBtns) do
				gb.BackgroundColor3 = C.Panel
			end
			b.BackgroundColor3 = C.Accent
		end)
		gizmoBtns[mode] = b
	end
	gizmoBtns["Move"].BackgroundColor3 = C.Accent

	-- Snap toggle
	local snapBtn = MakeButton({
		Parent=viewport, Size=UDim2.new(0,80,0,26),
		Position=UDim2.new(0,228,0,7),
		Text="Snap: OFF", BackgroundColor3=C.Panel, TextSize=11,
	})
	Instance.new("UICorner",snapBtn).CornerRadius=UDim.new(0,6)
	snapBtn.MouseButton1Click:Connect(function()
		Studio.SnapEnabled = not Studio.SnapEnabled
		snapBtn.Text = Studio.SnapEnabled and "Snap: ON" or "Snap: OFF"
		snapBtn.BackgroundColor3 = Studio.SnapEnabled and C.Success or C.Panel
	end)

	-- Onion skin toggle
	local onionBtn = MakeButton({
		Parent=viewport, Size=UDim2.new(0,90,0,26),
		Position=UDim2.new(0,312,0,7),
		Text="👻 Onion: OFF", BackgroundColor3=C.Panel, TextSize=11,
	})
	Instance.new("UICorner",onionBtn).CornerRadius=UDim.new(0,6)
	onionBtn.MouseButton1Click:Connect(function()
		Studio.OnionSkinEnabled = not Studio.OnionSkinEnabled
		onionBtn.Text = Studio.OnionSkinEnabled and "👻 Onion: ON" or "👻 Onion: OFF"
		onionBtn.BackgroundColor3 = Studio.OnionSkinEnabled and C.Warning or C.Panel
	end)

	-- ── Properties Panel (right sidebar) ──
	local propPanel = MakeFrame({
		Parent=win, Size=UDim2.new(0,180,0,420), Position=UDim2.new(1,-180,0,44),
		BackgroundColor3=C.Panel, BorderSizePixel=0,
	})
	AS.propPanel = propPanel
	MakeLabel({Parent=propPanel, Text="Properties", Size=UDim2.new(1,0,0,30),
		Position=UDim2.new(0,8,0,4), TextXAlignment=Enum.TextXAlignment.Left,
		Font=Enum.Font.GothamBold, TextSize=13})

	local function PropRow(label, placeholder, yOff)
		MakeLabel({Parent=propPanel, Text=label, Size=UDim2.new(1,0,0,18),
			Position=UDim2.new(0,8,0,yOff), TextColor3=C.TextDim, TextSize=11,
			TextXAlignment=Enum.TextXAlignment.Left})
		local inp = MakeInput({Parent=propPanel, Size=UDim2.new(1,-12,0,24),
			Position=UDim2.new(0,6,0,yOff+18), PlaceholderText=placeholder, Text=""})
		Instance.new("UICorner",inp).CornerRadius=UDim.new(0,4)
		return inp
	end

	local inpPX = PropRow("Position X","0",  32)
	local inpPY = PropRow("Position Y","0",  78)
	local inpPZ = PropRow("Position Z","0", 124)
	local inpRX = PropRow("Rotation X","0", 178)
	local inpRY = PropRow("Rotation Y","0", 224)
	local inpRZ = PropRow("Rotation Z","0", 270)

	AS.propInputs = {PX=inpPX,PY=inpPY,PZ=inpPZ,RX=inpRX,RY=inpRY,RZ=inpRZ}

	-- Apply transform button
	local btnApply = MakeButton({Parent=propPanel, Size=UDim2.new(1,-12,0,30),
		Position=UDim2.new(0,6,0,320), Text="✅ Apply Transform",
		BackgroundColor3=C.Success, TextSize=12})
	Instance.new("UICorner",btnApply).CornerRadius=UDim.new(0,6)
	btnApply.MouseButton1Click:Connect(function() ApplyTransformFromInputs() end)

	-- Pose library button
	local btnSavePose = MakeButton({Parent=propPanel, Size=UDim2.new(1,-12,0,26),
		Position=UDim2.new(0,6,0,358), Text="💾 Save Pose",
		BackgroundColor3=C.Accent, TextSize=12})
	Instance.new("UICorner",btnSavePose).CornerRadius=UDim.new(0,6)
	btnSavePose.MouseButton1Click:Connect(function() OpenSavePoseDialog() end)

	-- ═══════════════════════════════════════════
	-- TIMELINE + KEYFRAME EDITOR
	-- ═══════════════════════════════════════════
	local tlPanel = MakeFrame({
		Parent=win, Size=UDim2.new(1,0,0,200), Position=UDim2.new(0,0,0,464),
		BackgroundColor3=C.Header, BorderSizePixel=0,
	})
	AS.timelinePanel = tlPanel

	-- Playback bar
	local pbBar = MakeFrame({
		Parent=tlPanel, Size=UDim2.new(1,0,0,40), Position=UDim2.new(0,0,0,0),
		BackgroundColor3=C.Panel, BorderSizePixel=0,
	})

	local function PbBtn(label, xOff, w)
		local b = MakeButton({Parent=pbBar, Size=UDim2.new(0,w or 36,0,28),
			Position=UDim2.new(0,xOff,0,6), Text=label, BackgroundColor3=C.BG,
			TextSize=16, Font=Enum.Font.GothamBold,
		})
		Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
		return b
	end
	local btnFirst  = PbBtn("⏮",  8)
	local btnPrev   = PbBtn("◀", 48)
	local btnPlay   = PbBtn("▶", 88, 48)
	local btnPause  = PbBtn("⏸",140)
	local btnNext   = PbBtn("▶|",180)
	local btnLast   = PbBtn("⏭",220)

	-- Frame counter
	AS.frameLabel = MakeLabel({Parent=pbBar, Text="Frame: 1 / 60",
		Size=UDim2.new(0,100,1,0), Position=UDim2.new(0,264,0,0),
		TextColor3=C.Accent, TextSize=13, Font=Enum.Font.GothamBold})

	-- FPS selector
	MakeLabel({Parent=pbBar, Text="FPS:", Size=UDim2.new(0,32,0,28),
		Position=UDim2.new(0,374,0,6), TextColor3=C.TextDim, TextSize=12})
	local fpsInput = MakeInput({Parent=pbBar, Size=UDim2.new(0,40,0,28),
		Position=UDim2.new(0,408,0,6), Text=tostring(proj.FPS), PlaceholderText="FPS"})
	Instance.new("UICorner",fpsInput).CornerRadius=UDim.new(0,4)
	fpsInput.FocusLost:Connect(function()
		local v = tonumber(fpsInput.Text)
		if v and v > 0 then Studio.FPS = v; proj.FPS = v end
	end)

	-- Total frames input
	MakeLabel({Parent=pbBar, Text="Frames:", Size=UDim2.new(0,50,0,28),
		Position=UDim2.new(0,456,0,6), TextColor3=C.TextDim, TextSize=12})
	local totalFInput = MakeInput({Parent=pbBar, Size=UDim2.new(0,50,0,28),
		Position=UDim2.new(0,508,0,6), Text=tostring(proj.TotalFrames), PlaceholderText="Total"})
	Instance.new("UICorner",totalFInput).CornerRadius=UDim.new(0,4)
	totalFInput.FocusLost:Connect(function()
		local v = tonumber(totalFInput.Text)
		if v and v > 0 then
			Studio.TotalFrames = v; proj.TotalFrames = v
			RebuildTimeline()
		end
	end)

	-- ── Layer selector ──
	local layerBar = MakeFrame({
		Parent=tlPanel, Size=UDim2.new(0,160,1,-40), Position=UDim2.new(0,0,0,40),
		BackgroundColor3=C.BG, BorderSizePixel=0,
	})
	MakeLabel({Parent=layerBar, Text="Layers", Size=UDim2.new(1,0,0,28),
		Position=UDim2.new(0,4,0,2), TextXAlignment=Enum.TextXAlignment.Left,
		Font=Enum.Font.GothamBold, TextSize=12, TextColor3=C.TextDim})
	local layerScroll = Instance.new("ScrollingFrame")
	layerScroll.Size               = UDim2.new(1,0,1,-30)
	layerScroll.Position           = UDim2.new(0,0,0,30)
	layerScroll.BackgroundTransparency = 1
	layerScroll.ScrollBarThickness = 4
	layerScroll.BorderSizePixel    = 0
	layerScroll.Parent             = layerBar
	Instance.new("UIListLayout",layerScroll).Padding = UDim.new(0,2)
	AS.layerScroll = layerScroll

	-- ── Timeline (scrollable frames) ──
	local tlOuter = MakeFrame({
		Parent=tlPanel, Size=UDim2.new(1,-160,1,-40), Position=UDim2.new(0,160,0,40),
		BackgroundColor3=C.Timeline, BorderSizePixel=0,
	})
	local tlScroll = Instance.new("ScrollingFrame")
	tlScroll.Size               = UDim2.new(1,0,1,0)
	tlScroll.BackgroundTransparency = 1
	tlScroll.ScrollBarThickness = 6
	tlScroll.ScrollBarImageColor3 = C.Accent
	tlScroll.BorderSizePixel    = 0
	tlScroll.ScrollingDirection  = Enum.ScrollingDirection.X
	tlScroll.Parent             = tlOuter
	AS.timelineScroll = tlScroll

	-- Frame ruler + keyframe rows built by RebuildTimeline()
	AS.frameButtons   = {}
	AS.keyframeUIs    = {}   -- { [boneName] = { [frame] = button } }

	-- ── Playback wiring ──
	btnFirst.MouseButton1Click:Connect(function()
		Studio.CurrentFrame = 1; UpdateFrame()
	end)
	btnLast.MouseButton1Click:Connect(function()
		Studio.CurrentFrame = Studio.TotalFrames; UpdateFrame()
	end)
	btnPrev.MouseButton1Click:Connect(function()
		if Studio.CurrentFrame > 1 then Studio.CurrentFrame -= 1; UpdateFrame() end
	end)
	btnNext.MouseButton1Click:Connect(function()
		if Studio.CurrentFrame < Studio.TotalFrames then Studio.CurrentFrame += 1; UpdateFrame() end
	end)
	btnPlay.MouseButton1Click:Connect(function() StartPlayback() end)
	btnPause.MouseButton1Click:Connect(function() StopPlayback() end)

	-- ── Save button ──
	btnSave.MouseButton1Click:Connect(function() SaveProject() end)

	-- ── Export button ──
	btnExport.MouseButton1Click:Connect(function() OpenExportDialog() end)

	-- Build initial scene
	InitScene()
	RebuildObjectList()
	RebuildLayerList()
	RebuildTimeline()
end

-- ═══════════════════════════════════════════════════════
--  SCENE INITIALISATION
-- ═══════════════════════════════════════════════════════

function InitScene()
	-- Clean old scene objects
	for _,v in ipairs(workspace:GetChildren()) do
		if v:GetAttribute("AnimStudio") then v:Destroy() end
	end

	local proj = Studio.CurrentProject
	if not proj then return end

	-- Floor grid
	local floor = Instance.new("Part")
	floor.Name             = "StudioFloor"
	floor.Anchored         = true
	floor.Size             = Vector3.new(40,0.2,40)
	floor.Position         = Vector3.new(0,-0.1,0)
	floor.Material         = Enum.Material.SmoothPlastic
	floor.BrickColor       = BrickColor.new("Dark stone grey")
	floor.CastShadow       = false
	floor:SetAttribute("AnimStudio",true)
	floor.Parent           = workspace

	-- Spawn rig
	SpawnRig(proj.Rig)

	-- Camera default
	Camera.CameraType      = Enum.CameraType.Scriptable
	UpdateCameraOrbit()
end

-- ═══════════════════════════════════════════════════════
--  RIG SPAWNING
-- ═══════════════════════════════════════════════════════

local RIG_PARTS = {
	R15 = {
		"HumanoidRootPart","UpperTorso","LowerTorso","Head",
		"RightUpperArm","RightLowerArm","RightHand",
		"LeftUpperArm","LeftLowerArm","LeftHand",
		"RightUpperLeg","RightLowerLeg","RightFoot",
		"LeftUpperLeg","LeftLowerLeg","LeftFoot",
	},
	R6 = {
		"HumanoidRootPart","Torso","Head",
		"Right Arm","Left Arm","Right Leg","Left Leg",
	},
}

local RIG_JOINTS = {
	R15 = {
		{p="UpperTorso",    c="Head",           o=CFrame.new(0,0.9,0)},
		{p="LowerTorso",    c="UpperTorso",      o=CFrame.new(0,0.5,0)},
		{p="UpperTorso",    c="RightUpperArm",   o=CFrame.new(1.2,0.5,0)},
		{p="RightUpperArm", c="RightLowerArm",   o=CFrame.new(0,-0.6,0)},
		{p="RightLowerArm", c="RightHand",       o=CFrame.new(0,-0.5,0)},
		{p="UpperTorso",    c="LeftUpperArm",    o=CFrame.new(-1.2,0.5,0)},
		{p="LeftUpperArm",  c="LeftLowerArm",    o=CFrame.new(0,-0.6,0)},
		{p="LeftLowerArm",  c="LeftHand",        o=CFrame.new(0,-0.5,0)},
		{p="LowerTorso",    c="RightUpperLeg",   o=CFrame.new(0.5,-0.5,0)},
		{p="RightUpperLeg", c="RightLowerLeg",   o=CFrame.new(0,-0.8,0)},
		{p="RightLowerLeg", c="RightFoot",       o=CFrame.new(0,-0.7,0)},
		{p="LowerTorso",    c="LeftUpperLeg",    o=CFrame.new(-0.5,-0.5,0)},
		{p="LeftUpperLeg",  c="LeftLowerLeg",    o=CFrame.new(0,-0.8,0)},
		{p="LeftLowerLeg",  c="LeftFoot",        o=CFrame.new(0,-0.7,0)},
	},
}

local PART_SIZES = {
	HumanoidRootPart = Vector3.new(2,2,1),
	UpperTorso       = Vector3.new(2,1.4,1),
	LowerTorso       = Vector3.new(2,1,1),
	Head             = Vector3.new(1.2,1.2,1.2),
	RightUpperArm    = Vector3.new(0.8,1,0.8),
	RightLowerArm    = Vector3.new(0.7,1,0.7),
	RightHand        = Vector3.new(0.7,0.6,0.7),
	LeftUpperArm     = Vector3.new(0.8,1,0.8),
	LeftLowerArm     = Vector3.new(0.7,1,0.7),
	LeftHand         = Vector3.new(0.7,0.6,0.7),
	RightUpperLeg    = Vector3.new(0.9,1.2,0.9),
	RightLowerLeg    = Vector3.new(0.8,1.1,0.8),
	RightFoot        = Vector3.new(0.9,0.5,1.1),
	LeftUpperLeg     = Vector3.new(0.9,1.2,0.9),
	LeftLowerLeg     = Vector3.new(0.8,1.1,0.8),
	LeftFoot         = Vector3.new(0.9,0.5,1.1),
	Torso            = Vector3.new(2,2,1),
	["Right Arm"]    = Vector3.new(1,2,1),
	["Left Arm"]     = Vector3.new(1,2,1),
	["Right Leg"]    = Vector3.new(1,2,1),
	["Left Leg"]     = Vector3.new(1,2,1),
}

local SceneRig    = nil    -- { [partName] = Part }
local SceneMotors = {}     -- { [childName] = Motor6D }

function SpawnRig(rigType)
	-- Remove old rig
	if SceneRig then
		for _,p in pairs(SceneRig) do if p and p.Parent then p:Destroy() end end
		SceneRig = nil; SceneMotors = {}
	end

	rigType = rigType or "R15"
	local parts = RIG_PARTS[rigType] or RIG_PARTS.R15

	local model = Instance.new("Model")
	model.Name = "AnimationRig"
	model:SetAttribute("AnimStudio", true)
	model.Parent = workspace

	SceneRig = {}

	for _, pname in ipairs(parts) do
		local p = Instance.new("Part")
		p.Name     = pname
		p.Anchored = (pname == "HumanoidRootPart" or pname == "Torso")
		p.Size     = PART_SIZES[pname] or Vector3.new(1,1,1)
		p.Material = Enum.Material.SmoothPlastic
		p.BrickColor = (pname == "Head") and BrickColor.new("Pastel yellow") or
		               (pname:find("Arm") or pname:find("Hand")) and BrickColor.new("Pastel yellow") or
		               BrickColor.new("Medium stone grey")
		p.CanCollide = false
		p:SetAttribute("AnimStudio", true)
		p:SetAttribute("RigPart", true)
		p.Parent = model
		SceneRig[pname] = p
	end

	-- Position root
	local root = SceneRig["HumanoidRootPart"] or SceneRig["Torso"]
	if root then root.CFrame = CFrame.new(0, 4, 0) end

	-- Build joints (R15)
	local joints = RIG_JOINTS[rigType]
	if joints then
		for _, j in ipairs(joints) do
			local parent = SceneRig[j.p]
			local child  = SceneRig[j.c]
			if parent and child then
				local motor = Instance.new("Motor6D")
				motor.Name     = j.c
				motor.Part0    = parent
				motor.Part1    = child
				motor.C0       = j.o
				motor.C1       = CFrame.new()
				motor.Parent   = parent
				SceneMotors[j.c] = motor
				child.Anchored = false
			end
		end
	end

	-- Init animation data for all bones
	local proj = Studio.CurrentProject
	if proj then
		for pname, _ in pairs(SceneRig) do
			if not proj.Animation[pname] then
				proj.Animation[pname] = {}
			end
		end
	end

	-- Selectable parts
	for pname, part in pairs(SceneRig) do
		local btn3d = Instance.new("ClickDetector")
		btn3d.MaxActivationDistance = 200
		btn3d.Parent = part
		btn3d.MouseClick:Connect(function()
			Studio.SelectedBone = pname
			Studio.SelectedObject = pname
			UpdatePropertiesPanel(pname)
			RebuildObjectList()
		end)
	end

	RebuildObjectList()
end

-- ═══════════════════════════════════════════════════════
--  ADD CUSTOM OBJECT TO SCENE
-- ═══════════════════════════════════════════════════════

local function AddObjectToScene(objType, objName)
	local proj = Studio.CurrentProject
	if not proj then return end

	local part = Instance.new("Part")
	part.Name     = objName or objType
	part.Anchored = true
	part.Size     = Vector3.new(1,1,1)
	part.Material = Enum.Material.SmoothPlastic
	part.Position = Vector3.new(0, 2, 2)
	part.CanCollide = false
	part:SetAttribute("AnimStudio", true)
	part:SetAttribute("SceneObject", true)
	part.Parent   = workspace

	if objType == "Sword" then
		part.Size = Vector3.new(0.2, 3, 0.2)
		part.BrickColor = BrickColor.new("Bright yellow")
	elseif objType == "Block" then
		part.BrickColor = BrickColor.new("Bright blue")
	elseif objType == "Camera" then
		part.Size = Vector3.new(0.6,0.4,0.8)
		part.BrickColor = BrickColor.new("Really black")
	end

	local objData = {Name=part.Name, Type=objType, Layer="Objects"}
	table.insert(proj.Objects, objData)

	-- Animatable
	if not proj.Animation[part.Name] then
		proj.Animation[part.Name] = {}
	end

	-- Click to select
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 200
	cd.Parent = part
	cd.MouseClick:Connect(function()
		Studio.SelectedObject = part.Name
		Studio.SelectedBone   = nil
		UpdatePropertiesPanel(part.Name)
	end)

	RebuildObjectList()
end

-- ═══════════════════════════════════════════════════════
--  OBJECT LIST REBUILD
-- ═══════════════════════════════════════════════════════

function RebuildObjectList()
	if not AS.objScroll then return end
	for _,c in ipairs(AS.objScroll:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end

	local entries = {}

	-- Rig parts
	if SceneRig then
		for pname, _ in pairs(SceneRig) do
			table.insert(entries, {name=pname, type="Bone"})
		end
	end

	-- Scene objects
	local proj = Studio.CurrentProject
	if proj then
		for _,obj in ipairs(proj.Objects) do
			table.insert(entries, {name=obj.Name, type=obj.Type})
		end
	end

	table.sort(entries, function(a,b) return a.name < b.name end)

	for _, entry in ipairs(entries) do
		local row = MakeButton({
			Parent = AS.objScroll,
			Size   = UDim2.new(1,-2,0,28),
			BackgroundColor3 = (Studio.SelectedObject == entry.name) and C.Accent or C.Panel,
			Text   = entry.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 11, Font = Enum.Font.Gotham,
		})
		Instance.new("UICorner",row).CornerRadius=UDim.new(0,4)
		local uip = Instance.new("UIPadding",row)
		uip.PaddingLeft = UDim.new(0,6)

		local typeTag = MakeLabel({Parent=row, Text=entry.type,
			Size=UDim2.new(0,50,1,0), Position=UDim2.new(1,-54,0,0),
			TextColor3=C.TextDim, TextSize=10,
			TextXAlignment=Enum.TextXAlignment.Right})

		row.MouseButton1Click:Connect(function()
			Studio.SelectedObject = entry.name
			Studio.SelectedBone   = SceneRig and SceneRig[entry.name] and entry.name or nil
			UpdatePropertiesPanel(entry.name)
			RebuildObjectList()
			RebuildTimeline()
		end)
	end

	AS.objScroll.CanvasSize = UDim2.new(0,0,0,#entries*30)

	-- Wire Add buttons
	if AS.mainWindow then
		local btnAddObj = AS.mainWindow:FindFirstChild("StudioWindow") and
		                  AS.mainWindow:FindFirstChild("StudioWindow"):FindFirstChild("btnAddObj")
		-- fallback
	end
end

-- ═══════════════════════════════════════════════════════
--  LAYER LIST REBUILD
-- ═══════════════════════════════════════════════════════

function RebuildLayerList()
	if not AS.layerScroll then return end
	for _,c in ipairs(AS.layerScroll:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
	end
	local proj = Studio.CurrentProject
	if not proj then return end
	for _, layerName in ipairs(proj.Layers) do
		local row = MakeFrame({Parent=AS.layerScroll, Size=UDim2.new(1,0,0,28),
			BackgroundColor3=C.Panel, BorderSizePixel=0})
		Instance.new("UICorner",row).CornerRadius=UDim.new(0,4)

		local vis = true
		local eyeBtn = MakeButton({Parent=row, Size=UDim2.new(0,24,0,24),
			Position=UDim2.new(1,-26,0,2), Text="👁", BackgroundColor3=C.BG, TextSize=12})
		eyeBtn.MouseButton1Click:Connect(function()
			vis = not vis
			eyeBtn.TextColor3 = vis and C.TextMain or C.TextDim
		end)

		MakeLabel({Parent=row, Text=layerName, Size=UDim2.new(1,-32,1,0),
			Position=UDim2.new(0,6,0,0), TextXAlignment=Enum.TextXAlignment.Left,
			TextSize=11, TextColor3=C.TextMain})
	end
	AS.layerScroll.CanvasSize = UDim2.new(0,0,0,#proj.Layers*30)
end

-- ═══════════════════════════════════════════════════════
--  TIMELINE REBUILD
-- ═══════════════════════════════════════════════════════

function RebuildTimeline()
	if not AS.timelineScroll then return end
	for _,c in ipairs(AS.timelineScroll:GetChildren()) do c:Destroy() end

	AS.frameButtons  = {}
	AS.keyframeUIs   = {}

	local proj = Studio.CurrentProject
	if not proj then return end

	local FRAME_W = 24
	local ROW_H   = 24
	local TOTAL_W = Studio.TotalFrames * FRAME_W

	-- Get bone list
	local bones = {}
	if SceneRig then
		for pname in pairs(SceneRig) do table.insert(bones, pname) end
	end
	for _, obj in ipairs(proj.Objects) do
		table.insert(bones, obj.Name)
	end
	table.sort(bones)

	local TL_H = (1 + #bones) * ROW_H + 20

	AS.timelineScroll.CanvasSize = UDim2.new(0, TOTAL_W+40, 0, TL_H)

	-- ── Frame ruler ──
	local rulerFrame = MakeFrame({
		Parent=AS.timelineScroll,
		Size=UDim2.new(0,TOTAL_W,0,ROW_H),
		Position=UDim2.new(0,0,0,0),
		BackgroundColor3=C.Header, BorderSizePixel=0,
	})

	for f = 1, Studio.TotalFrames do
		local fBtn = MakeButton({
			Parent = rulerFrame,
			Size   = UDim2.new(0,FRAME_W-1,0,ROW_H-2),
			Position = UDim2.new(0,(f-1)*FRAME_W,0,1),
			Text   = (f%5==0) and tostring(f) or "",
			BackgroundColor3 = (f == Studio.CurrentFrame) and C.PlayHead or C.BG,
			TextSize = 9, TextColor3 = C.TextDim,
		})
		local fRef = f
		fBtn.MouseButton1Click:Connect(function()
			Studio.CurrentFrame = fRef
			UpdateFrame()
		end)
		AS.frameButtons[f] = fBtn
	end

	-- ── Keyframe rows ──
	for rowIdx, boneName in ipairs(bones) do
		local rowY = ROW_H + (rowIdx-1)*ROW_H

		local rowBg = MakeFrame({
			Parent=AS.timelineScroll,
			Size=UDim2.new(0,TOTAL_W,0,ROW_H-1),
			Position=UDim2.new(0,0,0,rowY),
			BackgroundColor3 = (rowIdx%2==0) and C.Timeline or C.BG,
			BorderSizePixel=0,
		})

		-- bone label
		MakeLabel({Parent=rowBg, Text=boneName, Size=UDim2.new(0,0,1,0),
			TextColor3=Color3.fromRGB(80,80,100), TextSize=9})

		AS.keyframeUIs[boneName] = {}

		local boneAnim = proj.Animation[boneName] or {}
		for f = 1, Studio.TotalFrames do
			local hasKF = boneAnim[f] ~= nil
			local cell = MakeButton({
				Parent = rowBg,
				Size   = UDim2.new(0,FRAME_W-1,0,ROW_H-3),
				Position = UDim2.new(0,(f-1)*FRAME_W,0,1),
				BackgroundColor3 = hasKF and C.Keyframe or Color3.fromRGB(35,35,45),
				Text   = "",
			})
			local fRef, bRef = f, boneName
			cell.MouseButton1Click:Connect(function()
				Studio.CurrentFrame = fRef
				Studio.SelectedBone = bRef
				Studio.SelectedObject = bRef
				UpdateFrame()
				UpdatePropertiesPanel(bRef)
			end)
			-- Right-click to add/remove keyframe
			cell.MouseButton2Click:Connect(function()
				ToggleKeyframe(bRef, fRef)
			end)
			AS.keyframeUIs[boneName][f] = cell
		end
	end

	UpdateFrameIndicator()
end

-- ═══════════════════════════════════════════════════════
--  KEYFRAME LOGIC
-- ═══════════════════════════════════════════════════════

function ToggleKeyframe(boneName, frame)
	local proj = Studio.CurrentProject
	if not proj then return end
	if not proj.Animation[boneName] then proj.Animation[boneName] = {} end

	if proj.Animation[boneName][frame] then
		-- Remove keyframe
		proj.Animation[boneName][frame] = nil
	else
		-- Add keyframe at current pose
		local cf = GetCurrentCFrameForBone(boneName)
		proj.Animation[boneName][frame] = cf
	end
	RefreshKeyframeRow(boneName)
end

function GetCurrentCFrameForBone(boneName)
	-- From motor
	local motor = SceneMotors[boneName]
	if motor then return motor.C0 end
	-- From scene object
	local part = workspace:FindFirstChild(boneName, true)
	if part then return part.CFrame end
	return CFrame.new()
end

function SetCFrameForBone(boneName, cf)
	local motor = SceneMotors[boneName]
	if motor then
		motor.C0 = cf
		return
	end
	local part = workspace:FindFirstChild(boneName, true)
	if part then part.CFrame = cf end
end

function RefreshKeyframeRow(boneName)
	if not AS.keyframeUIs or not AS.keyframeUIs[boneName] then return end
	local proj = Studio.CurrentProject
	if not proj then return end
	local boneAnim = proj.Animation[boneName] or {}
	for f, cell in pairs(AS.keyframeUIs[boneName]) do
		cell.BackgroundColor3 = boneAnim[f] and C.Keyframe or Color3.fromRGB(35,35,45)
	end
end

function UpdateFrameIndicator()
	-- Ruler highlight
	for f, btn in pairs(AS.frameButtons) do
		btn.BackgroundColor3 = (f == Studio.CurrentFrame) and C.PlayHead or C.BG
	end
	if AS.frameLabel then
		AS.frameLabel.Text = "Frame: "..Studio.CurrentFrame.." / "..Studio.TotalFrames
	end
end

-- ═══════════════════════════════════════════════════════
--  INTERPOLATION / POSE EVALUATION
-- ═══════════════════════════════════════════════════════

local function LerpCFrame(a, b, t)
	return a:Lerp(b, t)
end

local function EvaluateBoneAtFrame(boneName, frame)
	local proj = Studio.CurrentProject
	if not proj then return CFrame.new() end
	local boneAnim = proj.Animation[boneName]
	if not boneAnim then return CFrame.new() end

	-- Find surrounding keyframes
	local prevF, nextF = nil, nil
	for f, _ in pairs(boneAnim) do
		if f <= frame then
			if not prevF or f > prevF then prevF = f end
		end
		if f >= frame then
			if not nextF or f < nextF then nextF = f end
		end
	end

	if not prevF and not nextF then return CFrame.new() end
	if prevF and not nextF     then return boneAnim[prevF] end
	if not prevF and nextF     then return boneAnim[nextF] end
	if prevF == nextF          then return boneAnim[prevF] end

	-- Interpolate
	local t = (frame - prevF) / (nextF - prevF)
	return LerpCFrame(boneAnim[prevF], boneAnim[nextF], t)
end

function UpdateFrame()
	local proj = Studio.CurrentProject
	if not proj then return end

	-- Apply pose for all bones
	if SceneRig then
		for pname, _ in pairs(SceneRig) do
			local cf = EvaluateBoneAtFrame(pname, Studio.CurrentFrame)
			SetCFrameForBone(pname, cf)
		end
	end
	for _, obj in ipairs(proj.Objects) do
		local cf = EvaluateBoneAtFrame(obj.Name, Studio.CurrentFrame)
		local part = workspace:FindFirstChild(obj.Name, true)
		if part then part.CFrame = cf end
	end

	-- Onion skin
	if Studio.OnionSkinEnabled then
		DrawOnionSkin()
	end

	-- Sound events
	local snd = proj.SoundEvents[Studio.CurrentFrame]
	if snd then PlaySoundEffect(snd) end

	UpdateFrameIndicator()
	UpdatePropertiesPanel(Studio.SelectedObject)
end

-- ═══════════════════════════════════════════════════════
--  ONION SKIN
-- ═══════════════════════════════════════════════════════

function DrawOnionSkin()
	-- Remove old ghosts
	for _,g in ipairs(Studio.OnionGhosts) do
		if g and g.Parent then g:Destroy() end
	end
	Studio.OnionGhosts = {}

	if not SceneRig then return end
	local proj = Studio.CurrentProject
	if not proj then return end

	for offset = -2, 2 do
		if offset ~= 0 then
			local ghostF = Studio.CurrentFrame + offset
			if ghostF >= 1 and ghostF <= Studio.TotalFrames then
				for pname, part in pairs(SceneRig) do
					local cf = EvaluateBoneAtFrame(pname, ghostF)
					local ghost = Instance.new("SelectionBox")
					ghost.Adornee        = part
					ghost.SurfaceTransparency = 0.8
					ghost.Color3         = offset < 0 and Color3.fromRGB(100,100,255) or Color3.fromRGB(255,100,100)
					ghost.LineThickness  = 0.03
					ghost.Parent         = workspace
					table.insert(Studio.OnionGhosts, ghost)
				end
			end
		end
	end
end

-- ═══════════════════════════════════════════════════════
--  PLAYBACK
-- ═══════════════════════════════════════════════════════

function StartPlayback()
	if Studio.IsPlaying then return end
	Studio.IsPlaying = true
	Studio.FrameTimer = 0
	Studio.PlayConnection = RunService.Heartbeat:Connect(function(dt)
		if not Studio.IsPlaying then return end
		Studio.FrameTimer += dt
		local frameTime = 1 / Studio.FPS
		if Studio.FrameTimer >= frameTime then
			Studio.FrameTimer -= frameTime
			Studio.CurrentFrame += 1
			if Studio.CurrentFrame > Studio.TotalFrames then
				Studio.CurrentFrame = 1
			end
			UpdateFrame()
		end
	end)
end

function StopPlayback()
	Studio.IsPlaying = false
	if Studio.PlayConnection then
		Studio.PlayConnection:Disconnect()
		Studio.PlayConnection = nil
	end
end

-- ═══════════════════════════════════════════════════════
--  PROPERTIES PANEL UPDATE
-- ═══════════════════════════════════════════════════════

function UpdatePropertiesPanel(name)
	if not AS.propInputs then return end
	if not name then return end

	local cf = GetCurrentCFrameForBone(name)
	local pos = cf.Position
	local rx,ry,rz = cf:ToEulerAnglesXYZ()

	local function R(n) return math.floor(n*1000)/1000 end

	AS.propInputs.PX.Text = tostring(R(pos.X))
	AS.propInputs.PY.Text = tostring(R(pos.Y))
	AS.propInputs.PZ.Text = tostring(R(pos.Z))
	AS.propInputs.RX.Text = tostring(R(math.deg(rx)))
	AS.propInputs.RY.Text = tostring(R(math.deg(ry)))
	AS.propInputs.RZ.Text = tostring(R(math.deg(rz)))
end

function ApplyTransformFromInputs()
	local name = Studio.SelectedObject
	if not name or not AS.propInputs then return end

	local px = tonumber(AS.propInputs.PX.Text) or 0
	local py = tonumber(AS.propInputs.PY.Text) or 0
	local pz = tonumber(AS.propInputs.PZ.Text) or 0
	local rx = math.rad(tonumber(AS.propInputs.RX.Text) or 0)
	local ry = math.rad(tonumber(AS.propInputs.RY.Text) or 0)
	local rz = math.rad(tonumber(AS.propInputs.RZ.Text) or 0)

	local cf = CFrame.new(px,py,pz) * CFrame.fromEulerAnglesXYZ(rx,ry,rz)

	-- Snap
	if Studio.SnapEnabled then
		local s = Studio.SnapMove
		px = math.round(px/s)*s; py = math.round(py/s)*s; pz = math.round(pz/s)*s
		local sr = math.rad(Studio.SnapRotate)
		rx = math.round(rx/sr)*sr; ry = math.round(ry/sr)*sr; rz = math.round(rz/sr)*sr
		cf = CFrame.new(px,py,pz) * CFrame.fromEulerAnglesXYZ(rx,ry,rz)
	end

	SetCFrameForBone(name, cf)

	-- Auto-insert keyframe at current frame
	local proj = Studio.CurrentProject
	if proj then
		if not proj.Animation[name] then proj.Animation[name] = {} end
		proj.Animation[name][Studio.CurrentFrame] = cf
		RefreshKeyframeRow(name)
	end
end

-- ═══════════════════════════════════════════════════════
--  CAMERA ORBIT
-- ═══════════════════════════════════════════════════════

function UpdateCameraOrbit()
	local rad = Studio.CamDist
	local ax   = math.rad(Studio.CamAngleX)
	local ay   = math.rad(Studio.CamAngleY)
	local offset = Vector3.new(
		rad * math.sin(ay) * math.cos(ax),
		rad * math.sin(ax),
		rad * math.cos(ay) * math.cos(ax)
	)
	Camera.CFrame = CFrame.lookAt(Studio.CamTarget + offset, Studio.CamTarget)
end

-- Mouse input for camera
UserInputService.InputBegan:Connect(function(inp, gpe)
	if gpe then return end
	if inp.UserInputType == Enum.UserInputType.MouseButton2 then
		Studio.CamDragging = true
		Studio.CamLastPos  = inp.Position
	end
end)

UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton2 then
		Studio.CamDragging = false
	end
end)

UserInputService.InputChanged:Connect(function(inp)
	if Studio.CamDragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = inp.Position - Studio.CamLastPos
		Studio.CamAngleY -= delta.X * 0.4
		Studio.CamAngleX = math.clamp(Studio.CamAngleX - delta.Y * 0.4, -80, 80)
		Studio.CamLastPos = inp.Position
		UpdateCameraOrbit()
	end
	if inp.UserInputType == Enum.UserInputType.MouseWheel then
		Studio.CamDist = math.clamp(Studio.CamDist - inp.Position.Z * 1.5, 3, 80)
		UpdateCameraOrbit()
	end
end)

-- ═══════════════════════════════════════════════════════
--  POSE LIBRARY
-- ═══════════════════════════════════════════════════════

function OpenSavePoseDialog()
	local existing = ScreenGui:FindFirstChild("PoseDialog")
	if existing then existing:Destroy() end

	local dialog = RoundFrame(ScreenGui,
		UDim2.new(0,300,0,160),
		UDim2.new(0.5,-150,0.5,-80),
		C.BG, 10)
	dialog.Name  = "PoseDialog"
	dialog.ZIndex = 200

	MakeLabel({Parent=dialog, Text="Save Pose", Size=UDim2.new(1,0,0,30),
		Position=UDim2.new(0,10,0,5), Font=Enum.Font.GothamBold, TextSize=14,
		TextXAlignment=Enum.TextXAlignment.Left})

	local nameInp = MakeInput({Parent=dialog, Size=UDim2.new(1,-20,0,32),
		Position=UDim2.new(0,10,0,40), PlaceholderText="Pose Name..."})
	Instance.new("UICorner",nameInp).CornerRadius=UDim.new(0,6)

	local btnSave = MakeButton({Parent=dialog, Size=UDim2.new(0.45,0,0,30),
		Position=UDim2.new(0,10,0,88), Text="💾 Save", BackgroundColor3=C.Success})
	Instance.new("UICorner",btnSave).CornerRadius=UDim.new(0,6)

	local btnCancel = MakeButton({Parent=dialog, Size=UDim2.new(0.45,0,0,30),
		Position=UDim2.new(0.55,-10,0,88), Text="Cancel", BackgroundColor3=C.Danger})
	Instance.new("UICorner",btnCancel).CornerRadius=UDim.new(0,6)

	btnSave.MouseButton1Click:Connect(function()
		local pname = nameInp.Text
		if pname == "" then return end
		-- Capture current pose of all bones
		local poseData = {}
		if SceneRig then
			for bname, _ in pairs(SceneRig) do
				poseData[bname] = GetCurrentCFrameForBone(bname)
			end
		end
		Studio.PoseLibrary[pname] = poseData
		dialog:Destroy()
	end)
	btnCancel.MouseButton1Click:Connect(function() dialog:Destroy() end)
end

-- Apply a pose from library
local function ApplyPose(poseName)
	local pose = Studio.PoseLibrary[poseName]
	if not pose then return end
	for bname, cf in pairs(pose) do
		SetCFrameForBone(bname, cf)
	end
	-- Record keyframes
	local proj = Studio.CurrentProject
	if proj then
		for bname, cf in pairs(pose) do
			if not proj.Animation[bname] then proj.Animation[bname] = {} end
			proj.Animation[bname][Studio.CurrentFrame] = cf
			RefreshKeyframeRow(bname)
		end
	end
end

-- ═══════════════════════════════════════════════════════
--  SOUND SYSTEM
-- ═══════════════════════════════════════════════════════

function PlaySoundEffect(soundId)
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxassetid://"..tostring(soundId)
	snd.Volume  = 1
	snd.Parent  = SoundService
	snd:Play()
	game:GetService("Debris"):AddItem(snd, 5)
end

local function OpenSoundDialog()
	local existing = ScreenGui:FindFirstChild("SoundDialog")
	if existing then existing:Destroy() end

	local dialog = RoundFrame(ScreenGui,
		UDim2.new(0,300,0,180),
		UDim2.new(0.5,-150,0.5,-90),
		C.BG, 10)
	dialog.Name = "SoundDialog"
	dialog.ZIndex = 200

	MakeLabel({Parent=dialog, Text="🔊 Add Sound Event", Size=UDim2.new(1,0,0,30),
		Position=UDim2.new(0,10,0,5), Font=Enum.Font.GothamBold, TextSize=14,
		TextXAlignment=Enum.TextXAlignment.Left})
	MakeLabel({Parent=dialog, Text="Frame: "..Studio.CurrentFrame, Size=UDim2.new(1,0,0,24),
		Position=UDim2.new(0,10,0,36), TextColor3=C.TextDim, TextSize=12,
		TextXAlignment=Enum.TextXAlignment.Left})

	local sndInp = MakeInput({Parent=dialog, Size=UDim2.new(1,-20,0,32),
		Position=UDim2.new(0,10,0,62), PlaceholderText="Sound Asset ID..."})
	Instance.new("UICorner",sndInp).CornerRadius=UDim.new(0,6)

	local btnAdd = MakeButton({Parent=dialog, Size=UDim2.new(0.45,0,0,30),
		Position=UDim2.new(0,10,0,106), Text="Add", BackgroundColor3=C.Success})
	Instance.new("UICorner",btnAdd).CornerRadius=UDim.new(0,6)
	local btnClose = MakeButton({Parent=dialog, Size=UDim2.new(0.45,0,0,30),
		Position=UDim2.new(0.55,-10,0,106), Text="Close", BackgroundColor3=C.Danger})
	Instance.new("UICorner",btnClose).CornerRadius=UDim.new(0,6)

	btnAdd.MouseButton1Click:Connect(function()
		local id = tonumber(sndInp.Text)
		if id then
			local proj = Studio.CurrentProject
			if proj then proj.SoundEvents[Studio.CurrentFrame] = id end
		end
		dialog:Destroy()
	end)
	btnClose.MouseButton1Click:Connect(function() dialog:Destroy() end)
end

-- ═══════════════════════════════════════════════════════
--  EXPORT DIALOG
-- ═══════════════════════════════════════════════════════

function OpenExportDialog()
	local existing = ScreenGui:FindFirstChild("ExportDialog")
	if existing then existing:Destroy() end

	local dialog = RoundFrame(ScreenGui,
		UDim2.new(0,400,0,320),
		UDim2.new(0.5,-200,0.5,-160),
		C.BG, 10)
	dialog.Name = "ExportDialog"
	dialog.ZIndex = 200

	MakeLabel({Parent=dialog, Text="📤 Export Animation", Size=UDim2.new(1,0,0,34),
		Position=UDim2.new(0,12,0,6), Font=Enum.Font.GothamBold, TextSize=16,
		TextXAlignment=Enum.TextXAlignment.Left})

	local proj = Studio.CurrentProject

	-- Summary
	local summary = [[
Project : ]] .. (proj and proj.Name or "-") .. [[

Rig     : ]] .. (proj and proj.Rig or "-") .. [[

FPS     : ]] .. (proj and tostring(proj.FPS) or "-") .. [[

Frames  : ]] .. (proj and tostring(proj.TotalFrames) or "-") .. [[

Bones   : ]] .. (proj and tostring(#(function() local t={} for k in pairs(proj.Animation) do table.insert(t,k) end return t end)()) or "0") .. [[


Export as:
  [Animation ID] — Upload to Roblox & get ID
  [Print Data]   — Print keyframe table to Output
  ]]

	local sumLbl = MakeLabel({Parent=dialog, Text=summary,
		Size=UDim2.new(1,-24,0,180), Position=UDim2.new(0,12,0,44),
		TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
		TextSize=12, TextColor3=C.TextDim, TextWrapped=true})

	local btnPrint = MakeButton({Parent=dialog, Size=UDim2.new(0.45,0,0,34),
		Position=UDim2.new(0,12,0,238), Text="🖨 Print Data", BackgroundColor3=C.Warning})
	Instance.new("UICorner",btnPrint).CornerRadius=UDim.new(0,6)

	local btnClose = MakeButton({Parent=dialog, Size=UDim2.new(0.45,0,0,34),
		Position=UDim2.new(0.55,-12,0,238), Text="Close", BackgroundColor3=C.Danger})
	Instance.new("UICorner",btnClose).CornerRadius=UDim.new(0,6)

	btnPrint.MouseButton1Click:Connect(function()
		if not proj then return end
		print("=== ANIMATION EXPORT: "..proj.Name.." ===")
		for bname, frames in pairs(proj.Animation) do
			for f, cf in pairs(frames) do
				print(string.format("  Bone: %-20s  Frame: %3d  CFrame: %s", bname, f, tostring(cf)))
			end
		end
		print("=== END ===")
	end)

	btnClose.MouseButton1Click:Connect(function() dialog:Destroy() end)
end

-- ═══════════════════════════════════════════════════════
--  SAVE / LOAD (DataStore bridge via RemoteEvent)
-- ═══════════════════════════════════════════════════════

-- The actual DataStore persistence happens server-side.
-- This client communicates via RemoteEvents.

local RemoteFolder = ReplicatedStorage:FindFirstChild("AnimStudioRemotes")
if not RemoteFolder then
	RemoteFolder = Instance.new("Folder")
	RemoteFolder.Name   = "AnimStudioRemotes"
	RemoteFolder.Parent = ReplicatedStorage
end

local function GetOrCreateRemote(name, class)
	local r = RemoteFolder:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name   = name
		r.Parent = RemoteFolder
	end
	return r
end

local SaveEvent = GetOrCreateRemote("SaveProject",   "RemoteEvent")
local LoadEvent = GetOrCreateRemote("LoadProject",   "RemoteEvent")
local LoadBack  = GetOrCreateRemote("LoadedProject", "RemoteEvent")

function SaveProject()
	local proj = Studio.CurrentProject
	if not proj then return end

	-- Serialise CFrames to table
	local serialised = {
		Name        = proj.Name,
		Rig         = proj.Rig,
		FPS         = proj.FPS,
		Map         = proj.Map,
		TotalFrames = proj.TotalFrames,
		Layers      = proj.Layers,
		Objects     = proj.Objects,
		SoundEvents = proj.SoundEvents,
		Animation   = {},
	}
	for bname, frames in pairs(proj.Animation) do
		serialised.Animation[bname] = {}
		for f, cf in pairs(frames) do
			local pos = cf.Position
			local rx,ry,rz = cf:ToEulerAnglesXYZ()
			serialised.Animation[bname][tostring(f)] = {
				px=pos.X, py=pos.Y, pz=pos.Z,
				rx=rx,    ry=ry,    rz=rz,
			}
		end
	end

	SaveEvent:FireServer(serialised)
	print("[AnimStudio] Project saved: "..proj.Name)
end

LoadBack.OnClientEvent:Connect(function(data)
	if not data then return end
	-- Deserialise
	local proj = {
		Name        = data.Name,
		Rig         = data.Rig,
		FPS         = data.FPS,
		Map         = data.Map,
		TotalFrames = data.TotalFrames,
		Layers      = data.Layers,
		Objects     = data.Objects or {},
		SoundEvents = data.SoundEvents or {},
		Animation   = {},
	}
	for bname, frames in pairs(data.Animation or {}) do
		proj.Animation[bname] = {}
		for fStr, d in pairs(frames) do
			local f = tonumber(fStr)
			proj.Animation[bname][f] = CFrame.new(d.px,d.py,d.pz) *
			                           CFrame.fromEulerAnglesXYZ(d.rx,d.ry,d.rz)
		end
	end
	Studio.Projects[proj.Name] = proj
	print("[AnimStudio] Project loaded: "..proj.Name)
end)

-- ═══════════════════════════════════════════════════════
--  KEYBOARD SHORTCUTS
-- ═══════════════════════════════════════════════════════

UserInputService.InputBegan:Connect(function(inp, gpe)
	if gpe then return end
	if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local key = inp.KeyCode

	-- Space = Play/Pause
	if key == Enum.KeyCode.Space then
		if Studio.IsPlaying then StopPlayback() else StartPlayback() end

	-- Arrow Left/Right = prev/next frame
	elseif key == Enum.KeyCode.Left then
		if Studio.CurrentFrame > 1 then Studio.CurrentFrame -= 1; UpdateFrame() end
	elseif key == Enum.KeyCode.Right then
		if Studio.CurrentFrame < Studio.TotalFrames then Studio.CurrentFrame += 1; UpdateFrame() end

	-- K = set keyframe on selected bone
	elseif key == Enum.KeyCode.K then
		if Studio.SelectedBone then
			ToggleKeyframe(Studio.SelectedBone, Studio.CurrentFrame)
		end

	-- W/E/R = gizmo modes
	elseif key == Enum.KeyCode.W then Studio.GizmoMode = "Move"
	elseif key == Enum.KeyCode.E then Studio.GizmoMode = "Rotate"
	elseif key == Enum.KeyCode.R then Studio.GizmoMode = "Scale"

	-- S = Sound dialog
	elseif key == Enum.KeyCode.U then OpenSoundDialog()
	end
end)

-- ═══════════════════════════════════════════════════════
--  WIRE UP OBJECT / RIG ADD BUTTONS  (deferred)
-- ═══════════════════════════════════════════════════════

local function WireAddButtons()
	local win = ScreenGui:FindFirstChild("StudioWindow")
	if not win then return end
	local objPanel = win:FindFirstChild("Frame") -- first frame child = objPanel (by position)
	-- Find by iterating
	for _, child in ipairs(win:GetChildren()) do
		if child:IsA("Frame") then
			local addObjBtn = child:FindFirstChild("TextButton")
			-- Use the stored refs instead
		end
	end
end

-- ═══════════════════════════════════════════════════════
--  STARTUP
-- ═══════════════════════════════════════════════════════

BuildProjectManager()

-- Add demo project
Studio.Projects["Demo_Punch"] = {
	Name        = "Demo_Punch",
	Rig         = "R15",
	FPS         = 24,
	Map         = "Studio Map",
	TotalFrames = 30,
	Layers      = {"Character","Weapon","Effects","Camera"},
	Objects     = {},
	SoundEvents = {[10] = 0},   -- Punch sound at frame 10
	Animation   = {},
}

print([[
╔══════════════════════════════════════════════════╗
║    🎬 Animation Studio Loaded Successfully!     ║
╠══════════════════════════════════════════════════╣
║  SHORTCUTS:                                      ║
║   Space      = Play / Pause                      ║
║   ← →        = Prev / Next Frame                 ║
║   K          = Set Keyframe on selected bone     ║
║   W          = Move Gizmo                        ║
║   E          = Rotate Gizmo                      ║
║   R          = Scale Gizmo                       ║
║   U          = Add Sound Event                   ║
║   Right-drag = Orbit Camera                      ║
║   Scroll     = Zoom Camera                       ║
╚══════════════════════════════════════════════════╝
]])

-- ═══════════════════════════════════════════════════════
--  SERVER SCRIPT  (copy to ServerScriptService)
-- ═══════════════════════════════════════════════════════
--[[
============================================================
SERVER SCRIPT  —  AnimationStudioServer
Place in: ServerScriptService
============================================================

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DS = DataStoreService:GetDataStore("AnimStudio_v1")

local RemoteFolder = ReplicatedStorage:WaitForChild("AnimStudioRemotes")
local SaveEvent    = RemoteFolder:WaitForChild("SaveProject")
local LoadEvent    = RemoteFolder:WaitForChild("LoadProject")
local LoadBack     = RemoteFolder:WaitForChild("LoadedProject")

-- Save project
SaveEvent.OnServerEvent:Connect(function(player, projectData)
    local key = player.UserId.."_"..projectData.Name
    local success, err = pcall(function()
        DS:SetAsync(key, projectData)
    end)
    if not success then
        warn("[AnimStudio] Save failed: "..tostring(err))
    else
        print("[AnimStudio] Saved project '"..projectData.Name.."' for "..player.Name)
    end
end)

-- Load project
LoadEvent.OnServerEvent:Connect(function(player, projectName)
    local key = player.UserId.."_"..projectName
    local success, data = pcall(function()
        return DS:GetAsync(key)
    end)
    if success and data then
        LoadBack:FireClient(player, data)
    else
        warn("[AnimStudio] Load failed for: "..tostring(projectName))
    end
end)

-- Auto-load all projects on join
Players.PlayerAdded:Connect(function(player)
    -- You could load a list of project names here
end)
============================================================
--]]
