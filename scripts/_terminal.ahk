#if i3wm4win.settings.TerminalCMD
<!Enter::launchTerminal()
launchTerminal() {
   cmd := i3wm4win.settings["TerminalCMD"]
   Run, %cmd%  ; run doesn't like objects to be passed into it. =(
}
#if