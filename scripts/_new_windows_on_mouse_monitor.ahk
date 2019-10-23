#Persistent
SetBatchLines, -1
Process, Priority,, High


Gui +LastFound
newwinonmousemonitorhWnd := WinExist()


DllCall( "RegisterShellHookWindow", UInt,newwinonmousemonitorhWnd )
MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
OnMessage( MsgNum, "ShellMessage" )
Return

	
ShellMessage( wParam,lParam ) {
	global sqas
  If ( wParam = 1 ) ;  HSHELL_WINDOWCREATED := 1
     {
       Sleep, 10
       MouseGetPos, X, Y   ; get mouse location 
       WinGetTitle, Title, ahk_id %lParam%
       WinGet, maximized, MinMax, %title%


       ; Mouse screen coords = mouse relative + win coords therefore..
       WinGetPos, xtemp, ytemp,,, A ; get active windows location


       ;; Calculate actual position
       ;; -16 on x and y pos allows you to doubleclick and close window(most of the time) 
       xpos:=X+xtemp - 16
       ypos:=Y+ytemp - 16
       if (maximized != 0)
       {
        ;WinRestore, ahk_id %lParam%
       }
		

       WinMove, ahk_id %lParam%, , %xpos%, %ypos%  ; move window to mouse
       if (maximized = 1) 
       { 
          ;WinMaximize, %title%
       }
       else if (maximized = -1)
      {
         ;WinMinimize, %title%
      }
     }
}
