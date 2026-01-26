# ==========================================
#      Singbox Tray (Debug Version)
# ==========================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- 配置日志开关 ---
$EnableLogging = $false  # 如果需要排查问题，请改为 $true

# --- 配置日志文件路径 ---
$CurrentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $CurrentDir "debug.log"

# --- 日志函数 ---
function Write-Log {
    param([string]$Message)
    if (-not $EnableLogging) { return }
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    $LogEntry | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# 清空旧日志，开始新记录
if ($EnableLogging) {
    "" | Out-File -FilePath $LogFile -Encoding utf8
    Write-Log "=== 脚本启动 ==="
    Write-Log "工作目录: $CurrentDir"
}

# [强制启用 TLS 1.2]
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Write-Log "安全协议已设置为 TLS 1.2"

# --- 杀死旧进程 ---
$CurrentPID = $PID
try {
    Get-WmiObject Win32_Process | Where-Object { 
        $_.Name -match 'powershell' -and 
        $_.CommandLine -like '*SingboxTray\core\tray.ps1*' -and 
        $_.ProcessId -ne $CurrentPID 
    } | ForEach-Object { 
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue 
        Write-Log "已清理旧进程 ID: $($_.ProcessId)"
    }
} catch {
    Write-Log "清理旧进程时出错: $_"
}

# --- 路径配置 ---
Set-Location -Path $CurrentDir
Write-Log "已切换工作目录到: $(Get-Location)"

$SingboxExe   = Join-Path $CurrentDir "sing-box.exe"
$SingboxConf  = Join-Path $CurrentDir "windows.json"
$UrlConf      = Join-Path (Split-Path $CurrentDir -Parent) "url.conf"
$AppIcon      = Join-Path $CurrentDir "app.png"
$SingboxLog   = Join-Path $CurrentDir "sing-box.log"
$SingboxErr   = Join-Path $CurrentDir "sing-box.err"
$WebUIUrl     = "http://127.0.0.1:9090/ui/"

# --- 检查 sing-box.exe ---
if (-not (Test-Path $SingboxExe)) {
    Write-Log "致命错误: 找不到 sing-box.exe"
    [System.Windows.Forms.MessageBox]::Show("错误: 'sing-box.exe' 不存在！", "Singbox Tray", "OK", "Error")
    exit
}

# --- 函数: 下载配置文件 ---
function Download-Config {
    if (-not (Test-Path $UrlConf)) {
        Write-Log "错误: 找不到 url.conf"
        $NotifyIcon.ShowBalloonTip(3000, "Singbox Tray", "找不到 url.conf，请在项目根目录创建它并填入下载地址。", [System.Windows.Forms.ToolTipIcon]::Error)
        return $false
    }
    
    $DownloadUrl = (Get-Content $UrlConf -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
        Write-Log "错误: url.conf 为空"
        $NotifyIcon.ShowBalloonTip(3000, "Singbox Tray", "url.conf 内容为空，请填入下载地址。", [System.Windows.Forms.ToolTipIcon]::Warning)
        return $false
    }

    Write-Log "正在从 $DownloadUrl 下载配置文件..."
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $SingboxConf -ErrorAction Stop
        Write-Log "下载成功: $SingboxConf"
        return $true
    } catch {
        Write-Log "下载失败: $_"
        $NotifyIcon.ShowBalloonTip(3000, "Singbox Tray", "下载配置文件失败，请检查网络和 url.conf 中的地址。", [System.Windows.Forms.ToolTipIcon]::Error)
        return $false
    }
}

# --- 函数: 停止服务 ---
function Stop-Singbox {
    Write-Log "停止 Singbox 服务..."
    Stop-Process -Name "sing-box" -Force -ErrorAction SilentlyContinue
    $conhost = Get-Process | Where-Object { $_.ProcessName -eq "conhost" -and $_.MainWindowTitle -like "*sing-box.exe*" }
    if ($conhost) { Stop-Process -Id $conhost.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 200
}

# --- 函数: 启动服务 ---
function Start-Singbox {
    Write-Log "尝试启动 Singbox..."
    if (-not (Test-Path $SingboxConf)) {
        Write-Log "无法启动: 缺少 windows.json"
        $NotifyIcon.ShowBalloonTip(3000, "Singbox Tray", "缺少配置文件！请将 windows.json 放入 core 目录。", [System.Windows.Forms.ToolTipIcon]::Warning)
        return 
    }
    
    $existingProcess = Get-Process -Name "sing-box" -ErrorAction SilentlyContinue
    if (-not $existingProcess) {
        Write-Log "正在启动 sing-box.exe, 参数: run -c $SingboxConf"
        $ArgList = @("run", "-c", "$SingboxConf")
        # 使用 Start-Process 并在后台重定向输出
        try {
            if ($EnableLogging) {
                Start-Process -FilePath $SingboxExe -ArgumentList $ArgList -WindowStyle Hidden -WorkingDirectory $CurrentDir -RedirectStandardOutput $SingboxLog -RedirectStandardError $SingboxErr
            } else {
                Start-Process -FilePath $SingboxExe -ArgumentList $ArgList -WindowStyle Hidden -WorkingDirectory $CurrentDir
            }
            Write-Log "Singbox 启动命令已发出。"
            Start-Sleep -Seconds 1
            if (Get-Process -Name "sing-box" -ErrorAction SilentlyContinue) {
                Write-Log "Singbox 进程已成功运行。"
            } else {
                Write-Log "警告: Singbox 进程启动后立即退出，请检查 sing-box.err"
            }
        } catch {
            Write-Log "启动 Singbox 发生错误: $_"
        }
    } else {
        Write-Log "Singbox 进程已在运行中"
    }
}

# --- 托盘图标设置 ---
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$AppIco = Join-Path $CurrentDir "app.ico"

if (Test-Path $AppIco) {
    $NotifyIcon.Icon = New-Object System.Drawing.Icon($AppIco)
    Write-Log "已加载自定义图标 (ICO): $AppIco"
} elseif (Test-Path $AppIcon) {
    try {
        $Bitmap = [System.Drawing.Bitmap]::FromFile($AppIcon)
        $NotifyIcon.Icon = [System.Drawing.Icon]::FromHandle($Bitmap.GetHicon())
        Write-Log "已加载自定义图标 (PNG): $AppIcon"
    } catch {
        $NotifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($SingboxExe)
    }
} else {
    $NotifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($SingboxExe)
}
$NotifyIcon.Text = "Singbox Tray"
$NotifyIcon.Visible = $true

# --- 右键菜单 ---
$ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$MenuItemOpenUI = $ContextMenu.Items.Add("打开控制面板")
$MenuItemOpenUI.Add_Click({ Start-Process $WebUIUrl })

$ContextMenu.Items.Add("-") | Out-Null



$MenuItemRestart = $ContextMenu.Items.Add("重新启动")
$MenuItemRestart.Add_Click({
    Write-Log "用户点击了: 重新启动"
    $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "正在拉取配置并重启...", [System.Windows.Forms.ToolTipIcon]::Info)
    Stop-Singbox
    Download-Config | Out-Null
    Start-Singbox
})

$MenuItemExit = $ContextMenu.Items.Add("退出")
$MenuItemExit.Add_Click({
    Write-Log "用户点击了: 退出"
    Stop-Singbox
    $NotifyIcon.Visible = $false
    $NotifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
    exit 
})

$NotifyIcon.ContextMenuStrip = $ContextMenu
$NotifyIcon.Add_DoubleClick({ Start-Process $WebUIUrl })

# --- 主执行流程 ---
Stop-Singbox

if (-not (Test-Path $SingboxConf)) {
    Write-Log "主流程: 配置文件不存在，尝试下载..."
    Download-Config | Out-Null
}

if (-not (Test-Path $SingboxConf)) {
    Write-Log "主流程: 最终配置文件仍然不存在"
} else {
    Write-Log "主流程: 配置文件已就绪"
}

Start-Singbox
[System.Windows.Forms.Application]::Run()