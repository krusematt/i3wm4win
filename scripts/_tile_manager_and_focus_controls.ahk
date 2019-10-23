#SingleInstance force
;~ OutputDebug DBGVIEWCLEAR

;GoSub, ConfigMinimizeToTray
DetectHiddenWindows, On
 

;DllCall("EnumDisplayMonitors", "ptr", 0, "ptr", 0, "ptr", RegisterCallback("MonitorEnumProc", "", 4), "uint", 0)

;MonitorEnumProc(hMonitor, hdcMonitor, lprcMonitor, dwData) {
;	MsgBox % "Left: " . NumGet(lprcMonitor+0, 0, "int") . " -- "
;		. "Top: " . NumGet(lprcMonitor+0, 4, "int") . " -- " 
;		. "Right: " . NumGet(lprcMonitor+0, 8, "int") . " -- " 
;		. "Bottom: " . NumGet(lprcMonitor+0, 12, "int")
;	return 1
;}









; explicitly set the monitor locations, top, right, bottom, left relative to the monitor ID.
; this will be used for window focus and moving windows from one monitor to another.
monitorNeighbors := {1: {l:3}, 2:{b:3}, 3:{t:2, r:1}}

monitorScale := {1: 1 ,2: 0.75, 3: 0.75}
monitorOffset := {3: {x:-8,y:0,w:0, h:0, l:1,r:0,t:0,b:0},  1: {x:0,y:0,w:0, h:0, l:10,r:-10,t:0,b:0} }  ; offset to be applied to the tiles coords when moving.  this addresses the issue of scaling windows.  If a window's edge is next to a monitor with different DPI scaling, the monitor with larger scaling will be applied to the window.
forceScaleOnMonitors := 0.75  ; testing this.  we have some wonky behavior to address.


global sqas := new SquAeroSnap()
;return

;~ ^Esc::
;GuiClose:
;ExitApp
; ========================= Concepts used in this code ================================

; == Axes, Vectors and Edges ==
; Moving occurs along an axis
;	If you hit left or right, thats a move along the x axis
;	If you hit up/down, that's that's a move along the y axis
; Movement is in the direction of a vector
;	-1 is towards the origin, so left or up
;	+1 is away from the origin, so right or down
;
; Resizing operates upon an edge, along an axis in the direction of a vector.
; eg the right edge moves to the right, sizing up the window horizontally
; = +1 edge of x axis moves in vector +1
; It is initiated by holding an additional modifier when you press an arrow key

; === Monitor Index (ID) and Order ===
; AHK gives each monitor an Index (Starting with 1, counting up)
; These Indexes however are not guaranteed to be in the same order as they are physically arranged
; Monitor "Order" is the physical order they are arranged in (1 being the left-most)

; === Pos and Span ===
; A given window has Pos and Span attributes for each axis
; Pos is the position of the winow along that axis: 1 is the left/top-most tile
; Span is how many tiles that window covers along that axis

class SquAeroSnap {
    MonitorOrder := []
	MonitorRows := 2
	MonitorCols := 2
    Monitors := []
    TiledWindows := {}
	IgnoreFirstMove := 0
	ForceMonitorCoords := 0
	
	Axes := {x: 1, y: 2}
	AxisToWh := {x: "w", y: "h"}
    
    __New(){
		global monitorNeighbors
		this.monitorNeighbors := monitorNeighbors
		this.IniFile := RegExReplace(A_ScriptName, "\.exe|\.ahk", ".ini")

        Gui, +hwndhwnd
        this.hwnd := hwnd

		this.InitializeDLL()
		; === Gui ===
		;Gui, Add, GroupBox, w250 h75 Center Section, General Settings

		; -- Rows --
		;Gui, Add, Text, xs+20 yp+25 w50, Rows
		;Gui, Add, Edit, x+5 yp-3 w40 hwndhRowsEdit
		;this.hRowsEdit := hRowsEdit
        
		; -- Columns --
		;Gui, Add, Text, x+20 yp+3 w50, Columns
		;Gui, Add, Edit, x+5 yp-3 w40 hwndhColsEdit
		;this.hColsEdit := hColsEdit

		; -- Ignore first move --
		;Gui, Add, CheckBox, % "xs+20 y+10 hwndhIgnoreFirstmove AltSubmit", Ignore first move or size, just snap to tile(s)
		;this.hIgnoreFirstmove := hIgnoreFirstmove
		
		; -- Instructions --
		;Gui, Add, GroupBox, xm y+20 w250 h140 Center, Hotkeys
		;Gui, Add, Text, xp+1 yp+25 w245 R8 hwndhHotkeyInstructions Center
		;this.hHotkeyInstructions := hHotkeyInstructions
		
		; === Initialize Monitors ===
        SysGet, MonitorCount, MonitorCount
        this.MonitorCount := MonitorCount
        
        Loop % this.MonitorCount {
            this.Monitors.push(new this.CMonitor(A_Index))
        }
		MsgBox % JSON.dump(this.Monitors)

        if (this.MonitorOrder.length() != this.MonitorCount){
			this.SetupMonitorLayout()
        }
		this.UpdateMonitorTileConfiguration()
		
		; === Load Settings ===
		settings_loaded := this.LoadSettings()
		;Gui, Show, Hide, SquAeroSnap

		; === Minimze to tray if not first run, else show Gui ===
		if (!settings_loaded){
			;GoSub, OnMinimizeButton
		} else {
			;Gui, Show
		}
		;MsgBox Initializing ALL windows.
		this.InitializeAllWindows()
		; === Enable GuiControl Callbacks ===
		;this.SetGuiControlCallbackState(1)
    }
	
	
	InitializeDLL() {
		MajorVersion := DllCall("GetVersion") & 0xFF                ; 10
		MinorVersion := DllCall("GetVersion") >> 8 & 0xFF           ; 0
		BuildNumber  := DllCall("GetVersion") >> 16 & 0xFFFF        ; 10532
		;MsgBox % "MajorVersion:`t" MajorVersion "`n" "MinorVersion:`t" MinorVersion "`n" "BuildNumber:`t"  BuildNumber "`n" "dir:" A_ScriptDir
		;  load the correct DLL based on the version of windows.  i.e.  < 1803 vs  > 1803    different lib required.
		if (BuildNumber <= 17134) {
			this.hVirtualDesktopAccessor := DllCall("LoadLibrary", Str, A_ScriptDir . "\dll\VirtualDesktopAccessor_1803_and_lower.dll", "Ptr") 
		}
		if (BuildNumber > 17134) {
			this.hVirtualDesktopAccessor := DllCall("LoadLibrary", Str, A_ScriptDir . "\dll\VirtualDesktopAccessor_1809_and_above.dll", "Ptr") 
		}
		
		this.GoToDesktopNumberProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "GoToDesktopNumber", "Ptr")
		this.GetCurrentDesktopNumberProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "GetCurrentDesktopNumber", "Ptr")
		this.GetWindowDesktopIdProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "GetWindowDesktopId", "Ptr")
		this.GetWindowDesktopNumberProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "GetWindowDesktopNumber", "Ptr")
		this.IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "IsWindowOnCurrentVirtualDesktop", "Ptr")
		this.MoveWindowToDesktopNumberProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "MoveWindowToDesktopNumber", "Ptr")
		this.RegisterPostMessageHookProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "RegisterPostMessageHook", "Ptr")
		this.UnregisterPostMessageHookProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "UnregisterPostMessageHook", "Ptr")
		this.IsPinnedWindowProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "IsPinnedWindow", "Ptr")
		this.RestartVirtualDesktopAccessorProc := DllCall("GetProcAddress", Ptr, this.hVirtualDesktopAccessor, AStr, "RestartVirtualDesktopAccessor", "Ptr")
		; GetWindowDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GetWindowDesktopNumber", "Ptr")
				
	}
	
	; --------------------------------- Inital Setup -------------------------------
	LoadSettings(){
		hotkey_mode := 1
		if (FileExist(this.IniFile)){
			first_run := 0
		} else {
			first_run := 1
			FileAppend, % "", % this.IniFile
		}
		if (!first_run){
			IniRead, MonitorRows, % this.IniFile, Settings, MonitorRows
			if (MonitorRows != "ERROR"){
				this.MonitorRows := MonitorRows
			}
			IniRead, MonitorCols, % this.IniFile, Settings, MonitorCols
			if (MonitorCols != "ERROR"){
				this.MonitorCols := MonitorCols
			}
			IniRead, IgnoreFirstMove, % this.IniFile, Settings, IgnoreFirstMove
			if (IgnoreFirstMove != "ERROR"){
				this.IgnoreFirstMove := IgnoreFirstMove
			}
		}
		
		; Initialize hotkeys
		this.SetHotkeyState()
		
		; Update the GuiControls
		;GuiControl, , % this.hRowsEdit, % this.MonitorRows
		;GuiControl, , % this.hColsEdit, % this.MonitorCols
		;GuiControl, , % this.hIgnoreFirstmove, % this.IgnoreFirstMove
		
		return first_run
	}
	
	; Turns On or Off hotkeys, or sets the mode
    SetHotkeyState(){
		
		; focus
		fn := this.FocusWindow.Bind(this, "x", 1)
		hotkey, <!;, % fn
		
		fn := this.FocusWindow.Bind(this, "x", -1)
		hotkey, <!j, % fn
		
		fn := this.FocusWindow.Bind(this, "y", 1)
		hotkey, <!k, % fn
		
		fn := this.FocusWindow.Bind(this, "y", -1)
		hotkey, <!l, % fn
		
		
		; move window
		fn := this.MoveWindow.Bind(this, "x", 1)
		hotkey, +<!;, % fn
		
		fn := this.MoveWindow.Bind(this, "x", -1)
		hotkey, +<!j, % fn
		
		fn := this.MoveWindow.Bind(this, "y", 1)
		hotkey, +<!k, % fn
		
		fn := this.MoveWindow.Bind(this, "y", -1)
		hotkey, +<!l, % fn



		; fullscreen
		fn := this.FullScreenWindow.Bind(this)
		hotkey, <!f, % fn
		
		
		fn := this.SizeWindow.Bind(this, "x", -1, -1)
		hotkey, <!^j, % fn
		
		fn := this.SizeWindow.Bind(this, "y", -1, -1)
		hotkey, <!^k, % fn
		
		fn := this.SizeWindow.Bind(this, "y", 1, 1)
		hotkey, <!^l, % fn
		
		fn := this.SizeWindow.Bind(this, "x", 1, 1)
		hotkey, <!^;, % fn
		
		;fn := this.SizeWindow.Bind(this, "y", 1, 1)
		;hotkey, <!^k, % fn
		
		;fn := this.SizeWindow.Bind(this, "y", 1, -1)
		;hotkey, <!^l, % fn
		
		;fn := this.SizeWindow.Bind(this, "y", -1, 1)
		;hotkey, <!+k, % fn
		
		;fn := this.SizeWindow.Bind(this, "y", -1, -1)
		;hotkey, <!+l, % fn
		
		fn := this.debugVisibleWindows.Bind(this)
		hotkey, <!g, % fn
		
		
		fn := this.ReInitActiveWindow.Bind(this)
		hotkey, +<!t, % fn
		
		this.SetHotkeyInstructions()
    }
	
	; Updates the Gui to show hotkeys
	SetHotkeyInstructions(){
		text =
		(
Base modifier of WIN to Move
Add Ctrl to Resize bottom right corner
Add Shift to Resize top left corner

WIN + Arrow Keys = Move Window
WIN + CTRL + Up/Down = Resize bottom edge
WIN + CTRL + Left/Right = Resize right edge
WIN + SHIFT + Up/Down = Resize top edge
WIN + SHIFT + Left/Right = Resize left edge
		)
		
		text =
		(
Base modifier of LALT to Move
;Add Ctrl to Resize bottom right corner
;Add Shift to Resize top left corner

LALT + SHIFT + Arrow Keys = Move Window
LALT + SHIFT  + CTRL + Up/Down = Resize bottom edge
LALT + SHIFT  + CTRL + Left/Right = Resize right edge
LALT + SHIFT + Up/Down = Resize top edge
LALT + SHIFT + Left/Right = Resize left edge
		)
		;GuiControl, , % this.hHotkeyInstructions, % text
	}
    
	; Called on startup to work out physical layout of monitors
    SetupMonitorLayout(){
		tmp := {}
		for i, mon in this.Monitors {
			tmp[mon.Coords.l] := i
		}
		for i, id in tmp {
			this.MonitorOrder.push(id)
		}
	}
	
	; Instruct all monitors to pre-calculate their tile locations
	UpdateMonitorTileConfiguration(){
		for i, mon in this.Monitors {
			mon.SetRows(this.MonitorRows)
			mon.SetCols(this.MonitorCols)
		}
	}
	
	; ------------------------------- Window placement, movement and sizing ------------------------------
	; Called when a hotkey is hit to detect the current window
    GetWindow(){
        hwnd := WinExist("A")
        if (this.TiledWindows.HasKey(hwnd)){
			; init every time.
			win := this.TiledWindows[hwnd]
		} else {
			win := new this.CWindow(hwnd)
			this.InitWindow(win)
        }
        return win
    }
	
	GetWindowByHwnd(hwnd) {
		if (this.TiledWindows.HasKey(hwnd)){
			win := this.TiledWindows[hwnd]
		} else {
			win := new this.CWindow(hwnd)
        }
        return win
	}

	; Initializes a window if needed.
	; Returns 1 to indicate that the window is new
	InitWindow(win, force:=false){
		;MsgBox % JSON.dump(win)
        if (this.TiledWindows.HasKey(win.hwnd) && !force){
			return 0
		} else {
            this.TiledWindows[win.hwnd] := win
			win.CurrentMonitor := this.Monitors[this.GetWindowMonitor(win)]
			if(!win.CurrentMonitor) {
				; lets default monitor 1!
				;win.CurrentMonitor := this.Monitors[1]
			}
			; this.FitWindowToTiles(win)  ; do not fit to window tiles on init.. only fit when moving the window around.
			return 1
		}
	}
	
	; Works out initial placement for a window
	FitWindowToTiles(win){
		mon := win.CurrentMonitor
		coords := win.GetLocalCoords()

		Axes := {x: 1, y: 2}
		AxisToWh := {x: "w", y: "h"}
    

		for axis, unused in this.Axes {
			w_h := this.AxisToWh[axis] ; convert "x" or "y" to "w" or "h"
			; Work out initial position
			tile_pos := floor(coords[axis] / mon.TileSizes[axis]) + 1
			win.Pos[axis] := tile_pos
			
			; Work out how many tiles this window would fill if tiled
			num_tiles := floor(coords[w_h] / mon.TileSizes[axis])
			num_tiles := num_tiles ? num_tiles : 1	; minimum tile size of 1
			win.Span[axis] := num_tiles
			
			; Clamp window to max of full width of the axis
			if (win.Span[axis] > mon.TileCount[axis]){
				win.Span[axis] := mon.TileCount[axis]
			}
			
			; If window would extend off-screen on this axis, move it towards the origin
			sizediff := ((win.Pos[axis] + win.Span[axis]) - mon.TileCount[axis]) - 1
			if (sizediff > 0){
				win.Pos[axis] -= sizediff
			}
		}
		this.TileWindow(win)
	}
	
	; Moves a window along a specified axis in the direction of a specified vector
    MoveWindow(axis, vector){
		oaxis := axis == "x" ? "y" : "x"
		;MsgBox % oaxis

        win := this.GetWindow()
		; must set the current monitor before movement. it's possible to pick up the window and move it manually before retiling.
		; i.e. reinit the window every time.
		this.InitWindow(win, true)

		;if (this.InitWindow(win) && this.IgnoreFirstMove){
			;return
		;}
		mon := win.CurrentMonitor
		;MsgBox % JSON.dump(win)
		;MsgBox % JSON.dump(mon)
		
		new_pos := win.Pos[axis] + vector
		; --- quick hack to allow for either vertical split or horizontal split.
		; --- upcoming refactor will have more robust window tiling management.
		; --- 
		; --- making a quick hack to get a functional MVP.
		; --- when attempting to move window
		;MsgBox % JSON.dump(new_pos)
		if ((new_pos + win.Span[axis] - 1) > mon.TileCount[axis]){
			; moving beyond axis ++
			;if (axis == "y")
				;return
			
			; must check if monitor is full span before pusing to next monitor.
			; if not, resize window to full span across axis.
			;if(win.Span[axis] != )
			
			if(win.Span[axis] == mon.TileCount[axis]) {
				win.Span[axis] --
				;new_pos := win.Pos[axis]
			
			} else if (win.Span[oaxis] != mon["TileCount"][oaxis]) {
				;
				; -- 
				;
				win.Span[oaxis] := mon["TileCount"][oaxis]
				win.Pos[oaxis] := 1
				new_pos := win.Pos[axis]
			} else {
				new_pos := 1
				mon := this.GetNextMonitor(mon.id, axis, vector)
				;MsgBox % "changing monitors from ID: " win.CurrentMonitor.ID  "    To ID: " mon.ID
				win.CurrentMonitor := mon
			}
		} else if (new_pos <= 0){
			; moving beyond axis --
			;if (axis == "y")
				;return
				
				; if moving along the y axis with full span, reduce to single span.
				
			if(win.Span[axis] == mon.TileCount[axis]) {
				win.Span[axis] --
				new_pos := win.Pos[axis]
			
			} else if (win.Span[oaxis] != mon["TileCount"][oaxis]) {
				;
				; -- 
				;
				win.Span[oaxis] := mon["TileCount"][oaxis]
				win.Pos[oaxis] := 1
				new_pos := win.Pos[axis]
			} else if (win.Span[axis] == mon["TileCount"][axis]) {
				win.Span[oaxis] --
				now_pos := win.Pos[axis]
			} else {
				mon := this.GetNextMonitor(mon.id, axis, vector)
				;MsgBox % "changing monitors from ID: " win.CurrentMonitor.ID  "    To ID: " mon.ID

				win.CurrentMonitor := mon
				new_pos := (mon.TileCount[axis] - win.Span[axis]) + (vector * -1)
			}
		}
        Win.Pos[axis] := new_pos
		if(win.Span[axis] == "" || !win.Span[axis] || win.Span.axis[axis] == 0) {
			win.Span[axis] := 1
		}
		if(win.Span[oaxis] == "" || !win.Span[oaxis] || win.Span.axis[oaxis] == 0) {
			win.Span[oaxis] := 1
		}
        this.TileWindow(win)
    }
	
	FocusWindow(axis, vector, mon := false, loop_count := 0) {
		position:=0
		oaxis := axis == "x" ? "y" : "x"
		
		x1=x1
		x2=x2
		y1=y1
		y2=y2
		
		
		
		
        win := this.GetWindow()
		if(!win) {
			; no window focused.  todo: fix this.
			MsgBox No Window Focused.
			return
		}
		
		;MsgBox % JSON.dump(mon)
		move_mouse := false
		if(mon) {
			move_mouse := true
		}
		
		; check if window is on same monitor as mouse
		; if not change coords to move from.
		if(win.CurrentMonitor.ID != this.GetMouseMonitor() && !move_mouse) {
			;MsgBox % "active window monitor != cursor monitor"
			mon := this.Monitors[this.GetMouseMonitor()]
			position := this.GetMouseCoords()
		} else {
			if(move_mouse) {
				; we're moving to a different monitor.
				; nothing to do, leave monitor set to what is provided.
				; will perform closest neighbor lookup for focus.
			} else {
				mon := win.CurrentMonitor   ; this will be problematic,  don't assume momnitor will be the same.
			}
			;win.c := win.GetCenter()
			position := win.GetCenter()
		}
		
		;MsgBox % "moving from: " JSON.dump(position)
		;MsgBox % JSON.dump(mon)



		


		;if (this.InitWindow(win) && this.IgnoreFirstMove){
			;return
		;}
		;c := win.GetCenter()
		threshold := 50 ; number of pixels in x or y to qualify as same centerpoint.
		;threshold_range
		tr := { x1 : position["x"]-threshold, x2: position["x"]+threshold, y1:position["y"]-threshold, y2:position["y"]+threshold }
		
		focus_window := false
		
		
		;MsgBox % JSON.dump(win)
		;MsgBox % JSON.dump(mon)
		stacked_windows := []
		has_stacked_window := false ; AHK doesn't have a simple way to check if this list is empty =?
		;windows_on_center := []
		; GET ALL WINDOWS 
		
		; tie-breaking rules.
		; if centers of two or more windows are equal.  cycle through them by hardware id via vector until out of range.
		; allow for a radial|square target zone to qualify windows as equal center eg: +-50px either axis.
		
		; check if we need to switch monitors in relation to axis and vector.
		;MsgBox % JSON.dump(this.TiledWindows)
		has_windows := false
		this.InitializeAllWindows()
		monitor_window_count:= {}
		for win_hwnd, w in this.TiledWindows {
			; must check if this window is on the same virtual desktop.
			if (!w.IsOnCurrentDesktop(this.IsWindowOnCurrentVirtualDesktopProc)) { 
				continue
			}
			has_windows := true
			if(!monitor_window_count.HasKey(mon.ID)) {
				monitor_window_count[mon.ID] = 0
			}
			monitor_window_count[mon.ID] ++
			;MsgBox % JSON.dump(w)
				if (w.CurrentMonitor.ID == mon.ID &&  w.hwnd != win.hwnd) { 
					; filter list down only whats eligible for focus.
					w.c := w.GetCenter()
					;MsgBox % win.hwnd " ---- " w.hwnd 

					
					
					
					;first check for center match.
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					if(w.c[axis] >= tr[%axis%1] && w.c[axis] <= tr[%axis%2] && w.c[oaxis] >= tr[%oaxis%1] && w.c[oaxis] <= tr[%oaxis%2] && w.hwnd < win.hwnd && vector < 0) {
						stacked_windows.push(win)
						has_stacked_window := true
						;MsgBox % "vector --" tr[%axis%1]
						continue
					}
					if(w.c[axis] >= tr[%axis%1] && w.c[axis] <= tr[%axis%2] && w.c[oaxis] >= tr[%oaxis%1] && w.c[oaxis] <= tr[%oaxis%2] && w.hwnd > win.hwnd && vector > 0) {
						stacked_windows.push(win)
						has_stacked_window := true
						;MsgBox % "vector ++" tr[%axis%1]
						continue
					}
					;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
					
					
					;
					; now check if window is in path of vector.
					; and obtain the distance to each window.
					if(!has_stacked_window) {
						if(vector > 0) {
							; vector ++  going down, or right.
							if (loop_count > 0) {
								;MsgBox % "w.c: " JSON.dump(w.c) "     win.c: " JSON.dump(win.c)
							}
							if(w.c[axis] > win.c[axis]) {
								; determine distance
								w.distance := abs(w.c[axis] - win.c[axis]) + abs(w.c[oaxis] - win.c[oaxis])
								;windows.push(w)
								if(!focus_window) {
									; assign the first window as first to focus.
									focus_window := w
								} else if (w.distance < focus_window.distance) {
									focus_window := w
								}
							}
							
								
						} else {
							; vector --  going up or left
							if(w.c[axis] < win.c[axis]) {
								; determine distance
								w.distance := abs(w.c[axis] - win.c[axis]) + abs(w.c[oaxis] - win.c[oaxis])
								;windows.push(w)
								if(!focus_window) {
									; assign the first window as first to focus.
									focus_window := w
								} else if (w.distance < focus_window.distance) {
									focus_window := w
								}
							}
						}
					}
					;if(w.c[axis] )
					
					
					; now check of windows following the vector
				}
				
			
		}
		;MsgBox % JSON.dump(focus_window)
		
		if(!has_windows) {
			; move cursor to this monitor's center.
			mon := this.GetNextMonitor(mon.id, axis, vector)

			DllCall("SetCursorPos", int, mon.Coords.cx, int, mon.Coords.cy)

			;MsgBox % "Next Mon      " JSON.dump(mon)
			; we have to check if there are any windows on this monitor,
			; if not, set 
			loop_count ++
			if(loop_count < 3) {
				this.FocusWindow(axis, vector, mon, loop_count)
			} else {
				;MsgBox Error focusing to different window, try a different direction.
			}
			return
		}
		
		if(has_stacked_window) {
			focus_window = false
			for key, win in stacked_windows {
				; windows is a list of 
				if(!focus_window) {
					focus_window := win
				} else {
					if(vector > 0 && win.hwnd > focus_window.hwnd) {
						focus_window := win
					} else if (vector < 0 && win.hwnd < focus_window.hwnd) {
						focus_window := win
					}
				}
				
			}
		}
			
		; MsgBox % JSON.dump(windows)
		;MsgBox % JSON.dump(focus_window)
		if(focus_window) {
			;move the mouse.
			if(move_mouse) {
				;MsgBox % JSON.dump(mon)
				;MsgBox % "moving mouse   "  mon.cx "  y:  " mon.cy
				DllCall("SetCursorPos", int, focus_window.c.x, int, focus_window.c.y)
				;MouseMove mon.cx, mon.cy
				;mousemove, mon.cx, mon.cy
			}
			DllCall( "FlashWindow", UInt, focus_window.hwnd, Int,True )
			WinActivate, % "ahk_id " focus_window.hwnd
			
		} else if (move_mouse) { 
				DllCall("SetCursorPos", int, mon.Coords.cx, int, mon.Coords.cy)

		} else {
			; todo
			; add focus to next monitor.
			;MsgBox running again
			;MsgBox % JSON.dump(win)
			
			
			mon := this.GetNextMonitor(mon.id, axis, vector)

			DllCall("SetCursorPos", int, mon.Coords.cx, int, mon.Coords.cy)

			;MsgBox % "Next Mon      " JSON.dump(mon)
			; we have to check if there are any windows on this monitor,
			; if not, set 
			loop_count ++
			if(loop_count < 3) {
				this.FocusWindow(axis, vector, mon, loop_count)
			} else {
				;MsgBox Error focusing to different window, try a different direction.
			}
			
		}

	}
	
	
	;
	;
	; @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;
	; Moves a window along a specified axis in the direction of a specified vector
	ReInitActiveWindow() {
			win := this.getWindow()
			this.InitWindow(win, true)
	}
	
	
    FullScreenWindow(){
        win := this.GetWindow()
		
		;if (this.InitWindow(win) && this.IgnoreFirstMove){
			;return
		;}
		
		mon := win.CurrentMonitor
		;MsgBox % JSON.dump(win.hwnd)
		
		;MsgBox % JSON.dump(this.Monitors)
		
		;this.Monitors[win.CurrentMonitor]
		;Window_move(win.hwnd, x, y, width, height)
		;MsgBox % win.hwnd
		;new_pos := win.Pos[axis] + vector
		;Window_move(win.hwnd, this.Monitors[win.CurrentMonitor]["t"], this.Monitors[win.CurrentMonitor]["l"], this.Monitors[win.CurrentMonitor]["w"], this.Monitors[win.CurrentMonitor]["h"])
		
		WinGet, MinMax, MinMax, % "ahk_id " win.hwnd
		if (MinMax == 1) {
			;MsgBox % JSON.dump(win)
			WinRestore, % "ahk_id " win.hwnd
			; todo: Add logic to move window back to its tile postion.
		} else {
			WinMaximize, % "ahk_id " win.hwnd
		}
		
    }
    
	; Sizes a window by moving and edge along a specific axis in the direction of a specified vector
    SizeWindow(axis, edge, vector){
        win := this.GetWindow()
		
		if (this.InitWindow(win) && this.IgnoreFirstMove){
			return
		}

		mon := win.CurrentMonitor
		
		new_pos := win.Pos[axis], new_span := win.Span[axis]
		
		if (edge == -1){ ; moving left
			; Change in span causes change in pos
			if ((vector == 1 && win.Span[axis] != 1) || (vector == -1 && win.Pos[axis] != 1)){
				new_span += (vector * -1)
				new_pos += vector
			}
		} else { ; moving right
			new_span += (vector * edge)
		}
		if ((new_span == 0) || ((new_pos + new_span - 1) > mon.TileCount[axis])){
			return
		}
       
		;~ OutputDebug % "AHK| SIZE - Axis: " axis ", Edge: " edge ", Vector: " vector " / New Span: " new_span ", New Pos: " new_pos
		
		win.Span[axis] := new_span, win.Pos[axis] := new_pos
		
        this.TileWindow(win)
    }
	
	; Request a window be placed in its designated tile
	TileWindow(win) {
        mon := win.CurrentMonitor
		;  if current monitor has a scale, adjust accordingly.
		x := mon.TileCoords.x[win.Pos.x] * mon.Scale
		y := mon.TileCoords.y[win.Pos.y] * mon.Scale
		w := (mon.TileSizes.x * win.Span.x) * mon.Scale
		h := (mon.TileSizes.y * win.Span.y) * mon.Scale
		
		
		; If window is minimized or maximized, restore
		WinGet, MinMax, MinMax, % "ahk_id " win.hwnd
		if (MinMax != 0)
			WinRestore, % "ahk_id " win.hwnd

		;~ WinMove, % "ahk_id " win.hwnd, , x, y, w, h
		Window_move(win.hwnd, x, y, w, h)
		;~ OutputDebug % "AHK| Window Tile - PosX: " win.Pos.x ", PosY: " win.Pos.y ", SpanCols: " win.Span.x ", SpanRows: " win.Span.y
		;~ OutputDebug % "AHK| Window Coords - X: " x ", Y: " y ", W: " w ", H: " h
	}

	; -------------------------- Helper Functions ----------------------------
	; Returns a monitor object in a given vector
	; curr = Monitor ID (AHK monitor #)
	; vector = direction to look in
	; Returns monitor Object
	; ;  axis and vector mapping is required.  
	GetNextMonitor(curr, axis, vector){
		edge := "t"
		if(axis == "y") {
			edge := "t"
				if (vector > 0) {
					edge:="b"
				}
		} else {
			edge := "l"
				if (vector > 0) {
					
					edge:="r"
				}
		}
		if(this.monitorNeighbors.hasKey(curr)) {
			if(this.monitorNeighbors[curr].HasKey(edge)) {
					if(this.MonitorOrder.HasKey(this.monitorNeighbors[curr][edge])) {
						;MsgBox % JSON.dump(this.Monitors)
						curr := this.monitorNeighbors[curr][edge]
					}
			}
			
		}
		for key, mon in this.Monitors {
				if (curr == mon.ID) {
					return mon
				}
		}
		
		return curr
		
	}

	; Takes a Monitor ID (AHK Monitor ID)
	; Returns a Monitor ORDER (Monitor 1 = LeftMost)
	GetMonitorOrder(mon){
		found := 0
		for i, monid in this.MonitorOrder {
			if (monid == mon){
				found := 1
				break
			}
		}
		if (found){
			return i
		} else {
			return mon
		}
	}
	
	; Returns the Monitor Index that the center of the window is on
	GetWindowMonitor(window){
		; change the logic to check the monitor id using DLL call.
		c := window.GetCenter() ; this has caused issues.  may want to revisit this.  if so, use the logic for finding closest monitor to focus on, use distance calc from win center and monitor centers.
		;c := window.GetCoords()		
		distance := {}

		Loop % this.monitors.length() {
			m := this.monitors[A_Index].coords
			; Is the top-left corner of the window on this monitor?
			if (c.x >= m.l && c.x <= m.r && c.y >= m.t && c.y <= m.b){
				return A_Index
			}
			distance[A_Index] = abs(m["x"] - c["x"]) + abs(m["y"] - c["y"])

		}
		; find closest moniotor
		next:=false
		for k,v in distance {
			if (!next) {
				next:=k
			} else {
				if(v < distance[next]) {
					next:=k
				}
			}
		}
		return next ? next : 1 ; always set a default if nothing found.
	}
	
	
	; Returns the Monitor Index that the center of the mouse is on
	GetMouseMonitor(){
		; change the logic to check the monitor id using DLL call.
		c := this.GetMouseCoords()
		Loop % this.monitors.length() {
			m := this.Monitors[A_Index].coords
			; Is the top-left corner of the window on this monitor?
			if (c.x >= m.l && c.x <= m.r && c.y >= m.t && c.y <= m.b){
				return A_Index
			}
		}
		return 0
	}


	; --------------------------------------Window Discovery--------------------------
	InitializeAllWindows() {
		windows := this.AltTabWindows()
		for k, windowID in windows {
					;MsgBox % windowID
					win := this.GetWindowByHwnd(windowID)
					this.InitWindow(win)
					;MsgBox % JSON.dump(win)
				
		}
		return windows
		;MsgBox % JSON.dump(windows)
	}
	
	
	
	GetMouseCoords() {
		CoordMode, Mouse, Screen
		MouseGetPos, xpos, ypos
		return {x: xpos, y:ypos}
	}
	
	debugVisibleWindows() {
		win := this.GetWindow()
		CoordMode, Mouse, Screen
		MouseGetPos, xpos, ypos 
		MsgBox % "Mouse --  x: " xpos "   y: " ypos "   mon.ID: " this.GetMouseMonitor()
		MsgBox % JSON.dump(win)
		MsgBox % JSON.dump(win.GetCoords())
		MsgBox % JSON.dump(win.GetLocalCoords())
		return
		
		for key, windowID in this.AltTabWindows() {
			win := this.GetWindowByHwnd(windowID)
			MsgBox % JSON.dump(win)
		}	
		MsgBox % JSON.dump(this.AltTabWindows())
	}

	getWindowsByMonitor(mon) {
		
		;win.CurrentMonitor		
	}

	AltTabWindows() {
	   static WS_EX_TOPMOST :=            0x8 ; sets the Always On Top flag
	   static WS_EX_APPWINDOW :=      0x40000 ; provides a taskbar button
	   static WS_EX_TOOLWINDOW :=        0x80 ; removes the window from the alt-tab list
	   static GW_OWNER := 4

	   AltTabList := {}
	   windowList := ""
	   DetectHiddenWindows, Off ; makes DllCall("IsWindowVisible") unnecessary
	   WinGet, windowList, List ; gather a list of running programs
	   Loop, %windowList%
		  {
		  ownerID := windowID := windowList%A_Index%
		  Loop { ;If the window we found is opened by another application or "child", lets get the hWnd of the parent
			 ownerID := Format("0x{:x}",  DllCall("GetWindow", "UInt", ownerID, "UInt", GW_OWNER))
		  } Until !Format("0x{:x}",  DllCall("GetWindow", "UInt", ownerID, "UInt", GW_OWNER))
		  ownerID := ownerID ? ownerID : windowID

		  ; only windows that are not removed from the Alt+Tab list, AND have a taskbar button, will be appended to our list.
		  If (Format("0x{:x}", DllCall("GetLastActivePopup", "UInt", ownerID)) = windowID)
			 {
			 WinGet, es, ExStyle, ahk_id %windowID%
			 If (!((es & WS_EX_TOOLWINDOW) && !(es & WS_EX_APPWINDOW)) && !this.IsInvisibleWin10BackgroundAppWindow(windowID))
				AltTabList.Push(windowID)
			 }
		  }

	   ; UNCOMMENT THIS FOR TESTING
	   ;WinGetClass, class1, % "ahk_id" AltTabList[1]
	   ;WinGetClass, class2, % "ahk_id" AltTabList[2]
	   ;WinGetClass, classF, % "ahk_id" AltTabList.pop()
	   ;msgbox % "Number of Windows: " AltTabList.length() "`nFirst windowID: " class1 "`nSecond windowID: " class2 "`nFinal windowID: " classF
	   return AltTabList
	}

	IsInvisibleWin10BackgroundAppWindow(hWindow) {
		result := 0
		VarSetCapacity(cloakedVal, A_PtrSize) ; DWMWA_CLOAKED := 14
		hr := DllCall("DwmApi\DwmGetWindowAttribute", "Ptr", hWindow, "UInt", 14, "Ptr", &cloakedVal, "UInt", A_PtrSize)
		if !hr ; returns S_OK (which is zero) on success. Otherwise, it returns an HRESULT error code
			result := NumGet(cloakedVal) ; omitting the "&" performs better
		return result ? true : false
	}







	; ------------------------- GuiControl handling ----------------------------------
	RowColChanged(){
		;GuiControlGet, rows, , % this.hRowsEdit
		;this.MonitorRows := rows
		;GuiControlGet, cols, , % this.hColsEdit
		;this.MonitorCols := cols
		;IniWrite, % this.MonitorRows, % this.IniFile, Settings, MonitorRows
		;IniWrite, % this.MonitorCols, % this.IniFile, Settings, MonitorCols
		;this.UpdateMonitorTileConfiguration()
	}
	
	IgnoreFirstMoveChanged(){
		;GuiControlGet, setting, , % this.hIgnoreFirstMove
		;this.IgnoreFirstMove := setting
		;IniWrite, % this.IgnoreFirstMove, % this.IniFile, Settings, IgnoreFirstMove
	}






	; -------------------------------------------- Monitor Class ---------------------------------
    class CMonitor {
		ID := 0 ;	The Index (AHK Monitor ID) of the monitor
        TileCoords := {x: [], y: []}
        TileSizes := {x: 0, y: 0}
        TileCount := {x: 2, y: 2}
		Scale := 1
        
        __New(id){
			; use the offset to tweek the usable space of a tile.
			; i'm having some really bad scaling issues when trying to move
			; a window near another monitor with different dpi scaling.
			; this is a quick fix to the problem.  I.E. changing the usable
			; area we can snap/tile windows to.
			global monitorOffset
			this.monitorOffset := monitorOffset
			; monitor scale is used when setting x,y,w,h of a tile.
			global monitorScale
            this.id := id
            this.Coords := this.GetWorkArea()
			;test := DllCall("GetDpiForMonitor", "UInt", this.id)  ;
			;MsgBox % JSON.dump(test)
			for k,v in monitorScale {
				if(k==this.id) {
					this.Scale := v
				}
			}

			;MsgBox % JSON.dump(this)
        }
        
        SetRows(rows){
			; use the offset to tweek the usable space of a tile.
			; i'm having some really bad scaling issues when trying to move
			; a window near another monitor with different dpi scaling.
			; this is a quick fix to the problem.  I.E. changing the usable
			; area we can snap/tile windows to.
			global monitorOffset
			

			this.TileCoords.y := []
            this.TileCount.y := rows
            this.TileSizes.y := round(this.Coords.h / rows)
			if(this.monitorOffset.HasKey(this.id)) {
				MsgBox % "assigning y offset for monitor ID"  this.id
				this.TileSizes.y += round(this.monitorOffset[this.id].y)
			}
            o := this.coords.t
            Loop % rows {
                this.TileCoords.y.push(o)
                o += this.TileSizes.y
            }
        }
        
        SetCols(cols){
			
			
			this.TileCoords.x := []
            this.TileCount.x := cols
            this.TileSizes.x := round(this.Coords.w / cols)
			if(this.monitorOffset.HasKey(this.id)) {
				this.TileSizes.x += round(this.monitorOffset[this.id].x)
			;					MsgBox % "the monitor offset for x   "  JSON.dump(this.monitorOffset[this.id])  " and the current tile size:  " JSON.dump(this.TileSiz)

			}
            o := this.coords.l
            Loop % cols {
                this.TileCoords.x.push(o)
                o += this.TileSizes.x
            }
			
			;				MsgBox % "current X TileSizes for monitor ID"  this.id   "    data: " JSON.dump(this.TileSizes) 

        }
        
        ; Gets the "Work Area" of a monitor (The coordinates of the desktop on that monitor minus the taskbar)
        ; also pre-calculates a few values derived from the coordinates
        GetWorkArea(){
			global forceScaleOnMonitors
			

            SysGet, coords_, MonitorWorkArea, % this.id
            out := {}
            out.l := coords_left
            out.r := coords_right
            out.t := coords_top
            out.b := coords_bottom
			if(this.monitorOffset.HasKey(this.id)) {
				out.l := coords_left + this.monitorOffset[this.id].l
				out.r := coords_right+ this.monitorOffset[this.id].r
				out.t := coords_top + this.monitorOffset[this.id].t
				out.b := coords_bottom + this.monitorOffset[this.id].b
			}
			
            out.w := coords_right - coords_left
            out.h := coords_bottom - coords_top
            out.cx := coords_left + round(out.w / 2)	; center x
            out.cy := coords_top + round(out.h / 2)		; center y
            out.hw := round(out.w / 2)	; half width
            out.hh := round(out.w / 2)	 ; half height
			;MsgBox % "ID: " this.id "\n"  JSON.dump(out)
			
			if(this.monitorOffset.HasKey(this.id)) {
					
			}
			
			; trying to scale stuff to correct values.
			if(out.t != out.l) {
				
					for k, v in out {
						if (v != 0) {
														;MsgBox % k " -- " v

								;out[k] := round(v*forceScaleOnMonitors)
						}
							
					}
							
			}
						;MsgBox % JSON.dump(out)

            return out
        }
    }
    
	; ----------------------------------- Window Class ----------------------------------
    class CWindow {
        CurrentMonitor := 0	; Will point to monitor OBJECT when this window is tiled
        Pos := {x: 1, y: 1}
        Span := {x: 1, y: 1}
        
		AxisToOriginEdge := {x: "l", y: "t"}
		Axes := {x: 1, y: 2}
		scale := 1

        __New(hwnd){
			global forceScaleOnMonitors
			this.scale := forceScaleOnMonitors
            this.hwnd := hwnd
        }
        
		GetCoords(){
			WinGetPos, wx, wy, ww, wh, % "ahk_id " this.hwnd
			return {x: wx, y: wy, w: ww, h: wh}
		}
		
		GetLocalCoords(){
			coords := this.GetCoords()
			wa := this.CurrentMonitor.GetWorkArea()
			for axis, unused in this.Axes {
				l_t := this.AxisToOriginEdge[axis]
				coords[axis] := abs(wa[l_t] - coords[axis])
			}
			;~ coords.x := mon.coords.x - coords.x, coords.x := mon.coords.y - coords.y, coords.x := mon.coords.w - coords.w, coords.x := mon.coords.h - coords.h
			return coords
		}
		
        ; Gets the coordinates of the center of the window
        GetCenter(){
			w := this.GetCoords()
            cx := w.x + round(w.w / 2)
            cy := w.y + round(w.h / 2)
            return {x: cx, y: cy}
        }
		
		GetVirtualDesktopID() {
			desktopNumber := DllCall(this.GetWindowDesktopNumberProc, UInt, this.hwnd, Int)
			return desktopNumber
		}
		
		IsOnCurrentDesktop(IsWindowOnCurrentVirtualDesktopProc) {
			;MsgBox % DllCall(IsWindowOnCurrentVirtualDesktopProc, UInt, this.hwnd, Int) == 1
			if(DllCall(IsWindowOnCurrentVirtualDesktopProc, UInt, this.hwnd, Int) == 1) {
				return true
			}
			return false
		}
    }
}

; Code from Bug.n
; https://github.com/fuhsjr00/bug.n/blob/master/src/Window.ahk#L247

;; 0 - Not hung
;; 1 - Hung
Window_isHung(wndId) {
	static WM_NULL := 0
	detectHidden := A_DetectHiddenWindows
	DetectHiddenWindows, On
	SendMessage, WM_NULL, , , , % "ahk_id " wndId
	result := ErrorLevel
	DetectHiddenWindows, % detectHidden
	
	return result == 1
}

Window_getPosEx(hWindow, ByRef X = "", ByRef Y = "", ByRef Width = "", ByRef Height = "", ByRef Offset_X = "", ByRef Offset_Y = "") {
	Static Dummy5693, RECTPlus, S_OK := 0x0, DWMWA_EXTENDED_FRAME_BOUNDS := 9

	;-- Workaround for AutoHotkey Basic
	PtrType := (A_PtrSize=8) ? "Ptr" : "UInt"

	;-- Get the window's dimensions
	;   Note: Only the first 16 bytes of the RECTPlus structure are used by the
	;   DwmGetWindowAttribute and GetWindowRect functions.
	VarSetCapacity(RECTPlus, 24,0)
	DWMRC := DllCall("dwmapi\DwmGetWindowAttribute"
		,PtrType,hWindow                                ;-- hwnd
		,"UInt",DWMWA_EXTENDED_FRAME_BOUNDS             ;-- dwAttribute
		,PtrType,&RECTPlus                              ;-- pvAttribute
		,"UInt",16)                                     ;-- cbAttribute

	If (DWMRC != S_OK) {
		If ErrorLevel in -3, -4   ;-- Dll or function not found (older than Vista)
		{
			;-- Do nothing else (for now)
		} Else {
			outputdebug,
				(LTrim Join`s
				Function: %A_ThisFunc% -
				Unknown error calling "dwmapi\DwmGetWindowAttribute".
				RC = %DWMRC%,
				ErrorLevel = %ErrorLevel%,
				A_LastError = %A_LastError%.
				"GetWindowRect" used instead.
				)

			;-- Collect the position and size from "GetWindowRect"
			DllCall("GetWindowRect", PtrType, hWindow, PtrType, &RECTPlus)
		}
	}

	;-- Populate the output variables
	X := Left :=NumGet(RECTPlus, 0, "Int")
	Y := Top  :=NumGet(RECTPlus, 4, "Int")
	Right     :=NumGet(RECTPlus, 8, "Int")
	Bottom    :=NumGet(RECTPlus, 12, "Int")
	Width     :=Right-Left
	Height    :=Bottom-Top
	OffSet_X  := 0
	OffSet_Y  := 0

	;-- If DWM is not used (older than Vista or DWM not enabled), we're done
	If (DWMRC <> S_OK)
		Return &RECTPlus

	;-- Collect dimensions via GetWindowRect
	VarSetCapacity(RECT, 16, 0)
	DllCall("GetWindowRect", PtrType, hWindow, PtrType, &RECT)
	GWR_Width := NumGet(RECT, 8, "Int") - NumGet(RECT, 0, "Int")    ;-- Right minus Left
	GWR_Height := NumGet(RECT, 12, "Int") - NumGet(RECT, 4, "Int")  ;-- Bottom minus Top

	;-- Calculate offsets and update output variables
	NumPut(Offset_X := (Width  - GWR_Width)  // 2, RECTPlus, 16, "Int")
	NumPut(Offset_Y := (Height - GWR_Height) // 2, RECTPlus, 20, "Int")
	Return &RECTPlus
}

Window_move(wndId, x, y, width, height) {
	static WM_ENTERSIZEMOVE = 0x0231, WM_EXITSIZEMOVE  = 0x0232

	;~ If Not wndId Window_getPosEx(wndId, wndX, wndY, wndW, wndH) And (Abs(wndX - x) < 2 And Abs(wndY - y) < 2 And Abs(wndW - width) < 2 And Abs(wndH - height) < 2)
		;~ Return, 0
	addr := Window_getPosEx(wndId, wndX, wndY, wndW, wndH)
	if (!(wndId) && !(addr) &&  (Abs(wndX - x) < 2) &&  (Abs(wndY - y) < 2) &&  (Abs(wndW - width) < 2) &&  (Abs(wndH - height) < 2))
		return 0

	If Window_isHung(wndId) {
		OutputDebug % "DEBUG[2] Window_move: Potentially hung window " . wndId
		Return 1
	}
	/* Else {
		WinGet, wndMinMax, MinMax, % "ahk_id " wndId
		If (wndMinMax = -1 And Not Window_#%wndId%_isMinimized)
			WinRestore, ahk_id %wndId%
	}
	*/

	SendMessage, WM_ENTERSIZEMOVE, , , , % "ahk_id " wndId
	If ErrorLevel {
		;~ Debug_logMessage("DEBUG[2] Window_move: Potentially hung window " . wndId, 1)
		Return 1
	} Else {
		WinMove, % "ahk_id " wndId, , % x, % y, % width, % height
	
		;If Not (wndMinMax = 1) Or Not Window_#%wndId%_isDecorated Or Manager_windowNotMaximized(width, height) {
			If (Window_getPosEx(wndId, wndX, wndY, wndW, wndH) && (Abs(wndX - x) > 1 || Abs(wndY - y) > 1 || Abs(wndW - width) > 1 || Abs(wndH - height) > 1)) {
				x -= wndX - x
				y -= wndY - y
				width  += width - wndW - 1
				height += height - wndH - 1
				WinMove, % "ahk_id " wndId, , % x, % y, % width, % height
			}
		;}
	
		SendMessage, WM_EXITSIZEMOVE, , , , % "ahk_id " wndId
		Return, 0
	}
}



Decimal_to_Hex(var)
{
    Setformat, integer, hex
    var += 0
    Setformat, integer, d
    return var
}


HasVal(haystack, needle) {
	for index, value in haystack
		if (value = needle)
			return index
	if !IsObject(haystack)
		throw Exception("Bad haystack!", -1, haystack)
	return 0
}