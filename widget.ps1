param([switch]$SmokeTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$base=$PSScriptRoot
$mutex=New-Object Threading.Mutex($false,('Local\CodexQuotaWidgetV1'+$(if($SmokeTest){'-test'})))
try{if(-not $mutex.WaitOne(0)){exit}}catch [Threading.AbandonedMutexException]{}
$node=$env:CODEX_WIDGET_NODE
if(-not $node){$node=(Get-Command node.exe -ErrorAction SilentlyContinue).Source}
if(-not $node){$node=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'}
$codex=$env:CODEX_WIDGET_CODEX
if(-not $codex){$codex=(Get-Command codex.exe -ErrorAction SilentlyContinue).Source}
if(-not $codex){$codex=(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin') -Filter codex.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName}
if(-not $codex -or -not (Test-Path $codex)){[System.Windows.MessageBox]::Show('找不到 Codex，请安装并登录，或设置 CODEX_WIDGET_CODEX 为 codex.exe 路径。');exit}
if(-not (Test-Path $node)){[System.Windows.MessageBox]::Show('找不到 Node.js，请安装 Node.js 22 或更新版本，或设置 CODEX_WIDGET_NODE。');exit}
[xml]$xaml=@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Codex 剩余额度" Width="306" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="True" FontFamily="Microsoft YaHei UI">
<Border Background="#F51A1E26" BorderBrush="#414958" BorderThickness="1" CornerRadius="16" Padding="20,16">
<StackPanel>
<Grid x:Name="DragArea" Background="Transparent" Cursor="SizeAll" Margin="0,0,0,16"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
<StackPanel><TextBlock Text="AI QUOTA" Foreground="#94E2BC" FontWeight="Bold" FontSize="13"/><TextBlock Text="账户剩余额度" Foreground="#E9EDF5" FontSize="17" Margin="0,5,0,0"/></StackPanel>
<Button x:Name="CloseBtn" Grid.Column="1" Content="×" Width="26" Height="26" VerticalAlignment="Top" Background="Transparent" Foreground="#A6AFBF" BorderThickness="0" FontSize="20" ToolTip="关闭小组件"/>
</Grid>
<ScrollViewer MaxHeight="420" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="Rows"><TextBlock Text="正在读取额度…" Foreground="White" FontSize="22" Margin="0,6,0,18"/></StackPanel></ScrollViewer>
<Border BorderBrush="#414958" BorderThickness="0,1,0,0" Margin="0,16,0,0" Padding="0,10,0,0">
<StackPanel><TextBlock Text="本机状态 · 每 2 秒更新" Foreground="#8E9AAA" FontSize="11"/>
<StackPanel x:Name="HardwareRows"><TextBlock Text="正在读取硬件…" Foreground="#ADB7C6" FontSize="12" Margin="0,10,0,0"/></StackPanel>
</StackPanel></Border>
<TextBlock x:Name="Status" Foreground="#8E9AAA" Text="每 60 秒自动刷新" FontSize="11" TextWrapping="Wrap" Margin="0,12,0,12"/>
<Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
<CheckBox x:Name="Pin" Content="置顶" IsChecked="True" Foreground="#ADB7C6" VerticalAlignment="Center" FontSize="11"/>
<Button x:Name="Refresh" Content="刷新" Grid.Column="1" Padding="12,4" Background="#303A49" Foreground="#E7EEF9" BorderThickness="0"/>
</Grid>
<CheckBox x:Name="Auto" Content="开机自动显示" Foreground="#ADB7C6" FontSize="11" Margin="0,12,0,0"/>
</StackPanel></Border></Window>
"@
$window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$rows=$window.FindName('Rows');$status=$window.FindName('Status');$refresh=$window.FindName('Refresh')
$hardwareRows=$window.FindName('HardwareRows')
$script:hardwareWorker=[powershell]::Create()
[void]$script:hardwareWorker.AddScript({param($root) . (Join-Path $root 'hardware.ps1'); Get-HardwareSnapshot}).AddArgument($base)
$script:hardwarePending=$null;$script:hardwareNext=[datetime]::MinValue;$script:hardwarePassed=$false
function Render-Hardware($data) {
 $hardwareRows.Children.Clear()
 $items=@(foreach($gpu in $data.gpus){@{label='显卡占用';percent=$gpu.percent;detail=$gpu.name}})
 if($items.Count -eq 0){$items=@(@{label='显卡占用';percent=$null;detail='暂不可用（需要 NVIDIA 驱动）'})}
 $items+=@{label='内存占用';percent=$data.memoryPercent;detail=$(if($null -ne $data.memoryPercent){"$($data.usedGB) / $($data.totalGB) GB"}else{'暂不可用'})}
 foreach($item in $items){
  $grid=New-Object Windows.Controls.Grid;$grid.Margin='0,10,0,0'
  $text=New-Object Windows.Controls.TextBlock;$text.Text=$item.label;$text.Foreground='#AEBACA';$text.FontSize=12;[void]$grid.Children.Add($text)
  $text=New-Object Windows.Controls.TextBlock;$text.Text=if($null -eq $item.percent){'暂无数据'}else{"$($item.percent)%"};$text.Foreground='#E9EDF5';$text.FontSize=14;$text.FontWeight='SemiBold';$text.HorizontalAlignment='Right';[void]$grid.Children.Add($text);[void]$hardwareRows.Children.Add($grid)
  $bar=New-Object Windows.Controls.ProgressBar;$bar.Height=6;$bar.Maximum=100;$bar.Value=if($null -eq $item.percent){0}else{$item.percent};$bar.Background='#333D4B';$bar.Foreground=if($item.percent -ge 85){'#F5B775'}else{'#89DEB3'};$bar.BorderThickness=0;$bar.Margin='0,6,0,0';[void]$hardwareRows.Children.Add($bar)
  $text=New-Object Windows.Controls.TextBlock;$text.Text=$item.detail;$text.Foreground='#93A0B3';$text.FontSize=11;$text.TextWrapping='Wrap';$text.Margin='0,5,0,0';[void]$hardwareRows.Children.Add($text)
 }
}
$startup=Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex额度小组件.lnk'
$window.FindName('Auto').IsChecked=Test-Path $startup
$window.FindName('Auto').Add_Click({
 try {
  if($this.IsChecked){
   $shell=New-Object -ComObject WScript.Shell;$link=$shell.CreateShortcut($startup)
   $link.TargetPath="$env:WINDIR\System32\wscript.exe";$link.Arguments='"'+$base+'\启动额度小组件.vbs"';$link.WorkingDirectory=$base;$link.Save()
  }else{if(Test-Path $startup){Remove-Item -LiteralPath $startup}}
 }catch{$this.IsChecked=Test-Path $startup;$status.Text='无法更改开机启动设置'}
})
$window.FindName('Pin').Add_Click({$window.Topmost=[bool]$this.IsChecked})
$window.FindName('CloseBtn').Add_Click({$window.Close()})
$window.FindName('DragArea').Add_MouseLeftButtonDown({if($_.OriginalSource -isnot [Windows.Controls.Button]){$window.DragMove()}})
$screen=[Windows.SystemParameters]::WorkArea
$window.Left=$screen.Right-330;$window.Top=$screen.Top+80
try{$pos=Get-Content -Raw "$base\position.json" | ConvertFrom-Json;$window.Left=[Math]::Max($screen.Left,[Math]::Min($pos.left,$screen.Right-306));$window.Top=[Math]::Max($screen.Top,[Math]::Min($pos.top,$screen.Bottom-350))}catch{}
$script:worker=$null;$script:next=[datetime]::MinValue;$script:lastSuccess=$null;$script:passed=$false
function Begin-Refresh {
 if($script:worker){return}
 $status.Text='正在更新…';$refresh.IsEnabled=$false
 $info=New-Object Diagnostics.ProcessStartInfo
 $info.FileName=$node;$info.Arguments='"'+$base+'\read-quota.cjs" "'+$codex+'" "'+$base+'\quota.json"'
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true
 $script:worker=[Diagnostics.Process]::Start($info)
 $script:next=[datetime]::Now.AddSeconds(60)
}
function Render-Quota($data){
 if(-not $data.ok){$status.Foreground='#FFBA80';$status.Text=$data.error + $(if($script:lastSuccess){'（显示上次成功数据）'});return}
 $rows.Children.Clear()
 foreach($r in $data.rows){
  $label=switch($r.minutes){10080{'每周额度'} 300{'5 小时额度'} 1440{'每日额度'} default{if($null -eq $r.minutes){'额度'}else{"$($r.minutes) 分钟额度"}}}
  if($r.name -ne 'codex'){$label="$($r.name) · $label"}
  $t=New-Object Windows.Controls.TextBlock;$t.Text=$label;$t.Foreground='#AEBACA';$t.FontSize=12;$t.Margin='0,8,0,0';[void]$rows.Children.Add($t)
  $t=New-Object Windows.Controls.TextBlock;$t.Text=if($r.displayValue){$r.displayValue}elseif($null -eq $r.remaining){'暂无数据'}else{"$($r.remaining)%"};$t.Foreground='#F5F8FD';$t.FontSize=46;$t.FontWeight='SemiBold';[void]$rows.Children.Add($t)
  $bar=New-Object Windows.Controls.ProgressBar;$bar.Height=6;$bar.Maximum=100;$bar.Value=if($null -eq $r.remaining){0}else{$r.remaining};$bar.Background='#333D4B';$bar.Foreground=if($r.remaining -lt 20){'#F5B775'}else{'#89DEB3'};$bar.BorderThickness=0;if($null -ne $r.remaining){[void]$rows.Children.Add($bar)}
  $t=New-Object Windows.Controls.TextBlock;$t.Foreground='#93A0B3';$t.FontSize=11;$t.TextWrapping='Wrap';$t.Margin='0,10,0,4';$t.Text=if($r.detail){$r.detail}elseif($r.resetsAt){'重置于 '+[DateTimeOffset]::FromUnixTimeSeconds($r.resetsAt).ToLocalTime().ToString('MM月dd日 HH:mm')}else{'重置时间暂无数据'};[void]$rows.Children.Add($t)
 }
 if(@($data.rows).Count -eq 0){$t=New-Object Windows.Controls.TextBlock;$t.Text='当前账号暂无额度数据';$t.Foreground='White';[void]$rows.Children.Add($t)}
 $script:lastSuccess=[datetime]::Now;$script:passed=$true;$status.Foreground='#8E9AAA';$status.Text='更新于 '+$script:lastSuccess.ToString('HH:mm:ss')+' · 每分钟刷新';if($data.errors.Count -gt 0){$status.Foreground='#FFBA80';$status.Text+=' · '+($data.errors -join '；')}
}
$refresh.Add_Click({Begin-Refresh})
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({
 if($SmokeTest -and [datetime]::Now -gt $smokeDeadline){$window.Close();return}
 if($script:hardwarePending -and $script:hardwarePending.IsCompleted){
  try{$samples=$script:hardwareWorker.EndInvoke($script:hardwarePending);if($samples.Count -gt 0){Render-Hardware $samples[0];$script:hardwarePassed=$true}}catch{}
  $script:hardwarePending=$null;$script:hardwareNext=[datetime]::Now.AddSeconds(2)
 }
 if(-not $script:hardwarePending -and [datetime]::Now -ge $script:hardwareNext){$script:hardwarePending=$script:hardwareWorker.BeginInvoke()}
 try{
  if($script:worker -and $script:worker.HasExited){
   if($script:worker.ExitCode -eq 0){Render-Quota (Get-Content -Raw -Encoding UTF8 "$base\quota.json" | ConvertFrom-Json)}else{$status.Text='读取失败，将在一分钟内重试';$status.Foreground='#FFBA80'}
   $script:worker.Dispose();$script:worker=$null;$refresh.IsEnabled=$true
  }
  if(-not $script:worker -and [datetime]::Now -ge $script:next){Begin-Refresh}
  if($SmokeTest -and $script:passed -and $script:hardwarePassed){
   $window.UpdateLayout();$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window)
   $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create("$base\preview.png");$encoder.Save($file);$file.Close();$window.Close()
  }
 }catch{$status.Text='刷新异常，将自动重试';$status.Foreground='#FFBA80';$refresh.IsEnabled=$true;if($script:worker){if(-not $script:worker.HasExited){& taskkill.exe /PID $script:worker.Id /T /F 2>$null | Out-Null};$script:worker.Dispose();$script:worker=$null};$script:next=[datetime]::Now.AddSeconds(60);$_ | Out-String | Set-Content "$base\widget-error.log"}
})
$window.Add_Closed({$timer.Stop();if($script:worker -and -not $script:worker.HasExited){ & taskkill.exe /PID $script:worker.Id /T /F 2>$null | Out-Null };@{left=$window.Left;top=$window.Top}|ConvertTo-Json|Set-Content "$base\position.json"})
$smokeDeadline=[datetime]::Now.AddSeconds(40)
$timer.Start()
try{[void]$window.ShowDialog()}finally{$script:hardwareWorker.Stop();$script:hardwareWorker.Dispose();$mutex.ReleaseMutex();$mutex.Dispose()}
