Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------
# Create the main window
# -----------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Server Performance Dashboard"
$form.Size = New-Object System.Drawing.Size(500, 550)
$form.StartPosition = "CenterScreen"

# ---- Labels ----
$cpuLabel = New-Object System.Windows.Forms.Label
$cpuLabel.Location = New-Object System.Drawing.Point(10, 20)
$cpuLabel.Size = New-Object System.Drawing.Size(460, 20)
$form.Controls.Add($cpuLabel)

$memLabel = New-Object System.Windows.Forms.Label
$memLabel.Location = New-Object System.Drawing.Point(10, 60)
$memLabel.Size = New-Object System.Drawing.Size(460, 20)
$form.Controls.Add($memLabel)

$diskLabel = New-Object System.Windows.Forms.Label
$diskLabel.Location = New-Object System.Drawing.Point(10, 100)
$diskLabel.Size = New-Object System.Drawing.Size(460, 20)
$form.Controls.Add($diskLabel)

$cpuProcLabel = New-Object System.Windows.Forms.Label
$cpuProcLabel.Location = New-Object System.Drawing.Point(10, 140)
$cpuProcLabel.Size = New-Object System.Drawing.Size(460, 100)
$cpuProcLabel.AutoSize = $false
$cpuProcLabel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$cpuProcLabel.Padding = 5
$form.Controls.Add($cpuProcLabel)

$memProcLabel = New-Object System.Windows.Forms.Label
$memProcLabel.Location = New-Object System.Drawing.Point(10, 250)
$memProcLabel.Size = New-Object System.Drawing.Size(460, 100)
$memProcLabel.AutoSize = $false
$memProcLabel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$memProcLabel.Padding = 5
$form.Controls.Add($memProcLabel)

$netLabel = New-Object System.Windows.Forms.Label
$netLabel.Location = New-Object System.Drawing.Point(10, 370)
$netLabel.Size = New-Object System.Drawing.Size(460, 40)
$form.Controls.Add($netLabel)

# ---- STOP BUTTON ----
$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = "STOP"
$stopButton.Size = New-Object System.Drawing.Size(100, 30)
$stopButton.Location = New-Object System.Drawing.Point(200, 450)
$stopButton.BackColor = "IndianRed"
$stopButton.ForeColor = "White"
$stopButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($stopButton)

# Stop button event
$stopButton.Add_Click({
    $timer.Stop()
    $form.Close()
})

# ---- Timer ----
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000  # Refresh every 3 seconds

$timer.Add_Tick({

    # ----- CPU -----
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $cpuLabel.Text = "Total CPU Usage: $([Math]::Round($cpu,2)) %"

    # ----- Memory -----
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMem = [Math]::Round($os.TotalVisibleMemorySize/1MB,2)
    $freeMem = [Math]::Round($os.FreePhysicalMemory/1MB,2)
    $usedMem = $totalMem - $freeMem
    $memPct = [Math]::Round(($usedMem/$totalMem)*100,2)
    $memLabel.Text = "Memory Usage: $usedMem GB / $totalMem GB ($memPct% used, Free: $freeMem GB)"

    # ----- Disk -----
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeDisk = [Math]::Round($disk.FreeSpace/1GB,2)
    $totalDisk = [Math]::Round($disk.Size/1GB,2)
    $usedDisk = $totalDisk - $freeDisk
    $diskPct = [Math]::Round(($usedDisk/$totalDisk)*100,2)
    $diskLabel.Text = "Disk (C:) Usage: $usedDisk GB / $totalDisk GB ($diskPct% used, Free: $freeDisk GB)"

    # ----- Top 5 processes by CPU -----
    $topCpu = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
    $cpuText = "Top 5 CPU Processes:`n"
    foreach ($proc in $topCpu) {
        $line = "$($proc.ProcessName) ($([Math]::Round($proc.CPU,2)) CPU)`n"
        $cpuText += $line
    }
    $cpuProcLabel.Text = $cpuText
    # Highlight high CPU (>20%) in red
    foreach ($proc in $topCpu) {
        if ($proc.CPU -gt 20) {
            $cpuProcLabel.ForeColor = [System.Drawing.Color]::Red
            break
        } else {
            $cpuProcLabel.ForeColor = [System.Drawing.Color]::Black
        }
    }

    # ----- Top 5 processes by Memory -----
    $topMem = Get-Process | Sort-Object WS -Descending | Select-Object -First 5
    $memText = "Top 5 Memory Processes:`n"
    foreach ($proc in $topMem) {
        $line = "$($proc.ProcessName) ($([Math]::Round($proc.WS/1MB,2)) MB)`n"
        $memText += $line
    }
    $memProcLabel.Text = $memText
    # Highlight high memory (>500 MB) in red
    foreach ($proc in $topMem) {
        if ($proc.WS/1MB -gt 500) {
            $memProcLabel.ForeColor = [System.Drawing.Color]::Red
            break
        } else {
            $memProcLabel.ForeColor = [System.Drawing.Color]::Black
        }
    }

    # ----- Network -----
    $net = Get-Counter "\Network Interface(*)\Bytes Sent/sec","\Network Interface(*)\Bytes Received/sec"
    $sent = [Math]::Round(($net.CounterSamples | ? {$_.Path -like "*Sent/sec"} | Measure-Object CookedValue -Sum).Sum/1KB,2)
    $received = [Math]::Round(($net.CounterSamples | ? {$_.Path -like "*Received/sec"} | Measure-Object CookedValue -Sum).Sum/1KB,2)
    $netLabel.Text = "Network: Upload: $sent KB/s  |  Download: $received KB/s"
})

$timer.Start()

# Display window
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()

