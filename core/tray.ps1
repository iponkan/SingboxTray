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
$UrlConfFile  = Join-Path $CurrentDir "url.conf"
$WebUIUrl     = "http://127.0.0.1:9090/ui/"

# --- Pre-flight Checks ---
if (-not (Test-Path $SingboxExe)) {
    [System.Windows.Forms.MessageBox]::Show("错误: 'sing-box.exe' 不存在！`n请将 sing-box.exe 放置于 'core' 文件夹内。", "Singbox Tray", "OK", "Error")
    exit
}

# --- Function: Update Configuration ---
function Update-Config {
    if (-not (Test-Path $UrlConfFile)) {
        $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "未找到订阅链接文件，请先在 .bat 文件中设置。", [System.Windows.Forms.ToolTipIcon]::Warning)
        return
    }
    
    $ConfigUrl = (Get-Content $UrlConfFile -ErrorAction SilentlyContinue).Trim()

    if ([string]::IsNullOrWhiteSpace($ConfigUrl)) {
        $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "订阅链接为空，请在 .bat 文件中重新设置。", [System.Windows.Forms.ToolTipIcon]::Warning)
        return
    }

    $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "正在更新订阅...", [System.Windows.Forms.ToolTipIcon]::Info)
    try {
        Invoke-WebRequest -Uri $ConfigUrl -OutFile $SingboxConf -UseBasicParsing
        $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "订阅更新成功！", [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {
        $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "订阅更新失败！请检查链接或网络。", [System.Windows.Forms.ToolTipIcon]::Error)
        $_.Exception.Message | Out-File -FilePath (Join-Path $CurrentDir "error.log") -Append
    }
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
    # Check if config file exists after attempting download
    if (-not (Test-Path $SingboxConf)) {
        [System.Windows.Forms.MessageBox]::Show("错误: 'windows.json' 配置文件不存在！`n请先更新订阅或手动放置配置文件。", "Singbox Tray", "OK", "Error")
        return # Stop execution if config is missing
    }
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

# [NEW] Update Subscription Item
$MenuItemUpdate = $ContextMenu.Items.Add("更新订阅并重启 (Update Subscription)")
$MenuItemUpdate.Add_Click({
    Stop-Singbox
    Update-Config
    Start-Singbox
    # Note: Balloon tip is already handled inside Update-Config and Start-Singbox logic mainly, 
    # but we can add a completion message here if needed.
})

# [MODIFIED] Restart Service (Now only restarts, does not update)
$MenuItemRestart = $ContextMenu.Items.Add("重启服务 (Restart Service)")
$MenuItemRestart.Add_Click({
    Stop-Singbox
    # Removed Update-Config from here based on user request
    Start-Singbox
    $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "服务已重启 (使用本地配置)", [System.Windows.Forms.ToolTipIcon]::Info)
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

# 2. Update config ONLY if it doesn't exist
if (-not (Test-Path $SingboxConf)) {
    Update-Config
}

# 3. Start a fresh instance
Start-Singbox

# 4. Show a startup notification
$NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "Singbox 服务已启动", [System.Windows.Forms.ToolTipIcon]::Info)

# 5. Keep the tray icon alive
[System.Windows.Forms.Application]::Run()