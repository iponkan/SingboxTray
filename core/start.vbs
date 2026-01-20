Option Explicit
Dim fso, currentDir, psScript

' Create necessary objects
Set fso = CreateObject("Scripting.FileSystemObject")

' Get the directory where this VBScript is located
currentDir = fso.GetParentFolderName(WScript.ScriptFullName)
' Construct the full path to the PowerShell script
psScript = "-WindowStyle Hidden -ExecutionPolicy Bypass -File " & chr(34) & currentDir & "\tray.ps1" & chr(34)

' Execute the PowerShell script with administrator privileges
' Changed the last parameter from 1 (SW_SHOWNORMAL) to 0 (SW_HIDE) to prevent window flashing
CreateObject("Shell.Application").ShellExecute "powershell.exe", psScript, currentDir, "runas", 0