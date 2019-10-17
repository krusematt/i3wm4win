#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; semi-VIM Keybinding for windows
; home row key bindings.
>!j::
   Send, {Left down}{Left up}
Return

>!k::
   Send, {Down down}{Down up}
Return

>!l::
   Send, {Up down}{Up up}
Return

>!;::
   Send, {Right down}{Right up}
Return


; major movement keys, above home row.
>!u::
   Send, {Home down}{Home up}
Return

>!p::
   Send, {End down}{End up}
Return

>!i::
   Send, {PgDn down}{PgDn up}
Return

>!o::
   Send, {PgUp down}{PgUp up}
Return

; home row modifier movement keys (shift + arrow) (ctrl + shift + arrow)
;;;; + ctrl
^>!j::
   Send, {Control down}{Left down}{Left up}{Control up}
Return
^>!k::
   Send, {Control down}{Down down}{Down up}{Control up}
Return
^>!l::
   Send, {Control down}{Up down}{Up up}{Control up}
Return
^>!;::
   Send, {Control down}{Right down}{Right up}{Control up}
Return
;;;;; + shift
+>!j::
   Send, {Shift down}{Left down}{Left up}{Shift up}
Return
+>!k::
   Send, {Shift down}{Down down}{Down up}{Shift up}
Return
+>!l::
   Send, {Shift down}{Up down}{Up up}{Shift up}
Return
+>!;::
   Send, {Shift down}{Right down}{Right up}{Shift up}
Return
;;;;; + ctrl + shift
; home row modifier movement keys (shift + arrow) (ctrl + shift + arrow)
+^>!j::
   Send, {Shift down}{Control down}{Left down}{Left up}{Control up}{Shift up}
Return
+^>!;::
   Send, {Shift down}{Control down}{Right down}{Right up}{Control up}{Shift up}
Return
; for now -- up and down should behave like shift+down, as we're in select text mode at the time we invoke this hotkey
+^>!k::
   Send, {Shift down}{Down down}{Down up}{Shift up}
Return
+^>!l::
   Send, {Shift down}{Up down}{Up up}{Shift up}
Return

; :todo,  make this configurable.
<!Enter::
   Run, ubuntu
return

; note, testing this to see if it will work.
<!d::
   Send, ^{Esc}
return

