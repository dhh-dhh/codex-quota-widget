function ConvertTo-NetworkRate($Previous,$Current,[double]$Seconds) {
 $upload=0.0;$download=0.0;$matched=0
 if($Seconds -le 0){return [pscustomobject]@{upload=$null;download=$null}}
 $lookup=@{};foreach($item in $Previous){$lookup[$item.id]=$item}
 foreach($item in $Current){
  $old=$lookup[$item.id]
  if($null -eq $old -or $item.sent -lt $old.sent -or $item.received -lt $old.received){continue}
  $upload+=([double]$item.sent-[double]$old.sent)/$Seconds
  $download+=([double]$item.received-[double]$old.received)/$Seconds;$matched++
 }
 if($matched -eq 0){return [pscustomobject]@{upload=$null;download=$null}}
 [pscustomobject]@{upload=$upload;download=$download}
}
function Format-NetworkSpeed($BytesPerSecond) {
 if($null -eq $BytesPerSecond -or $BytesPerSecond -lt 0){return '--'}
 $unit='KB/s';$value=$BytesPerSecond/1KB
 if($BytesPerSecond -ge 1GB){$unit='GB/s';$value=$BytesPerSecond/1GB}
 elseif($BytesPerSecond -ge 1MB){$unit='MB/s';$value=$BytesPerSecond/1MB}
 $value.ToString('0.#',[Globalization.CultureInfo]::InvariantCulture)+' '+$unit
}
function Get-NetworkSpeed {
 $now=[Diagnostics.Stopwatch]::GetTimestamp()/[double][Diagnostics.Stopwatch]::Frequency
 if($null -eq $script:networkAdaptersRefresh -or $now -ge $script:networkAdaptersRefresh){
  $script:physicalNetworkIds=$null
  try{
   $script:physicalNetworkIds=@(Get-NetAdapter -Physical -ErrorAction Stop | ForEach-Object {([string]$_.InterfaceGuid).Trim('{}').ToLowerInvariant()})
  }catch{}
  $script:networkAdaptersRefresh=$now+30
 }
 $current=@(foreach($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()){
  if($adapter.OperationalStatus -ne 'Up' -or $adapter.NetworkInterfaceType -in @('Loopback','Tunnel')){continue}
  if($null -ne $script:physicalNetworkIds){
   if($script:physicalNetworkIds -notcontains $adapter.Id.Trim('{}').ToLowerInvariant()){continue}
  }else{
   if($adapter.Description -match '(?i)virtual|vpn|tun|tap|clash|wireguard|hyper-v|vmware|virtualbox'){continue}
   if($adapter.NetworkInterfaceType -notin @('Ethernet','Wireless80211')){continue}
  }
  try{$stats=$adapter.GetIPStatistics();[pscustomobject]@{id=$adapter.Id;sent=$stats.BytesSent;received=$stats.BytesReceived}}catch{}
 })
 $sampleTime=[Diagnostics.Stopwatch]::GetTimestamp()/[double][Diagnostics.Stopwatch]::Frequency
 $rate=ConvertTo-NetworkRate $script:networkPrevious $current ($sampleTime-$script:networkSampleTime)
 $script:networkPrevious=$current;$script:networkSampleTime=$sampleTime
 [pscustomobject]@{upload=$rate.upload;download=$rate.download;uploadText=(Format-NetworkSpeed $rate.upload);downloadText=(Format-NetworkSpeed $rate.download)}
}
