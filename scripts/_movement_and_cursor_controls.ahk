﻿
; semi-VIM Keybinding for windows
; home row key bindings.
;#if i3wm4win.settings["MovementHotKeys"]
>!j::Send, {Left down}{Left up}
>!k::Send, {Down down}{Down up}
>!l::Send, {Up down}{Up up}
>!;::Send, {Right down}{Right up}
; major movement keys, above home row.
>!u::Send, {Home down}{Home up}
>!p::Send, {End down}{End up}
>!i::Send, {PgDn down}{PgDn up}
>!o::Send, {PgUp down}{PgUp up}
; home row modifier movement keys (shift + arrow) (ctrl + shift + arrow)
;;;; + ctrl
^>!j::Send, {Control down}{Left down}{Left up}{Control up}
^>!k::Send, {Control down}{Down down}{Down up}{Control up}
^>!l::Send, {Control down}{Up down}{Up up}{Control up}
^>!;::Send, {Control down}{Right down}{Right up}{Control up}
;;;;; + shift
+>!j::Send, {Shift down}{Left down}{Left up}{Shift up}
+>!k::Send, {Shift down}{Down down}{Down up}{Shift up}
+>!l::Send, {Shift down}{Up down}{Up up}{Shift up}
+>!;::Send, {Shift down}{Right down}{Right up}{Shift up}
;;;;; + ctrl + shift
; home row modifier movement keys (shift + arrow) (ctrl + shift + arrow)
+^>!j::Send, {Shift down}{Control down}{Left down}{Left up}{Control up}{Shift up}
+^>!;::Send, {Shift down}{Control down}{Right down}{Right up}{Control up}{Shift up}
; for now -- up and down should behave like shift+down, as we're in select text mode at the time we invoke this hotkey
+^>!k::Send, {Shift down}{Down down}{Down up}{Shift up}
+^>!l::Send, {Shift down}{Up down}{Up up}{Shift up}
; :todo,  make this configurable.