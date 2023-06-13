#Requires AutoHotkey v2.0

Main := Gui()
Main.MarginX := 15
Main.MarginY := 15
Main.SetFont("S12", "Microsoft YaHei UI")
Main.Title := "AHK Rime Console"

maxLogLine := 12

Main.OnEvent("Close", (*) => ExitApp)
Main.AddText("vMyLog xm ym w480 r" . maxLogLine, "Hello, World!")
Main.AddEdit("vMyInput -Multi w380")
Main.AddButton("vMySend yp", "Send")
; Main.AddButton("vMyClear yp", "Clear")

Main["MySend"].OnEvent("Click", Send_Click)

Main.Show("AutoSize")

Print(output, cleanup := false)
{
    static text, num_line
    if not IsSet(num_line) {
        num_line := 1
        cleanup := true
    }
    if not IsSet(Main) {
        ExitApp(1)
    }
    LogText := Main["MyLog"]
    if (cleanup) {
        num_line := 1
        text := output
    } else if num_line < maxLogLine {
        num_line := num_line + 1
        text := LogText.Text . "`r`n" . output
    } else {
        text := SubStr(LogText.Text, InStr(LogText.Text, "`n") + 1) . "`r`n" . output
    }
    LogText.Text := text
}

NotificationHandler(context_object, session_id, message_type, message_value)
{
    msg := "Session: " . session_id . ", " StrGet(message_type, "UTF-8") . ": " . StrGet(message_value, "UTF-8")
}

Send_Click(GuiCtrlObj, Info)
{
    if not rimeReady {
        return
    }
    GuiObj := GuiCtrlObj.Gui
    line := GuiObj["MyInput"].Text
    if line = "" {
        return
    }
    if line = "exit" {
        ExitApp
    }
    if line = "print schema list" {
        list := Buffer(8, 0)
        res := DllCall("rime\RimeGetSchemaList", "Ptr", list.Ptr, "Cdecl")
        if res {
            Print("schema list:")
            size := NumGet(list, 0, "UInt")
            Loop size {
                item := NumGet(list.Ptr, 4, "Ptr") + (A_Index - 1) * 12 ; item = list[A_Index - 1]
                schema_id_ptr := NumGet(item, 0, "Ptr") ; schema_id_ptr = item.schema_id
                schema_id := StrGet(schema_id_ptr, "UTF-8")
                name_ptr := NumGet(item, 4, "Ptr") ; name_ptr = item.name
                name := StrGet(name_ptr, "UTF-8")
                out := A_Index . ". " . name . " [" . schema_id . "]"
                Print(out)
            }
        }
        current := Buffer(100, 0)
        res := DllCall("rime\RimeGetCurrentSchema", "Int", session_id, "Ptr", current, "UInt", current.Size, "Cdecl")
        if res {
            current_name := StrGet(current, "UTF-8")
            Print("current schema: [" . current_name . "]")
        }
        return
    }
    if RegExMatch(line, "select schema (.+)", &matched) {
        schema_id := matched[1]
        id_length := StrPut(schema_id, "UTF-8")
        id := Buffer(id_length, 0)
        StrPut(schema_id, id, "UTF-8")
        res := DllCall("rime\RimeSelectSchema", "Int", session_id, "Ptr", id, "Cdecl")
        if res {
            Print("selected schema: [" . schema_id . "]")
        }
        return
    }
    ; TODO: select candidate
    ; TODO: print candidate list
    ; TODO: set option
    line_length := StrPut(line, "UTF-8")
    line_buff := Buffer(line_length)
    StrPut(line, line_buff, "UTF-8")
    ; TODO: simulate key sequence
}

rimeModule := DllCall("LoadLibrary", "Str", "rime.dll", "Ptr")
rimeReady := false

; sizeof(RimeTraits) = 96
traits := Buffer(96, 0)
NumPut("Int", 92, traits, 0) ; traits.data_size = 92 (sizeof(RimeTraits) - sizeof(traits.data_size))
app_name_literal := "ahk.rime.console"
app_name_length := StrPut(app_name_literal, "UTF-8")
app_name := Buffer(app_name_length)
StrPut(app_name_literal, app_name, "UTF-8")
NumPut("Ptr", app_name.Ptr, traits, 48) ; traits.app_name = "ahk.rime.console"

dir_literal := "rime"
dir_length := StrPut(dir_literal, "UTF-8")
dir := Buffer(dir_length)
StrPut(dir_literal, dir, "UTF-8")
NumPut("Ptr", dir.Ptr, traits, 4)
NumPut("Ptr", dir.Ptr, traits, 8)

DllCall("rime\RimeSetup", "Ptr", traits, "Cdecl")
DllCall("rime\RimeSetNotificationHandler", "Ptr", CallbackCreate(NotificationHandler, "C", 4), "Ptr", 0, "Cdecl")

Print("initializing...", true)

DllCall("rime\RimeInitialize", "Ptr", 0, "Cdecl")
success := DllCall("rime\RimeStartMaintenance", "Int", 1, "Cdecl")
if success {
    DllCall("rime\RimeJoinMaintenanceThread", "CDecl")
}

rimeReady := true
Print("ready.")

session_id := DllCall("rime\RimeCreateSession", "CDecl")
if not session_id {
    MsgBox("Error creating rime session.\n")
    Exit(1)
}

OnExit ExitRimeConsole

ExitRimeConsole(ExitReason, ExitCode) {
    DllCall("rime\RimeDestroySession", "Int", session_id, "Cdecl")
    DllCall("rime\RimeFinalize", "CDecl")

    DllCall("FreeLibrary", "Ptr", rimeModule)
}
