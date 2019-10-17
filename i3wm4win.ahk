#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.




class i3wm4win {
    CtrlCapsSwap := 0
	MovementHotKeys := 0
	DesktopSwitcher := 0
	MonitorRows := 4
	MonitorCols := 4
    Monitors := []
    TiledWindows := {}
	IgnoreFirstMove := 1
	
	Axes := {x: 1, y: 2}
	AxisToWh := {x: "w", y: "h"}
    
	; --------------------------------- Constructor -------------------------------
    __New(){
		this.IniFile := RegExReplace(A_ScriptName, "\.exe|\.ahk", ".ini")
		this.hwnd := hwnd
		settings_loaded := this.LoadSettings()		
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
			IniRead, CtrlCapsSwap, % this.IniFile, KeyBindings, Ctrl_Caps_Swap
			if (CtrlCapsSwap != "ERROR"){
				this.CtrlCapsSwap := CtrlCapsSwap
			}
			IniRead, MovementHotKeys, % this.IniFile, KeyBindings, Movement_Hot_Keys
			if (MovementHotKeys != "ERROR"){
				this.MovementHotKeys := MovementHotKeys
			}
			IniRead, DesktopSwitcher, % this.IniFile, KeyBindings, Virtual_Desktop_Switcher
			if (DesktopSwitcher != "ERROR"){
				this.DesktopSwitcher := DesktopSwitcher
			}			
		}
		
		; Initialize hotkeys
		this.SetHotkeyState()
		
		; Update the GuiControls
		GuiControl, , % this.hRowsEdit, % this.MonitorRows
		GuiControl, , % this.hColsEdit, % this.MonitorCols
		GuiControl, , % this.hIgnoreFirstmove, % this.IgnoreFirstMove
		
		return first_run
	}
	
	setHotkeyState() {
		if(this.CtrlCapsSwap == 1) #Include %A_LineFile%\scripts\_ctrl_caps_swap.ahk
		if(this.MovementHotKeys == 1) #Include %A_LineFile%\scripts\_movement_and_cursor_controls.ahk
		if(this.DesktopSwitcher == 1) #Include %A_LineFile%\scripts\_desktop_switcher.ahk
	}
}

