# ==========================================
#        Singbox Tray Core Logic
# ==========================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Kill previous tray instances to prevent duplicates ---
$CurrentPID = $PID
try {
    Get-WmiObject Win32_Process | Where-Object { 
        $_.Name -match 'powershell' -and 
        $_.CommandLine -like '*SingboxTray\core\tray.ps1*' -and 
        $_.ProcessId -ne $CurrentPID 
    } | ForEach-Object { 
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue 
    }
} catch {}

# --- Path Configuration ---
$CurrentDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SingboxExe   = Join-Path $CurrentDir "sing-box.exe"
$SingboxConf  = Join-Path $CurrentDir "windows.json"
$WebUIUrl     = "http://127.0.0.1:9090/ui/"

# --- Pre-flight Checks ---
if (-not (Test-Path $SingboxExe)) {
    [System.Windows.Forms.MessageBox]::Show("错误: 'sing-box.exe' 不存在！`n请将 sing-box.exe 放置于 'core' 文件夹内。", "Singbox Tray", "OK", "Error")
    exit
}
if (-not (Test-Path $SingboxConf)) {
    [System.Windows.Forms.MessageBox]::Show("错误: 'windows.json' 配置文件不存在！`n请将您的配置文件放置于 'core' 文件夹内。", "Singbox Tray", "OK", "Error")
    exit
}

# --- Function: Stop Sing-box ---
function Stop-Singbox {
    # Gracefully stop sing-box process
    Stop-Process -Name "sing-box" -Force -ErrorAction SilentlyContinue
    # Also kill the terminal host if it's lingering
    $conhost = Get-Process | Where-Object { $_.ProcessName -eq "conhost" -and $_.MainWindowTitle -like "*sing-box.exe*" }
    if ($conhost) {
        Stop-Process -Id $conhost.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 200
}

# --- Function: Start Sing-box ---
function Start-Singbox {
    # Check if process is already running before starting a new one
    $existingProcess = Get-Process -Name "sing-box" -ErrorAction SilentlyContinue
    if (-not $existingProcess) {
        $ArgList = @(
            "run", "-c", "$SingboxConf"
        )
        # Use -WindowStyle Hidden to prevent console window from appearing
        Start-Process -FilePath $SingboxExe -ArgumentList $ArgList -WindowStyle Hidden
    }
}

# --- System Tray Icon ---
$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($SingboxExe)
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = $Icon
$NotifyIcon.Text = "Singbox Tray"
$NotifyIcon.Visible = $true

# --- Context Menu (Right-click menu) ---
$ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$MenuItemOpenUI = $ContextMenu.Items.Add("打开控制面板 (Open UI)")
$MenuItemOpenUI.Add_Click({
    Start-Process $WebUIUrl
})

$ContextMenu.Items.Add("-") | Out-Null # Separator

$MenuItemRestart = $ContextMenu.Items.Add("重启服务 (Restart)")
$MenuItemRestart.Add_Click({
    Stop-Singbox
    Start-Singbox
    $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "服务已重启", [System.Windows.Forms.ToolTipIcon]::Info)
})

$ContextMenu.Items.Add("-") | Out-Null # Separator

$MenuItemExit = $ContextMenu.Items.Add("退出 (Exit)")
$MenuItemExit.Add_Click({
    Stop-Singbox
    $NotifyIcon.Visible = $false
    $NotifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
    exit # Ensure the PowerShell script itself closes
})

$NotifyIcon.ContextMenuStrip = $ContextMenu

# --- Double-Click Action ---
$NotifyIcon.Add_DoubleClick({
    Start-Process $WebUIUrl
})

# --- Main Execution ---
# 1. Clean up any old instances
Stop-Singbox
# 2. Start a fresh instance
Start-Singbox
# 3. Show a startup notification
$NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "Singbox 服务已启动", [System.Windows.Forms.ToolTipIcon]::Info)
# 4. Keep the tray icon alive
[System.Windows.Forms.Application]::Run()
