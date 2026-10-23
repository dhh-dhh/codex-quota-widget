function Resolve-SystemProxyState {
 param([bool]$ProxyEnabled,[string]$Server,[int]$Port,[bool]$ClashRunning,[bool]$Guard=$false,[string]$PacUrl='')
 $matchesClash=$Port -ge 1 -and $Port -le 65535 -and -not [string]::IsNullOrWhiteSpace($Server)
 foreach($part in ($Server -split ';')){
  $address=($part -replace '^\s*(http|https|socks)\s*=\s*','').Trim()
  if($address -notin @("127.0.0.1:$Port","localhost:$Port","[::1]:$Port")){$matchesClash=$false}
 }
 $available=$matchesClash -and $ClashRunning -and -not $Guard -and [string]::IsNullOrWhiteSpace($PacUrl)
 $detail=if(-not $ClashRunning){'请先启动 Clash Verge'}elseif($Guard){'代理守卫开启，请在 Clash 中切换'}elseif($PacUrl){'当前使用 PAC，请在 Clash 中切换'}elseif(-not $matchesClash){'代理地址不匹配，请在 Clash 中设置'}elseif($ProxyEnabled){'Clash Verge · 已开启'}else{'Clash Verge · 已关闭'}
 [pscustomobject]@{available=$available;enabled=($ProxyEnabled -and $matchesClash);detail=$detail}
}

function Get-SystemProxyState {
 $configPath=Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'io.github.clash-verge-rev.clash-verge-rev\verge.yaml'
 if(-not (Test-Path -LiteralPath $configPath)){return [pscustomobject]@{available=$false;enabled=$false;detail='未找到 Clash Verge 配置'}}
 try{
  $config=Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 -ErrorAction Stop
  $port=0
  if($config -match '(?m)^verge_mixed_port:\s*(\d+)\s*$'){$port=[int]$Matches[1]}
  if($port -eq 0){
   $corePath=Join-Path (Split-Path $configPath) 'clash-verge.yaml'
   $core=Get-Content -LiteralPath $corePath -Raw -Encoding UTF8 -ErrorAction Stop
   if($core -match '(?m)^mixed-port:\s*(\d+)\s*$'){$port=[int]$Matches[1]}
  }
  $guard=$config -match '(?m)^enable_proxy_guard:\s*true\s*$'
  $registry=Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
  $running=@(Get-Process -Name clash-verge -ErrorAction SilentlyContinue).Count -gt 0
  Resolve-SystemProxyState -ProxyEnabled ($registry.ProxyEnable -eq 1) -Server $registry.ProxyServer -Port $port -ClashRunning $running -Guard $guard -PacUrl $registry.AutoConfigURL
 }catch{[pscustomobject]@{available=$false;enabled=$false;detail='无法读取系统代理状态'}}
}

function Initialize-ProxyNative {
 if('QuotaWidgetProxyNative' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class QuotaWidgetProxyNative {
 [StructLayout(LayoutKind.Explicit)] struct Value {
  [FieldOffset(0)] public int Flags;
  [FieldOffset(0)] public IntPtr Text;
  [FieldOffset(0)] public long Time;
 }
 [StructLayout(LayoutKind.Sequential)] struct Option {public int Id;public Value Value;}
 [StructLayout(LayoutKind.Sequential)] struct List {public int Size;public IntPtr Connection;public int Count;public int Error;public IntPtr Options;}
 [DllImport("wininet.dll",SetLastError=true)] static extern bool InternetQueryOption(IntPtr h,int option,ref List list,ref int size);
 [DllImport("wininet.dll",EntryPoint="InternetSetOptionW",SetLastError=true)] static extern bool SetOptions(IntPtr h,int option,ref List list,int size);
 [DllImport("wininet.dll",EntryPoint="InternetSetOptionW",SetLastError=true)] static extern bool Notify(IntPtr h,int option,IntPtr buffer,int size);
 public static void SetEnabled(bool enabled) {
  IntPtr memory=Marshal.AllocHGlobal(Marshal.SizeOf(typeof(Option)));
  try {
   var option=new Option {Id=1};
   Marshal.StructureToPtr(option,memory,false);
   var list=new List {Size=Marshal.SizeOf(typeof(List)),Count=1,Options=memory};
   int size=list.Size;
   if(!InternetQueryOption(IntPtr.Zero,75,ref list,ref size))throw new Win32Exception(Marshal.GetLastWin32Error());
   option=(Option)Marshal.PtrToStructure(memory,typeof(Option));
   // Preserve auto-detection and other flags; only change manual-proxy use.
   option.Value.Flags=(option.Value.Flags|1)&~2;
   if(enabled)option.Value.Flags|=2;
   Marshal.StructureToPtr(option,memory,false);
   if(!SetOptions(IntPtr.Zero,75,ref list,list.Size))throw new Win32Exception(Marshal.GetLastWin32Error());
   Notify(IntPtr.Zero,39,IntPtr.Zero,0);
   Notify(IntPtr.Zero,95,IntPtr.Zero,0);
   Notify(IntPtr.Zero,37,IntPtr.Zero,0);
  } finally {Marshal.FreeHGlobal(memory);}
 }
}
'@
}

function Set-SystemProxyEnabled([bool]$Enabled) {
 $before=Get-SystemProxyState
 if(-not $before.available){throw $before.detail}
 if($before.enabled -eq $Enabled){return $before}
 Initialize-ProxyNative
 try{
  [QuotaWidgetProxyNative]::SetEnabled($Enabled)
  $after=Get-SystemProxyState
  if(-not $after.available -or $after.enabled -ne $Enabled){throw '系统未应用代理设置'}
  return $after
 }catch{
  try{[QuotaWidgetProxyNative]::SetEnabled($before.enabled)}catch{}
  throw '系统代理切换失败，已尝试恢复原状态'
 }
}
