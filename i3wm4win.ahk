﻿#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
DetectHiddenWindows, On



MsgBox % A_LineFile


; Initialize our root i3wm4win object.  Set it as a global so we can use this object anywhere.
global i3wm4win := new i3wm4win_bootstrap()

class i3wm4win_bootstrap {
	count := 0
    CtrlCapsSwap := 0
	MovementHotKeys := 0
	DesktopSwitcher := 0
	MonitorRows := 4
	MonitorCols := 4
    Monitors := []
    TiledWindows := {}
	IgnoreFirstMove := 1
	
	settings := { MovementHotKeys: 0, DesktopSwitcher: 0, CtrlCapsSwap: 0 , TerminalCMD: 0, EnableLauncher: 0	}
	
	Axes := {x: 1, y: 2}
	AxisToWh := {x: "w", y: "h"}
    
	; --------------------------------- Constructor -------------------------------
    __New(){
		this.msg()
		this.IniFile := RegExReplace(A_ScriptName, "\.exe|\.ahk", ".ini")
		this.hwnd := WinExist("ahk_pid " . DllCall("GetCurrentProcessId","Uint"))
		settings_loaded := this.LoadSettings()
		this.setHotkeyState()
		return this
	}
	
	msg() {
		this.count ++
		;MsgBox % "count: " this.count
	}
	
	; --------------------------------- Inital Setup -------------------------------
	LoadSettings(){
		if (FileExist(this.IniFile)){
			first_run := 0
		} else {
			first_run := 1
			FileAppend, % "", % this.IniFile
		}
		if (!first_run){
			for key, v in this.settings {
				IniRead, iniVal, % this.IniFile, Settings, %key%
				if (iniVal != "ERROR"){
					this.settings[key] := iniVal
					MsgBox %key% = %iniVal%
				}
			}
		}
		return first_run
	}

}




; ------------ include all script files ------------------
#Include %A_ScriptDir%\scripts\_desktop_switcher.ahk


#Include %A_ScriptDir%\scripts\_movement_and_cursor_controls.ahk




#Include %A_ScriptDir%\scripts\_launcher.ahk
#Include %A_ScriptDir%\scripts\_terminal.ahk
#Include %A_ScriptDir%\scripts\_ctrl_caps_swap.ahk