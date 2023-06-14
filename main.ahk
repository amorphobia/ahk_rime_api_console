#Requires AutoHotkey v2.0 32-bit

Main := Gui()
Main.MarginX := 15
Main.MarginY := 15
Main.SetFont("S12", "Microsoft YaHei UI")
Main.Title := "AHK Rime Console"

maxLogLine := 12

Main.OnEvent("Close", (*) => ExitApp)
Main.AddEdit("vLog xm ym w480 ReadOnly VScroll r" . maxLogLine)
Main.AddEdit("vMyInput -Multi w480")
Main.AddButton("Default Hidden w0 h0 vDftBtn")

Main["DftBtn"].OnEvent("Click", Send_KeySequence)

ControlFocus(Main["MyInput"])
Main.Show("AutoSize")

Print(output)
{
    static text
    LogEdit := Main["Log"]
    if not IsSet(text) {
        text := output
    } else {
        text := LogEdit.Value . "`r`n" . output
    }
    LogEdit.Value := text
    ControlSend("^{End}", LogEdit)
}

NotificationHandler(context_object, session_id, message_type, message_value)
{
    msg := "Session: " . session_id . ", " StrGet(message_type, "UTF-8") . ": " . StrGet(message_value, "UTF-8")
}

PrintStatus(status)
{
    schema_id := StrGet(NumGet(status, 4, "Ptr"), "UTF-8")
    schema_name := StrGet(NumGet(status, 8, "Ptr"), "UTF-8")
    Print("schema: " . schema_id . " / " . schema_name)
    out := "status: "
    if NumGet(status, 12, "Int") {
        out := out . "disabled "
    }
    if NumGet(status, 16, "Int") {
        out := out . "composing "
    }
    if NumGet(status, 20, "Int") {
        out := out . "ascii "
    }
    if NumGet(status, 24, "Int") {
        out := out . "full_shape "
    }
    if NumGet(status, 28, "Int") {
        out := out . "simplified "
    }
    Print(out)
}

PrintContext(context)
{
    if NumGet(context, 4, "Int") > 0 {
        ; TODO: print composition
        preedit_ptr := NumGet(context, 20, "Ptr")
        if preedit_ptr {
            preedit := StrGet(preedit_ptr, "UTF-8")
        }
        ; TODO: print menu
    } else {
        Print("(not composing)")
    }
}

PrintSession(sid)
{
    api := DllCall("rime\rime_get_api", "Cdecl Ptr")
    commit := Buffer(8, 0)
    NumPut("Int", 4, commit, 0) ; commit.data_size = 4
    status := Buffer(40, 0)
    NumPut("Int", 36, status, 0) ; commit.data_size = 36
    context := Buffer(60, 0)
    NumPut("Int", 56, context, 0) ; commit.data_size = 56

    res := DllCall(NumGet(api, 88, "Ptr"), "Int", sid, "Ptr", commit.Ptr, "Cdecl") ; rime->get_commit
    if res {
        text := StrGet(NumGet(commit, 4, "Ptr"), "UTF-8")
        Print("commit: " . text)
        DllCall(NumGet(api, 92, "Ptr"), "Ptr", commit.Ptr, "Cdecl") ; rime->free_commit
    }

    res := DllCall(NumGet(api, 104, "Ptr"), "Int", sid, "Ptr", status.Ptr, "Cdecl") ; rime->get_status
    if res {
        PrintStatus(status)
        DllCall(NumGet(api, 108, "Ptr"), "Ptr", status.Ptr, "Cdecl") ; rime->free_status
    }

    res := DllCall(NumGet(api, 96, "Ptr"), "Int", sid, "Ptr", context.Ptr, "Cdecl") ; rime->get_context
    if res {
        PrintContext(context)
        DllCall(NumGet(api, 100, "Ptr"), "Ptr", context.Ptr, "Cdecl") ; rime->free_context
    }
}

Send_KeySequence(GuiCtrlObj, Info)
{
    if not rimeReady {
        return
    }
    GuiObj := GuiCtrlObj.Gui
    line := GuiObj["MyInput"].Value
    GuiObj["MyInput"].Value := ""
    if line = "" {
        return
    }
    if line = "exit" {
        ExitApp
    }
    api := DllCall("rime\rime_get_api", "Cdecl Ptr")
    if line = "print schema list" {
        list := Buffer(8, 0)
        res := DllCall(NumGet(api, 128, "Ptr"), "Ptr", list.Ptr, "Cdecl") ; rime->get_schema_list
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
            DllCall(NumGet(api, 132, "Ptr"), "Ptr", list.Ptr, "Cdecl") ; rime->free_schema_list
        }
        current := Buffer(100, 0)
        res := DllCall(NumGet(api, 136, "Ptr"), "Int", session_id, "Ptr", current, "UInt", current.Size, "Cdecl")
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
        res := DllCall(NumGet(api, 140, "Ptr"), "Int", session_id, "Ptr", id, "Cdecl") ; rime->select_schema
        if res {
            Print("selected schema: [" . schema_id . "]")
        }
        return
    }
    if RegExMatch(line, "select candidate (.+)", &matched) {
        index := Integer(matched[1])
        if index > 0 {
            res := DllCall(NumGet(api, 300, "Ptr"), "Int", session_id, "UInt", index - 1, "Cdecl") ; rime->select_candidate_on_current_page
        } else {
            res := 0
        }
        if res {
            PrintSession(session_id)
        } else {
            MsgBox("cannot select candidate at index " . index . ".", "Error")
        }
        return
    }
    if RegExMatch(line, "print candidate list") {
        cand_iter := Buffer(20, 0) ; RimeCandidateListIterator
        res := DllCall(NumGet(api, 304, "Ptr"), "Int", session_id, "Ptr", cand_iter.Ptr, "Cdecl") ; rime->candidate_list_begin
        if res {
            Loop {
                res := DllCall(NumGet(api, 308, "Ptr"), "Ptr", cand_iter.Ptr, "Cdecl") ; rime->candidate_list_next
                if not res {
                    break
                }
                cand_text_ptr := NumGet(cand_iter, 8, "Ptr")
                cand_text := StrGet(cand_text_ptr, "UTF-8")
                out := NumGet(cand_iter, 4, "Int") + 1 . ". " . cand_text
                comment_ptr := NumGet(cand_iter, 12, "Ptr")
                if comment_ptr {
                    comment := StrGet(comment_ptr, "UTF-8")
                    out := out . " (" . comment . ")"
                }
                Print(out)
            }
            DllCall(NumGet(api, 312, "Ptr"), "Ptr", cand_iter.Ptr, "Cdecl") ; rime->candidate_list_end
        } else {
            Print("no candidates.")
        }
        return
    }
    if RegExMatch(line, "set option (.+)", &matched) {
        is_on := true
        option := matched[1]
        if SubStr(option, 1, 1) = "!" {
            is_on := false
            option := SubStr(option, 2)
        }
        opt_len := StrPut(option, "UTF-8")
        opt_buff := Buffer(opt_len, 0)
        StrPut(option, opt_buff, "UTF-8")
        DllCall(NumGet(api, 112, "Ptr"), "Int", session_id, "Ptr", opt_buff.Ptr, "Int", is_on, "Cdecl") ; rime->set_option
        if is_on {
            Print(option . " set on.")
        } else {
            Print(option . " set off.")
        }
        return
    }
    line_length := StrPut(line, "UTF-8")
    line_buff := Buffer(line_length)
    StrPut(line, line_buff, "UTF-8")
    res := DllCall(NumGet(api, 192, "Ptr"), "Int", session_id, "Ptr", line_buff.Ptr, "Cdecl") ; rime->simulate_key_sequence
    if res {
        PrintSession(session_id)
    } else {
        MsgBox("Error processing key sequence: " . line, "Error")
    }
}

rimeModule := DllCall("LoadLibrary", "Str", "rime.dll", "Ptr")
rimeReady := false

rimeApi := DllCall("rime\rime_get_api", "Cdecl Ptr")
; api_size := NumGet(rimeApi, 0, "Int")
; Print(api_size)

; sizeof(RimeTraits) = 96
traits := Buffer(96, 0) ; RimeTraits
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

DllCall(NumGet(rimeApi, 4, "Ptr"), "Ptr", traits, "Cdecl") ; rime->setup
DllCall(NumGet(rimeApi, 8, "Ptr"), "Ptr", CallbackCreate(NotificationHandler, "C", 4), "Ptr", 0, "Cdecl") ; rime->set_notification_handler

Print("initializing...")

DllCall(NumGet(rimeApi, 12, "Ptr"), "Ptr", 0, "Cdecl") ; rime->initialize
success := DllCall(NumGet(rimeApi, 20, "Ptr"), "Int", 1, "Cdecl") ; rime->start_maintenance

if success {
    DllCall(NumGet(rimeApi, 28, "Ptr"), "CDecl")
}

rimeReady := true
Print("ready.")

session_id := DllCall(NumGet(rimeApi, 56, "Ptr"), "Cdecl") ; rime->create_session
if not session_id {
    MsgBox("Error creating rime session.", "Error")
    Exit(1)
}

Main.Title := Main.Title . " (Session " . session_id . ")"

OnExit ExitRimeConsole

ExitRimeConsole(ExitReason, ExitCode) {
    DllCall(NumGet(rimeApi, 64, "Ptr"), "Int", session_id, "Cdecl") ; rime->destroy_session
    DllCall(NumGet(rimeApi, 16, "Ptr"), "Cdecl") ; rime->finalize

    DllCall("FreeLibrary", "Ptr", rimeModule)
}
