$ErrorActionPreference='Stop'
. "$PSScriptRoot\network.ps1"
function Assert-Equal($Actual,$Expected,$Message){if($Actual -ne $Expected){throw "$Message : expected $Expected, got $Actual"}}
$before=@([pscustomobject]@{id='wifi';sent=1000;received=3000},[pscustomobject]@{id='ethernet';sent=500;received=900})
$after=@([pscustomobject]@{id='wifi';sent=3048;received=11192},[pscustomobject]@{id='ethernet';sent=2548;received=4996})
$rate=ConvertTo-NetworkRate $before $after 2
Assert-Equal $rate.upload 2048 'Upload uses byte delta divided by actual elapsed seconds'
Assert-Equal $rate.download 6144 'Download aggregates active physical adapters'
$rate=ConvertTo-NetworkRate $after $after 1
Assert-Equal $rate.upload 0 'Idle upload is valid zero'
Assert-Equal $rate.download 0 'Idle download is valid zero'
Assert-Equal ($null -eq (ConvertTo-NetworkRate @() $after 1).upload) $true 'First sample is unknown'
Assert-Equal ($null -eq (ConvertTo-NetworkRate $before $after 0).upload) $true 'Invalid elapsed time is unknown'
$rate=ConvertTo-NetworkRate $before @([pscustomobject]@{id='wifi';sent=1;received=2},[pscustomobject]@{id='new';sent=999999;received=999999}) 1
Assert-Equal ($null -eq $rate.upload) $true 'Reset and newly added adapters cannot create a speed spike'
Assert-Equal (Format-NetworkSpeed $null) '--' 'Unknown speed is distinct from zero'
Assert-Equal (Format-NetworkSpeed 0) '0 KB/s' 'Idle display'
Assert-Equal (Format-NetworkSpeed 1536) '1.5 KB/s' 'Kilobytes display'
Assert-Equal (Format-NetworkSpeed 1572864) '1.5 MB/s' 'Megabytes display'
Assert-Equal (Format-NetworkSpeed 2147483648) '2 GB/s' 'Gigabytes display'
Write-Output 'Network checks passed (12 assertions).'
