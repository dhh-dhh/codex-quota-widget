$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\hardware.ps1"
function Assert-Equal($actual, $expected, $message) {
    if ($actual -ne $expected) { throw "$message : expected $expected, got $actual" }
}
$sample = ConvertTo-HardwareSnapshot -TotalKB 16777216 -FreeKB 4194304 -GpuCsv 'NVIDIA GeForce RTX 4060, 34'
Assert-Equal $sample.memoryPercent 75 'Used memory percentage'
Assert-Equal $sample.usedGB 12 'Used memory GB'
Assert-Equal $sample.totalGB 16 'Total memory GB'
Assert-Equal $sample.gpus[0].percent 34 'GPU utilization'
$sample = ConvertTo-HardwareSnapshot -TotalKB 16777216 -FreeKB 16777216 -GpuCsv "GPU A, 0`nGPU B, 100"
Assert-Equal $sample.memoryPercent 0 'Zero memory usage is valid'
Assert-Equal $sample.gpus.Count 2 'Multiple GPUs remain separate'
Assert-Equal $sample.gpus[0].percent 0 'Idle GPU is valid'
Assert-Equal $sample.gpus[1].percent 100 'Busy GPU is valid'
$sample = ConvertTo-HardwareSnapshot -TotalKB 0 -FreeKB 0 -GpuCsv "GPU A, [N/A]`nGPU B, 101"
Assert-Equal ($null -eq $sample.memoryPercent) $true 'Unavailable memory is unknown'
Assert-Equal ($null -eq $sample.gpus[0].percent) $true 'Unsupported GPU is unknown'
Assert-Equal ($null -eq $sample.gpus[1].percent) $true 'Invalid GPU percentage is unknown'
$sample = ConvertTo-HardwareSnapshot -TotalKB 16777216 -FreeKB 4194304 -GpuCsv ''
Assert-Equal $sample.memoryPercent 75 'GPU failure does not hide memory'
Assert-Equal $sample.gpus.Count 0 'Missing GPU is not zero utilization'
Write-Output 'Hardware checks passed (14 assertions).'
