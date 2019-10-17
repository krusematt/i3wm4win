﻿;#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Enable warnings to assist with detecting common errors.
;SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
;SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

global listOfEvents := []

MajorVersion := DllCall("GetVersion") & 0xFF                ; 10
MinorVersion := DllCall("GetVersion") >> 8 & 0xFF           ; 0
BuildNumber  := DllCall("GetVersion") >> 16 & 0xFFFF        ; 10532

;MsgBox % "MajorVersion:`t" MajorVersion "`n"
;       . "MinorVersion:`t" MinorVersion "`n"
;       . "BuildNumber:`t"  BuildNumber
	   
	   
;  load the correct DLL based on the version of windows.  i.e.  < 1803 vs  > 1803    different lib required.
if (BuildNumber <= 17134) {
	hVirtualDesktopAccessor := DllCall("LoadLibrary", Str, A_LineFile . "\VirtualDesktopAccessor_1803_and_lower.dll", "Ptr") 
}
if (BuildNumber > 17134) {
	hVirtualDesktopAccessor := DllCall("LoadLibrary", Str, A_LineFile . "\VirtualDesktopAccessor_1809_and_above.dll", "Ptr") 
}

; #Include shell_spy.ahk

DetectHiddenWindows, On
hwnd:=WinExist("ahk_pid " . DllCall("GetCurrentProcessId","Uint"))
hwnd+=0x1000<<32

GoToDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GoToDesktopNumber", "Ptr")
GetCurrentDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GetCurrentDesktopNumber", "Ptr")
GetWindowDesktopIdProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GetWindowDesktopId", "Ptr")
GetWindowDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GetWindowDesktopNumber", "Ptr")
IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "IsWindowOnCurrentVirtualDesktop", "Ptr")
MoveWindowToDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "MoveWindowToDesktopNumber", "Ptr")
RegisterPostMessageHookProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "RegisterPostMessageHook", "Ptr")
UnregisterPostMessageHookProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "UnregisterPostMessageHook", "Ptr")
IsPinnedWindowProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "IsPinnedWindow", "Ptr")
RestartVirtualDesktopAccessorProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "RestartVirtualDesktopAccessor", "Ptr")
; GetWindowDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GetWindowDesktopNumber", "Ptr")
activeWindowByDesktop := {}

; Restart the virtual desktop accessor when Explorer.exe crashes, or restarts (e.g. when coming from fullscreen game)
explorerRestartMsg := DllCall("user32\RegisterWindowMessage", "Str", "TaskbarCreated")
OnMessage(explorerRestartMsg, "OnExplorerRestart")
OnExplorerRestart(wParam, lParam, msg, hwnd) {
    global RestartVirtualDesktopAccessorProc
    DllCall(RestartVirtualDesktopAccessorProc, UInt, result)
}

MoveCurrentWindowToDesktop(number) {
	global MoveWindowToDesktopNumberProc, GoToDesktopNumberProc, activeWindowByDesktop
	WinGet, activeHwnd, ID, A
	activeWindowByDesktop[number] := 0 ; Do not activate
	DllCall(MoveWindowToDesktopNumberProc, UInt, activeHwnd, UInt, number)
	; todo: make this an optional.  by default, i3wm does not automatically focus to the dekstop you're sending the window to.  So the behavior will be the same in this instance.
	; DllCall(GoToDesktopNumberProc, UInt, number)
}

GoToPrevDesktop() {
	global GetCurrentDesktopNumberProc, GoToDesktopNumberProc
	current := DllCall(GetCurrentDesktopNumberProc, UInt)
	if (current = 0) {
		GoToDesktopNumber(7)
	} else {
		GoToDesktopNumber(current - 1)      
	}
	return
}

GoToNextDesktop() {
	global GetCurrentDesktopNumberProc, GoToDesktopNumberProc
	current := DllCall(GetCurrentDesktopNumberProc, UInt)
	if (current = 7) {
		GoToDesktopNumber(0)
	} else {
		GoToDesktopNumber(current + 1)    
	}
	return
}

GoToDesktopNumber(num) {
	global GetCurrentDesktopNumberProc, GoToDesktopNumberProc, IsPinnedWindowProc, activeWindowByDesktop

	; Store the active window of old desktop, if it is not pinned
	WinGet, activeHwnd, ID, A
	current := DllCall(GetCurrentDesktopNumberProc, UInt) 
	isPinned := DllCall(IsPinnedWindowProc, UInt, activeHwnd)
	if (isPinned == 0) {
		activeWindowByDesktop[current] := activeHwnd
	}

	; Try to avoid flashing task bar buttons, deactivate the current window if it is not pinned
	if (isPinned != 1) {
		WinActivate, ahk_class Shell_TrayWnd
	}

	; Change desktop
	DllCall(GoToDesktopNumberProc, Int, num)
	return
}

; Windows 10 desktop changes listener
DllCall(RegisterPostMessageHookProc, Int, hwnd, Int, 0x1400 + 30)
OnMessage(0x1400 + 30, "VWMess")
VWMess(wParam, lParam, msg, hwnd) {
	global IsWindowOnCurrentVirtualDesktopProc, IsPinnedWindowProc, activeWindowByDesktop

	desktopNumber := lParam + 1
	
	; Try to restore active window from memory (if it's still on the desktop and is not pinned)
	WinGet, activeHwnd, ID, A 
	isPinned := DllCall(IsPinnedWindowProc, UInt, activeHwnd)
	oldHwnd := activeWindowByDesktop[lParam]
	isOnDesktop := DllCall(IsWindowOnCurrentVirtualDesktopProc, UInt, oldHwnd, Int)
	if (isOnDesktop == 1 && isPinned != 1) {
		WinActivate, ahk_id %oldHwnd%
	}

	; Menu, Tray, Icon, Icons/icon%desktopNumber%.ico
	
	; When switching to desktop 1, set background pluto.jpg
	; if (lParam == 0) {
		; DllCall("SystemParametersInfo", UInt, 0x14, UInt, 0, Str, "C:\Users\Jarppa\Pictures\Backgrounds\saturn.jpg", UInt, 1)
	; When switching to desktop 2, set background DeskGmail.png
	; } else if (lParam == 1) {
		; DllCall("SystemParametersInfo", UInt, 0x14, UInt, 0, Str, "C:\Users\Jarppa\Pictures\Backgrounds\DeskGmail.png", UInt, 1)
	; When switching to desktop 7 or 8, set background DeskMisc.png
	; } else if (lParam == 2 || lParam == 3) {
		; DllCall("SystemParametersInfo", UInt, 0x14, UInt, 0, Str, "C:\Users\Jarppa\Pictures\Backgrounds\DeskMisc.png", UInt, 1)
	; Other desktops, set background to DeskWork.png
	; } else {
		; DllCall("SystemParametersInfo", UInt, 0x14, UInt, 0, Str, "C:\Users\Jarppa\Pictures\Backgrounds\DeskWork.png", UInt, 1)
	; }
}


























getAllVisibleWindowsOnAllVirtualDesktops(){
	global IsWindowOnCurrentVirtualDesktopProc, IsPinnedWindowProc, activeWindowByDesktop, GetWindowDesktopIdProc, GetWindowDesktopNumberProc

	WinGet,WinList,List,,,Program Manager
	List=""
	WindowList:={}  ; a list of all windows, Key = VirtualDesktopNumber
	c = 0
	loop,%WinList%{
		Current:=WinList%A_Index%
		If Current {
			c++
			;WinGet, activeHwnd, ID, %WinTitle% 
			activeHwnd := Current
			desktopNumber := DllCall(GetWindowDesktopNumberProc, UInt, activeHwnd, Int)
			;MsgBox % guid
			isOnDesktop := DllCall(IsWindowOnCurrentVirtualDesktopProc, UInt, activeHwnd, Int)
			if (DllCall(IsWindowOnCurrentVirtualDesktopProc, UInt, activeHwnd, Int) == 1) {
				if DllCall("IsWindowVisible", "UInt", activeHwnd) {
					WinGetTitle,WinTitle,ahk_id %Current%

					WinGetPos, X, Y, Width, Height, %WinTitle%
					 ; this doesn't work for some reason... ;; isOnDesktop := DllCall(IsWindowOnCurrentVirtualDesktopProc, UInt, activeHwnd, Int)
					List.="`n" "Desktop:" desktopNumber "   ID:" activeHwnd " --- " WinTitle " x=" X " y=" Y " width=" Width " height=" Height
					if (!WindowList.HasKey(desktopNumber)) {
						WindowList[desktopNumber]:=[]
					}
					WindowList[desktopNumber].Push({ x: X, y: Y, title:WinTitle, height: Height, width: Width, activeHwnd: activeHwnd })
				}
			}
   		}
	}
	;MsgBox %List%
	;	MsgBox % c
	;	MsgBox % WindowList.Length()

	; msgList(Wins)
	return WindowList 
}

getAllWindowsOnCurrentVirtualDesktop() {
	global GetCurrentDesktopNumberProc
		WL:=getAllVisibleWindowsOnAllVirtualDesktops()
		current := DllCall(GetCurrentDesktopNumberProc, UInt)
		msgList(WL[current])
}

msgList(l) {
	List=""
	c=0
	for k,v in l {
		c++
		List.="`n" " ID:" v["activeHwnd"] "  Title" v["title"] " ---- X:" v["x"] "   Y:" v["y"]
	}
	;MsgBox % c
		MsgBox %List%

	;DebugMessage(List)
}


msgLines() {
	List=""
	for k,v in listOfEvents {
		List.="`n"v
	}
	MsgBox % List
}




;for key, value in activeWindowByDesktop
;    MsgBox activeWindowByDesktop.%key% = %value%

; +<!g::getWindowsOnVirtualDesktop()

<!g::
   getAllWindowsOnCurrentVirtualDesktop()
   return






<!1::GoToDesktopNumber(0)
<!2::GoToDesktopNumber(1)
<!3::GoToDesktopNumber(2)
<!4::GoToDesktopNumber(3)
<!5::GoToDesktopNumber(4)
<!6::GoToDesktopNumber(5)
<!7::GoToDesktopNumber(6)
<!8::GoToDesktopNumber(7)
<!9::GoToDesktopNumber(8)
<!0::GoToDesktopNumber(9)


+<!1::MoveCurrentWindowToDesktop(0)
+<!2::MoveCurrentWindowToDesktop(1)
+<!3::MoveCurrentWindowToDesktop(2)
+<!4::MoveCurrentWindowToDesktop(3)
+<!5::MoveCurrentWindowToDesktop(4)
+<!6::MoveCurrentWindowToDesktop(5)
+<!7::MoveCurrentWindowToDesktop(6)
+<!8::MoveCurrentWindowToDesktop(7)
+<!9::MoveCurrentWindowToDesktop(8)
+<!0::MoveCurrentWindowToDesktop(9)


<!-::GoToPrevDesktop()
<!=::GotoNextDesktop()




;
;
;  WINDOW FOCUS LOGIC
;
;


<!j::
	focusToWindow("left")
	return
<!k::
	focusToWindow("down")
	return
<!l::
	focusToWindow("up")
	return

<!;::
	focusToWindow("right")
	return




focusToWindow(direction) {
	
	MsgBox Testing Focus Window
	global IsWindowOnCurrentVirtualDesktopProc, IsPinnedWindowProc, activeWindowByDesktop
	; declare variables
	WinGetActiveTitle, Title
	WinGet, activeHwnd, ID, %Title%
	
	if (direction == "up") {
	}
	
	if (direction == "down") {
	}
	
	if (direction == "left") {
	}
	
	if (direction == "right") {
	}
	
	
	; look at current active window for coordinates.
	WinGetPos, X, Y, Width, Height, %Title%
	centerX := X + (Width / 2)
	centerY := Y + (Height / 2)
	MsgBox x = %X%, y = %Y%, width=%Width%, height=%Height%, centerX = %centerX%, centerY = %centerY%
	
	; find nearest
	windows = getAllWindowsOnCurrentVirtualDesktop()

}




; bind to shellhook window events.  use this to refresh the window list for focus movment speed improvement.



<!h::
	msgLines()
	return







;;;;;;;;;;;;;;;;;;;; debug stuff

DebugMessage(str)
{
 global h_stdout
 DebugConsoleInitialize()  ; start console window if not yet started
 str .= "`n" ; add line feed
 DllCall("WriteFile", "uint", h_Stdout, "uint", &str, "uint", StrLen(str), "uint*", BytesWritten, "uint", NULL) ; write into the console
 WinSet, Bottom,, ahk_id %h_stout%  ; keep console on bottom
}

DebugConsoleInitialize()
{
   global h_Stdout     ; Handle for console
   static is_open = 0  ; toogle whether opened before
   if (is_open = 1)     ; yes, so don't open again
     return
	 
   is_open := 1	
   ; two calls to open, no error check (it's debug, so you know what you are doing)
   DllCall("AttachConsole", int, -1, int)
   DllCall("AllocConsole", int)

   dllcall("SetConsoleTitle", "str","Paddy Debug Console")    ; Set the name. Example. Probably could use a_scriptname here 
   h_Stdout := DllCall("GetStdHandle", "int", -11) ; get the handle
   WinSet, Bottom,, ahk_id %h_stout%      ; make sure it's on the bottom
   WinActivate,Lightroom   ; Application specific; I need to make sure this application is running in the foreground. YMMV
   return
}