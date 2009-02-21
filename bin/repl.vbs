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
                            fso.GetBaseName(WScript.ScriptFullName) & ".Log")
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

Sub PopupError
  PopupMessage Err.Number & ": " & Err.Description & " (" & Err.Source & ")", _
               vbOKOnly + vbCritical, POPUP_TITLE + ": Error"
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
    PopupError
  End If
End Sub

Sub REPL_Evaluate(expr)
  Dim result
  On Error Resume Next
  result = ShowValue(REPL_ScriptControl.Eval(expr))
  If Err.Number = 0 Then
    PopupResult expr, result
  Else
    PopupError
  End If
End Sub

Dim binDir: binDir = fso.GetParentFolderName(WScript.ScriptFullName)
Dim baseDir: baseDir = fso.GetParentFolderName(binDir)
Dim libDir: libDir = fso.BuildPath(baseDir, "lib")

Sub ImportFile(path)
  If Not fso.FileExists(path) Then
    Dim libPath
    libPath = fso.BuildPath(libDir, path)
    If Not fso.FileExists(libPath) Then
      PopupMessage "not found a file to import: " & path, _
                   vbOKOnly + vbCritical, POPUP_TITLE + ": Error"
      Exit Sub
    End If
    path = libPath
  End If

  On Error Resume Next
  REPL_ScriptControl.AddCode FileReadAll(path)
  If Err.Number <> 0 Then
    PopupError
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
importCommand.Pattern = "^@import\s+"
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
    expr = importCommand.Replace(expr, "")
    ImportFile expr
  Else
    REPL_Execute expr
  End If
Loop

' Local Variables:
' mode: Visual-Basic
' indent-tabs-mode: nil
' End:
