# ==========================================
#      Singbox Tray (Debug Version)
# ==========================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- 配置日志文件路径 ---
$CurrentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $CurrentDir "debug.log"

# --- 日志函数 ---
function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    $LogEntry | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# 清空旧日志，开始新记录
"" | Out-File -FilePath $LogFile -Encoding utf8
Write-Log "=== 脚本启动 ==="
Write-Log "工作目录: $CurrentDir"

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
$SingboxExe   = Join-Path $CurrentDir "sing-box.exe"
$SingboxConf  = Join-Path $CurrentDir "windows.json"
$UrlConfFile  = Join-Path $CurrentDir "url.conf"
$WebUIUrl     = "http://127.0.0.1:9090/ui/"

# --- 检查 sing-box.exe ---
if (-not (Test-Path $SingboxExe)) {
    Write-Log "致命错误: 找不到 sing-box.exe"
    [System.Windows.Forms.MessageBox]::Show("错误: 'sing-box.exe' 不存在！", "Singbox Tray", "OK", "Error")
    exit
}

# --- 函数: 更新配置 ---
function Update-Config {
    Write-Log "--- 开始执行 Update-Config ---"
    
    if (-not (Test-Path $UrlConfFile)) {
        Write-Log "错误: 找不到 url.conf 文件"
        [System.Windows.Forms.MessageBox]::Show("未找到 'url.conf'！请先运行 bat 设置链接。", "缺少配置", "OK", "Warning")
        return
    }
    
    # 读取 URL 并记录详细信息（长度等，排查看不见的字符）
    $RawUrl = Get-Content $UrlConfFile -ErrorAction SilentlyContinue | Out-String
    $ConfigUrl = $RawUrl.Trim()
    
    Write-Log "读取到的 URL 长度: $($ConfigUrl.Length)"
    if ($ConfigUrl.Length -gt 5) {
        Write-Log "URL 前5位: $($ConfigUrl.Substring(0,5))..."
    } else {
        Write-Log "URL 似乎为空或过短"
    }

    if ([string]::IsNullOrWhiteSpace($ConfigUrl)) {
        Write-Log "错误: URL 为空"
        return
    }

    $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "正在下载订阅...", [System.Windows.Forms.ToolTipIcon]::Info)
    
    try {
        Write-Log "正在尝试下载... (Timeout: 30s)"
        # 伪装 User-Agent
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        Invoke-WebRequest -Uri $ConfigUrl -OutFile $SingboxConf -UseBasicParsing -UserAgent $UserAgent -TimeoutSec 30
        
        # 验证文件
        if (Test-Path $SingboxConf) {
            $FileSize = (Get-Item $SingboxConf).Length
            Write-Log "下载完成。文件大小: $FileSize 字节"
            
            if ($FileSize -lt 100) {
                Write-Log "警告: 文件太小，可能是错误页面"
                throw "下载的文件太小 ($FileSize bytes)，可能是无效的订阅链接。"
            }
            $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "订阅更新成功！", [System.Windows.Forms.ToolTipIcon]::Info)
        } else {
            throw "下载命令执行完了，但找不到目标文件。"
        }
    } catch {
        # 详细记录错误堆栈
        Write-Log "!!! 下载失败 !!!"
        Write-Log "错误信息: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Log "内部错误: $($_.Exception.InnerException.Message)"
        }
        if ($_.Exception.Response) {
            Write-Log "HTTP 状态码: $($_.Exception.Response.StatusCode.value__)"
        }
        
        [System.Windows.Forms.MessageBox]::Show("订阅下载失败！`n`n查看 core/debug.log 获取详情。", "更新失败", "OK", "Error")
    }
    Write-Log "--- Update-Config 结束 ---"
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
        $NotifyIcon.ShowBalloonTip(3000, "Singbox Tray", "等待配置文件... 请右键更新。", [System.Windows.Forms.ToolTipIcon]::Warning)
        return 
    }
    
    $existingProcess = Get-Process -Name "sing-box" -ErrorAction SilentlyContinue
    if (-not $existingProcess) {
        $ArgList = @("run", "-c", "$SingboxConf")
        Start-Process -FilePath $SingboxExe -ArgumentList $ArgList -WindowStyle Hidden
        Write-Log "Singbox 进程已启动"
    } else {
        Write-Log "Singbox 进程已在运行中"
    }
}

# --- 托盘图标设置 ---
$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($SingboxExe)
$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$NotifyIcon.Icon = $Icon
$NotifyIcon.Text = "Singbox Tray (Debug)"
$NotifyIcon.Visible = $true

# --- 右键菜单 ---
$ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$MenuItemOpenUI = $ContextMenu.Items.Add("打开控制面板")
$MenuItemOpenUI.Add_Click({ Start-Process $WebUIUrl })

$ContextMenu.Items.Add("-") | Out-Null

$MenuItemUpdate = $ContextMenu.Items.Add("更新订阅并重启")
$MenuItemUpdate.Add_Click({
    Write-Log "用户点击了: 更新订阅并重启"
    Stop-Singbox
    Update-Config
    Start-Singbox
})

$MenuItemRestart = $ContextMenu.Items.Add("仅重启服务")
$MenuItemRestart.Add_Click({
    Write-Log "用户点击了: 仅重启服务"
    Stop-Singbox
    Start-Singbox
    $NotifyIcon.ShowBalloonTip(1000, "Singbox Tray", "服务已重启", [System.Windows.Forms.ToolTipIcon]::Info)
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
    Write-Log "主流程: 配置文件不存在，尝试下载"
    Update-Config
} else {
    Write-Log "主流程: 配置文件已存在，跳过自动下载"
}

Start-Singbox
[System.Windows.Forms.Application]::Run()