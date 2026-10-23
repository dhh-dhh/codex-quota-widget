function ConvertTo-HardwareSnapshot {
    param([double]$TotalKB, [double]$FreeKB, [string]$GpuCsv)
    $memoryPercent = $null; $usedGB = $null; $totalGB = $null
    if ($TotalKB -gt 0 -and $FreeKB -ge 0 -and $FreeKB -le $TotalKB) {
        $memoryPercent = [math]::Round(100 * ($TotalKB - $FreeKB) / $TotalKB)
        $usedGB = [math]::Round(($TotalKB - $FreeKB) / 1MB, 1)
        $totalGB = [math]::Round($TotalKB / 1MB, 1)
    }
    $gpus = @(foreach ($line in ($GpuCsv -split '\r?\n')) {
        if ($line -match '^(.+),\s*([^,]+)$') {
            $name = $Matches[1].Trim(); $raw = $Matches[2].Trim()
            $value = 0.0; $percent = $null
            if ([double]::TryParse($raw, [ref]$value) -and $value -ge 0 -and $value -le 100) {
                $percent = [math]::Round($value)
            }
            [pscustomobject]@{ name = $name; percent = $percent }
        }
    })
    [pscustomobject]@{ memoryPercent = $memoryPercent; usedGB = $usedGB; totalGB = $totalGB; gpus = $gpus }
}

function Get-HardwareSnapshot {
    $total = 0; $free = 0; $csv = ''
    try {
        $os = Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 2 -ErrorAction Stop
        $total = $os.TotalVisibleMemorySize; $free = $os.FreePhysicalMemory
    } catch {}
    $smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($smi) {
        $process = New-Object Diagnostics.Process
        $process.StartInfo.FileName = $smi.Source
        $process.StartInfo.Arguments = '--query-gpu=name,utilization.gpu --format=csv,noheader,nounits'
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        try {
            [void]$process.Start()
            $output = $process.StandardOutput.ReadToEndAsync()
            $errors = $process.StandardError.ReadToEndAsync()
            if ($process.WaitForExit(1500)) {
                if ($process.ExitCode -eq 0) { $csv = $output.GetAwaiter().GetResult() }
            } else { $process.Kill(); $process.WaitForExit() }
        } catch {} finally { $process.Dispose() }
    }
    ConvertTo-HardwareSnapshot -TotalKB $total -FreeKB $free -GpuCsv $csv
}
