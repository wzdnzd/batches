' remove-edge.vbs
' Silent launcher for remove-edge.ps1 (same role as remove-edge.cmd).
'
' Designed for Task Scheduler: no console window, no MsgBox.
' Double-clicking this file also runs hidden.
'
' Default (no extra arguments): -Apply
' Pass any remove-edge.ps1 arguments after the .vbs path to override.
' Dry-run example:
'   wscript.exe //B "<path>\msedge-manager\remove-edge.vbs" -Mode Remove
'
' Task Scheduler (create from an elevated prompt):
'   Program/script:  wscript.exe
'   Add arguments:   //B "<path>\msedge-manager\remove-edge.vbs"
'   Start in:        <path>\msedge-manager
'   Run with highest privileges: YES
'   Run as the interactive user (not SYSTEM) so HKCU cleanup hits your profile.
'
'   schtasks /Create /TN "msedge-manager\RemoveEdgeKeepWebView2" /TR "wscript.exe //B \"<path>\msedge-manager\remove-edge.vbs\"" /SC DAILY /ST 03:30 /RL HIGHEST /F
'
' Logs: EdgeRemovalLogs\remove-edge-yyyyMMdd-HHmmss.log (kept 30 days)

Option Explicit

Const WINDOW_HIDDEN = 0
Const WAIT_ON_RETURN = True
Const LOG_KEEP_DAYS = 1
Const ForAppending = 8

Dim fso, sh, scriptDir, ps1Path, logDir, logPath, argLine, cmd, rc, psExe

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path   = fso.BuildPath(scriptDir, "remove-edge.ps1")

If Not fso.FileExists(ps1Path) Then
  WScript.Quit 1
End If

logDir = fso.BuildPath(scriptDir, "EdgeRemovalLogs")
logPath = ""
On Error Resume Next
If Not fso.FolderExists(logDir) Then fso.CreateFolder logDir
If fso.FolderExists(logDir) Then
  logPath = fso.BuildPath(logDir, "remove-edge-" & TimeStamp() & ".log")
End If
On Error GoTo 0

argLine = BuildArgLine()
If logPath <> "" Then
  If Not HasSwitch("-LogPath") Then
    argLine = Trim(argLine & " -LogPath " & QuoteWin(logPath))
  End If
  AppendLog logPath, "==== remove-edge start " & Now & " ===="
  AppendLog logPath, "Script: " & ps1Path
  AppendLog logPath, "Arguments: " & argLine
  AppendLog logPath, ""
End If

sh.CurrentDirectory = scriptDir

' Resolve powershell.exe dynamically from PATH. Use the first existing result.
' Run where.exe from System32 so the script's own directory is not searched first.
' This avoids relying on a hard-coded PowerShell installation directory.
psExe = FindPowerShellExe()
If psExe = "" Then
  If logPath <> "" Then AppendLog logPath, "ERROR: unable to locate powershell.exe via PATH (where.exe)."
  WScript.Quit 2
End If

If logPath <> "" Then AppendLog logPath, "PowerShell executable: " & psExe

' Output is written by remove-edge.ps1 -LogPath (Start-Transcript cannot capture
' Write-Host in a hidden / non-interactive host, and can hang the process).
cmd = QuoteWin(psExe) & " -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
      QuoteWin(ps1Path) & " " & argLine

rc = sh.Run(cmd, WINDOW_HIDDEN, WAIT_ON_RETURN)

If logPath <> "" Then
  AppendLog logPath, ""
  AppendLog logPath, "==== wrapper exit=" & rc & " " & Now & " ===="
End If

On Error Resume Next
If logDir <> "" Then PruneOldLogs logDir, LOG_KEEP_DAYS
On Error GoTo 0

WScript.Quit rc

Function FindPowerShellExe()
  Dim whereExe, previousDir, proc, output, lines, candidate, i

  FindPowerShellExe = ""
  whereExe = sh.ExpandEnvironmentStrings("%SystemRoot%\System32\where.exe")
  If Not fso.FileExists(whereExe) Then Exit Function

  previousDir = sh.CurrentDirectory
  On Error Resume Next

  ' where.exe searches its current directory before PATH. Use System32 as a
  ' neutral working directory so a powershell.exe next to this VBS cannot win.
  sh.CurrentDirectory = sh.ExpandEnvironmentStrings("%SystemRoot%\System32")
  Err.Clear
  Set proc = sh.Exec(QuoteWin(whereExe) & " powershell.exe")

  If Err.Number = 0 Then
    If IsObject(proc) Then
      output = proc.StdOut.ReadAll
      lines = Split(Replace(output, vbCr, ""), vbLf)

      For i = 0 To UBound(lines)
        candidate = Trim(lines(i))
        If Len(candidate) > 0 Then
          ' where.exe normally returns fully-qualified paths. Verify the result
          ' before returning it, and normalize it to an absolute path.
          If fso.FileExists(candidate) Then
            FindPowerShellExe = fso.GetAbsolutePathName(candidate)
            Exit For
          End If
        End If
      Next
    End If
  End If

  ' Restore the launcher's original working directory even if where.exe fails.
  Err.Clear
  sh.CurrentDirectory = previousDir
  On Error GoTo 0
End Function

Function BuildArgLine()
  Dim i, a, parts
  If WScript.Arguments.Count = 0 Then
    BuildArgLine = "-Apply"
    Exit Function
  End If
  parts = ""
  For i = 0 To WScript.Arguments.Count - 1
    a = WScript.Arguments(i)
    If IsPsSwitch(a) Then
      parts = parts & " " & a
    Else
      parts = parts & " " & QuoteWin(a)
    End If
  Next
  BuildArgLine = Trim(parts)
End Function

Function HasSwitch(ByVal name)
  Dim i
  For i = 0 To WScript.Arguments.Count - 1
    If LCase(WScript.Arguments(i)) = LCase(name) Then
      HasSwitch = True
      Exit Function
    End If
  Next
  HasSwitch = False
End Function

Function IsPsSwitch(ByVal s)
  If Len(s) >= 2 And Left(s, 1) = "-" And InStr(s, " ") = 0 Then
    IsPsSwitch = True
  Else
    IsPsSwitch = False
  End If
End Function

Function QuoteWin(ByVal s)
  QuoteWin = """" & Replace(s, """", """""") & """"
End Function

Sub AppendLog(ByVal path, ByVal text)
  Dim ts
  On Error Resume Next
  Set ts = fso.OpenTextFile(path, ForAppending, True)
  If Err.Number = 0 Then
    ts.WriteLine text
    ts.Close
  End If
  On Error GoTo 0
End Sub

Function TimeStamp()
  Dim d
  d = Now
  TimeStamp = Year(d) _
    & Right("0" & Month(d), 2) _
    & Right("0" & Day(d), 2) _
    & "-" _
    & Right("0" & Hour(d), 2) _
    & Right("0" & Minute(d), 2) _
    & Right("0" & Second(d), 2)
End Function

Sub PruneOldLogs(ByVal folderPath, ByVal days)
  Dim folder, f
  If Not fso.FolderExists(folderPath) Then Exit Sub
  Set folder = fso.GetFolder(folderPath)
  For Each f In folder.Files
    If LCase(fso.GetExtensionName(f.Name)) = "log" Then
      If DateDiff("d", f.DateLastModified, Now) > days Then
        f.Delete True
      End If
    End If
  Next
End Sub
