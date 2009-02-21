'Read Eval Print Loop

Option Explicit

Dim ShowString_Quote
Set ShowString_Quote = New RegExp
ShowString_Quote.Pattern = """"
ShowString_Quote.Global = True

Function ShowString(value)
  ShowString = """" & ShowString_Quote.Replace(value, """""") & """"
End Function

Function ShowArray(value)
  Dim r, i, sep: sep = ""
  r = "["
  For Each i In value
    r = r & sep & ShowValue(i)
    sep = ","
  Next
  r = r & "]"
  ShowArray = r
End Function

Function ShowDictionary(value)
  Dim r, k, sep: sep = ""
  r = "{"
  For Each k In value.Keys
    r = r & sep & ShowValue(k) & "=>" & ShowValue(value(k))
    sep = ","
  Next
  r = r & "}"
  ShowDictionary = r
End Function

Function ShowObject(value)
  On Error Resume Next
  Dim r
  r = ShowDictionary(value)
  If Err.Number <> 0 Then
    Err.Clear
    r = ShowArray(value)
  End If
  If Err.Number <> 0 Then
    Err.Clear
    r = ShowArray(value.Items)
  End If
  If Err.Number <> 0 Then
    Err.Clear
    r = "<" & TypeName(value) & ">"
  End If
  ShowObject = r
End Function

Function ShowOther(value)
  On Error Resume Next
  Dim r
  r = CStr(value)
  If Err.Number <> 0 Then
    Err.Clear
    r = ShowArray(value)
  End If
  If Err.Number <> 0 Then
    Err.Clear
    r = ShowDictionary(value)
  End If
  If Err.Number <> 0 Then
    Err.Clear
    r = "<unknown:" & VarType(value) & ">"
  End If
  ShowOther = r
End Function

Function ShowValue(value)
  Dim r
  If VarType(value) = vbString Then
    r = ShowString(value)
  ElseIf IsArray(value) Then
    r = ShowArray(value)
  ElseIf IsObject(value) Then
    r = ShowObject(value)
  ElseIf IsEmpty(value) Then
    r = "<empty>"
  ElseIf IsNull(value) Then
    r = "<null>"
  Else
    r = ShowOther(value)
  End If
  ShowValue = r
End Function

Const MAX_HISTORY = 30

Class History
  Private dict
  Private firstIndex
  Private lastIndex
  Private maxHistory

  Public Sub Class_Initialize
    Set dict = CreateObject("Scripting.Dictionary")
    firstIndex = 0
    lastIndex = 0
    maxHistory = MAX_HISTORY
  End Sub

  Public Property Get NextIndex
    NextIndex = lastIndex
  End Property

  Public Sub Add(expr)
    dict(lastIndex) = expr
    lastIndex = lastIndex + 1

    Do While dict.Count > maxHistory
      dict.Remove firstIndex
      firstIndex = firstIndex + 1
    Loop
  End Sub

  Public Default Property Get Item(index)
    If dict.Exists(index) Then
      Item = dict(index)
    End If
  End Property

  Public Function Exists(index)
    Exists = dict.Exists(index)
  End Function

  Public Function Keys
    ReDim KeyList(dict.Count - 1)

    Dim i
    For i = 0 To dict.Count - 1
      KeyList(i) = firstIndex + i
    Next

    Keys = KeyList
  End Function
End Class

Class FileOpenDialog
  Private ivar_ie

  Private Sub Class_Initialize
    Set ivar_ie = CreateObject("InternetExplorer.Application")
    ivar_ie.MenuBar = False
    ivar_ie.AddressBar = False
    ivar_ie.ToolBar = False
    ivar_ie.StatusBar = False
    ivar_ie.Navigate "abount:blank"
    'ivar_ie.Visible = True              ' why once on invisible?
    WaitReadyStateComplete
    ivar_ie.document.Write "<html><body></body></html>"
  End Sub

  Private Sub Class_Terminate
    ivar_ie.Quit
    Set ivar_ie = Nothing
  End Sub

  Private Sub WaitReadyStateComplete
    Do While ivar_ie.Busy And ivar_ie.ReadyState <> 4
      WScript.Sleep 10
    Loop
  End Sub

  Public Function GetFilePath
    ivar_ie.document.body.innerHTML = "<input type='file' id='FileOpenDialog' />"
    ivar_ie.document.getElementById("FileOpenDialog").Click
    Dim path: path = ivar_ie.Document.getElementById("FileOpenDialog").Value
    If Len(path) > 0 Then
      GetFilePath = path
    End If
  End Function
End Class

Function InputFileOpenDialog
  Dim dialog
  Set dialog = New FileOpenDialog
  InputFileOpenDialog = dialog.GetFilePath
End Function

Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")

Const ForReading = 1, ForWriting = 2, ForAppending = 8

Function FileReadAll(path)
  Dim stream
  Set stream = fso.OpenTextFile(path)
  FileReadAll = stream.ReadAll
  stream.Close
End Function

Dim logFilename, logStream
logFilename = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), _
                            fso.GetBaseName(WScript.ScriptFullName) & ".log")
Set logStream = fso.OpenTextFile(logFilename, ForAppending, True)

Const POPUP_TITLE = "Read Eval Print Loop"

Sub PopupMessage(prompt, buttons, title)
  logStream.WriteLine Now
  logStream.WriteLine "[ " & title & " ]"
  logStream.WriteLine prompt
  logStream.WriteBlankLines 1

  MsgBox prompt, buttons, title
End Sub

Function PopupInputBox(prompt, title, default)
  Dim s
  s = InputBox(prompt, title, default)

  logStream.WriteLine Now
  logStream.WriteLine "[ " & title & " ]"
  logStream.WriteLine prompt
  logStream.WriteLine "input: " & ShowValue(s)
  logStream.WriteBlankLines 1

  PopupInputBox = s
End Function

Sub PopupError(title)
  PopupMessage Err.Number & ": " & Err.Description & " (" & Err.Source & ")", _
               vbOKOnly + vbCritical, POPUP_TITLE + ": " & title
End Sub

Sub PopupResult(expr, result)
  PopupMessage expr & vbNewLine & "=> " & result, _
               vbOKOnly, POPUP_TITLE & ": Result"
End Sub

Sub PopupHistory(hist)
  Dim i, text, sep
  For Each i In hist.Keys
    text = text & sep & i & ": " & hist(i)
    sep = vbNewLine
  Next
  PopupMessage text, vbOKOnly + vbInformation, POPUP_TITLE & ": History"
End Sub

Function GetHistory(hist, indexExpr)
  Dim index
  On Error Resume Next
  index = CInt(indexExpr)
  If Err.Number = 0 Then
    If hist.Exists(index) Then
      GetHistory = hist(index)
      Exit Function
    End If
  End If
  GetHistory = Empty
End Function

Dim REPL_ScriptControl
Set REPL_ScriptControl = CreateObject("ScriptControl")
REPL_ScriptControl.Language = "VBScript"
REPL_ScriptControl.AddObject "WScript", WScript

Sub REPL_Execute(expr)
  On Error Resume Next
  REPL_ScriptControl.ExecuteStatement expr
  If Err.Number <> 0 Then
    PopupError("Statement Error")
  End If
End Sub

Sub REPL_Evaluate(expr)
  Dim result
  On Error Resume Next
  result = ShowValue(REPL_ScriptControl.Eval(expr))
  If Err.Number = 0 Then
    PopupResult expr, result
  Else
    PopupError("Expression Error")
  End If
End Sub

Sub ImportFile(path)
  If IsEmpty(path) Then
    path = InputFileOpenDialog
  End If
  If Not IsEmpty(path) Then
    On Error Resume Next
    REPL_ScriptControl.AddCode FileReadAll(path)
    If Err.Number <> 0 Then
      PopupError("Import Error")
    End If
  End If
End Sub

Dim execCommand
Set execCommand = New RegExp
execCommand.Pattern = "^e\s+"
execCommand.IgnoreCase = True

Dim evalCommand
Set evalCommand = New RegExp
evalCommand.Pattern = "^p\s+"
evalCommand.IgnoreCase = True

Dim histCommand
Set histCommand = New RegExp
histCommand.Pattern = "^h$|^hh$|^h\s+"
histCommand.IgnoreCase = True

Dim importCommand
Set importCommand = New RegExp
importCommand.Pattern = "^@import$|^@import\s+"
importCommand.IgnoreCase = True

Dim hist
Set hist = New History

Dim expr
Dim defaultExpr
defaultExpr = Empty

Do
  expr = PopupInputBox("Input `statement' or `e statement' or `p expression'. `h' for history.", _
                       POPUP_TITLE & " [" & hist.NextIndex & "]", _
                       defaultExpr)

  If IsEmpty(expr) Then
    Exit Do
  End If

  hist.Add expr
  defaultExpr = Empty

  If execCommand.Test(expr) Then
    expr = execCommand.Replace(expr, "")
    REPL_Execute expr
  ElseIf evalCommand.Test(expr) Then
    expr = evalCommand.Replace(expr, "")
    REPL_Evaluate expr
  ElseIf histCommand.Test(expr) Then
    Select Case LCase(expr)
      Case "h":
        PopupHistory(hist)
      Case "hh":
        defaultExpr = hist(hist.NextIndex - 2)
      Case Else:
        defaultExpr = GetHistory(hist, histCommand.Replace(expr, ""))
    End Select
  ElseIf importCommand.Test(expr) Then
    Select Case LCase(expr)
      Case "@import":
        ImportFile Empty
      Case Else:
        expr = importCommand.Replace(expr, "")
        ImportFile expr
    End Select
  Else
    REPL_Execute expr
  End If
Loop

' Local Variables:
' mode: Visual-Basic
' indent-tabs-mode: nil
' End:
