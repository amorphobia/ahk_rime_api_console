MyGui := Gui("+Resize +MinSize300x200")
MyGui.AddText("vMessages", "Hellow World.")
MyGui.Show()

Print(output)
{
    static hGui, text
    if not IsSet(hGui) {
        hGui := Gui("+Resize")
        hGui.AddText("vhText x0 y0 w400 h200")
        hGui.Title := "Messages"
        hGui["hText"].SetFont("S10", "Microsoft YaHei")
        hGui.Show("w400 h200")
        text := output
    } else {
        text := hGui["hText"].Text . "`r`n" . output
    }
    hGui["hText"].Text := text
}

NotificationHandler(context_object, session_id, message_type, message_value)
{
    msg := "Session: " . session_id . "    " StrGet(message_type, "UTF-8") . ": " . StrGet(message_value, "UTF-8")
    ; DllCall(context_object, "Str", msg, "Cdecl")
    ; Print(msg)
    ; MyGui.Title := session_id
    ; MyGui["Messages"].Text := msg
}

rimeModule := DllCall("LoadLibrary", "Str", "rime.dll", "Ptr")

; sizeof(RimeTraits) = 96
traits := Buffer(96, 0)
NumPut("Int", 92, traits, 0) ; traits.data_size = 92 (sizeof(RimeTraits) - sizeof(traits.data_size))
app_name_literal := "ahk.rime.console"
app_name_length := StrPut(app_name_literal, "UTF-8")
Print(app_name_length)
app_name := Buffer(app_name_length)
StrPut(app_name_literal, app_name, "UTF-8")
NumPut("Ptr", app_name.Ptr, traits, 48) ; traits.app_name = "ahk.rime.console"

dir_literal := "rime"
dir_length := StrPut(dir_literal, "UTF-8")
dir := Buffer(dir_length)
StrPut(dir_literal, dir, "UTF-8")
NumPut("Ptr", dir.Ptr, traits, 4)
NumPut("Ptr", dir.Ptr, traits, 8)

name_ptr := NumGet(traits, 8, "Ptr")
Print(StrGet(name_ptr, "UTF-8"))

DllCall("rime\RimeSetup", "Ptr", traits, "Cdecl")

DllCall("rime\RimeSetNotificationHandler", "Ptr", CallbackCreate(NotificationHandler, "C", 4), "Ptr", 0, "Cdecl")

Print("initializing...")

DllCall("rime\RimeInitialize", "Ptr", 0, "Cdecl")
success := DllCall("rime\RimeStartMaintenance", "Int", 1, "Cdecl")
if success {
    DllCall("rime\RimeJoinMaintenanceThread", "CDecl")
}

Print("ready.")

session_id := DllCall("rime\RimeCreateSession", "CDecl")
if not session_id {
    MsgBox("Error creating rime session.\n")
    MyGui.Destroy()
    Exit(1)
}

MyGui.AddEdit()

MyGui.AddButton("vSend", "Send")

OnExit ExitRimeConsole

ExitRimeConsole(ExitReason, ExitCode) {
    DllCall("rime\RimeDestroySession", "Int", session_id, "Cdecl")
    DllCall("rime\RimeFinalize", "CDecl")

    DllCall("FreeLibrary", "Ptr", rimeModule)
}
