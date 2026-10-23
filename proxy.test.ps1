$ErrorActionPreference='Stop'
. "$PSScriptRoot\proxy-control.ps1"
function Assert-Proxy($condition,$message){if(-not $condition){throw $message}}
$on=Resolve-SystemProxyState -ProxyEnabled $true -Server '127.0.0.1:7897' -Port 7897 -ClashRunning $true
Assert-Proxy ($on.available -and $on.enabled) 'Current Clash proxy must be controllable and on'
$off=Resolve-SystemProxyState -ProxyEnabled $false -Server '127.0.0.1:7897' -Port 7897 -ClashRunning $true
Assert-Proxy ($off.available -and -not $off.enabled) 'Disabled proxy retains its configured endpoint'
$foreign=Resolve-SystemProxyState -ProxyEnabled $true -Server 'proxy.example.com:8080' -Port 7897 -ClashRunning $true
Assert-Proxy (-not $foreign.available) 'Another proxy must not be modified'
$wrongPort=Resolve-SystemProxyState -ProxyEnabled $true -Server '127.0.0.1:8888' -Port 7897 -ClashRunning $true
Assert-Proxy (-not $wrongPort.available) 'A different local proxy must not be modified'
$stopped=Resolve-SystemProxyState -ProxyEnabled $false -Server '127.0.0.1:7897' -Port 7897 -ClashRunning $false
Assert-Proxy (-not $stopped.available) 'Cannot enable a stopped Clash instance'
$guard=Resolve-SystemProxyState -ProxyEnabled $true -Server '127.0.0.1:7897' -Port 7897 -ClashRunning $true -Guard $true
Assert-Proxy (-not $guard.available) 'Guarded settings must be handled in Clash'
$pac=Resolve-SystemProxyState -ProxyEnabled $true -Server '127.0.0.1:7897' -Port 7897 -ClashRunning $true -PacUrl 'http://127.0.0.1/proxy.pac'
Assert-Proxy (-not $pac.available) 'Manual control must not silently override PAC'
$ipv4=Resolve-SystemProxyState -ProxyEnabled $true -Server 'http=127.0.0.1:7897;https=127.0.0.1:7897' -Port 7897 -ClashRunning $true
Assert-Proxy ($ipv4.available -and $ipv4.enabled) 'Per-protocol endpoint format must be recognized'
$mixed=Resolve-SystemProxyState -ProxyEnabled $true -Server 'http=127.0.0.1:7897;https=other.example:443' -Port 7897 -ClashRunning $true
Assert-Proxy (-not $mixed.available) 'Mixed endpoints must not be changed'
Write-Output 'Proxy checks passed (9 assertions).'
