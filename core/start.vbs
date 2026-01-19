Option Explicit
Dim ws, fso, currentDir, psScript

' Create necessary objects
Set ws = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Get the directory where this VBScript is located
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
' Construct the full path to the PowerShell script
psScript = chr(34) & currentDir & "\tray.ps1" & chr(34)

' Execute the PowerShell script
' -WindowStyle Hidden: Prevents the PowerShell console from appearing.
' -ExecutionPolicy Bypass: Avoids script execution errors due to security policies.
' The second argument '0' in ws.Run also helps hide the window.
ws.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File " & psScript, 0, False
