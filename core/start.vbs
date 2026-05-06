Option Explicit
Dim fso, shellApp, currentDir, psArgs

' Create necessary objects
Set fso = CreateObject("Scripting.FileSystemObject")
Set shellApp = CreateObject("Shell.Application")

' Get the directory where this VBScript is located
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
' Construct the PowerShell arguments.
' Launching elevated directly from VBS avoids the brief console flash that can
' happen when a hidden non-admin PowerShell relaunches itself with UAC.
psArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & chr(34) & currentDir & "\tray.ps1" & chr(34)

' Execute the PowerShell script with administrator privileges and keep it hidden.
shellApp.ShellExecute "powershell.exe", psArgs, currentDir, "runas", 0
