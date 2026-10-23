param([switch]$SmokeTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$base=$PSScriptRoot
. "$base\widget-ui.ps1"
. "$base\proxy-control.ps1"
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
$script:darkMode=$false
try{$appearance=Get-Content -LiteralPath "$base\appearance.json" -Raw -Encoding UTF8 | ConvertFrom-Json;if($appearance.darkMode -is [bool]){$script:darkMode=$appearance.darkMode}}catch{}
$brushResources=($script:WidgetPalette.Keys | ForEach-Object {'<SolidColorBrush x:Key="Brush'+$_.Substring(1)+'" Color="'+(Get-WidgetColor $_)+'"/>'}) -join ''
[xml]$xaml=@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="油量表" Width="300" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="True" FontFamily="Segoe UI, Microsoft YaHei UI" UseLayoutRounding="True" SnapsToDevicePixels="True">
<Window.Resources>
$brushResources
<Style TargetType="ProgressBar"><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ProgressBar"><Grid x:Name="PART_Track" ClipToBounds="True"><Border Background="{TemplateBinding Background}" CornerRadius="2"/><Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left" CornerRadius="2"/></Grid></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="Button"><Setter Property="Foreground" Value="{DynamicResource Brush4D6485}"/><Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="ButtonSurface" Background="{TemplateBinding Background}" CornerRadius="8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonSurface" Property="Background" Value="{DynamicResource BrushE7EDF8}"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
<Style TargetType="CheckBox"><Setter Property="Foreground" Value="{DynamicResource Brush4D5F78}"/><Setter Property="FontSize" Value="12"/><Setter Property="VerticalContentAlignment" Value="Center"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox"><Grid Background="Transparent"><Grid.ColumnDefinitions><ColumnDefinition Width="14"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><Border x:Name="CheckSurface" Height="14" Background="{DynamicResource BrushFFFFFF}" BorderBrush="{DynamicResource BrushA4B2C7}" BorderThickness="1" CornerRadius="3"/><Path x:Name="CheckMark" Data="M 3 7 L 6 10 L 11 4" Stroke="{DynamicResource BrushFEFEFE}" StrokeThickness="1.7" Visibility="Collapsed" VerticalAlignment="Center"/><ContentPresenter Grid.Column="1" Margin="6,0,0,0" VerticalAlignment="Center"/></Grid><ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="CheckSurface" Property="Background" Value="{DynamicResource Brush326BD5}"/><Setter TargetName="CheckSurface" Property="BorderBrush" Value="{DynamicResource Brush326BD5}"/><Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
</Window.Resources>
<Border Background="{DynamicResource BrushFBFCFF}" BorderBrush="{DynamicResource BrushD4DDEA}" BorderThickness="1" CornerRadius="20" Padding="18,8,18,8">
<StackPanel>
<Grid x:Name="DragArea" Background="Transparent" Cursor="SizeAll" Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
<StackPanel Orientation="Horizontal" VerticalAlignment="Center"><Grid Width="22" Height="22" Margin="0,0,9,0"><Rectangle Width="4" Height="11" RadiusX="2" RadiusY="2" Fill="{DynamicResource Brush263C5B}" HorizontalAlignment="Left" VerticalAlignment="Bottom"/><Rectangle Width="4" Height="20" RadiusX="2" RadiusY="2" Fill="{DynamicResource Brush263C5B}" VerticalAlignment="Bottom"/><Rectangle Width="4" Height="15" RadiusX="2" RadiusY="2" Fill="{DynamicResource Brush263C5B}" HorizontalAlignment="Right" VerticalAlignment="Bottom"/></Grid><TextBlock Text="油量表" Foreground="{DynamicResource Brush263C5B}" FontWeight="SemiBold" FontSize="16" VerticalAlignment="Center"/></StackPanel>
<Button x:Name="CloseBtn" Grid.Column="1" Content="×" Width="44" Height="44" Margin="0,0,-10,0" FontSize="22" ToolTip="关闭小组件"/>
</Grid>
<ScrollViewer x:Name="QuotaScroll" MaxHeight="330" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"><StackPanel x:Name="Rows"><TextBlock Text="正在读取额度…" Foreground="{DynamicResource Brush5E6C80}" FontSize="14" Margin="0,12,0,20"/></StackPanel></ScrollViewer>
<Border Background="{DynamicResource BrushEDF2FF}" BorderBrush="{DynamicResource BrushD7E3FC}" BorderThickness="1" CornerRadius="14" Padding="12,5" Margin="0,0,0,12"><StackPanel>
<StackPanel x:Name="TrafficRows"><TextBlock Text="正在读取流量…" FontSize="14" Foreground="{DynamicResource Brush23334B}" Margin="0,4,0,4"/></StackPanel>
<Border BorderBrush="{DynamicResource BrushDCE3EE}" BorderThickness="0,1,0,0" Margin="0,5,0,0" Padding="0,8,0,0"><Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="44"/></Grid.ColumnDefinitions>
<StackPanel><TextBlock Text="系统代理" FontSize="14" Foreground="{DynamicResource Brush23334B}"/><TextBlock x:Name="ProxyStatus" Text="正在读取状态…" FontSize="12" Foreground="{DynamicResource Brush5E6C80}" TextWrapping="Wrap" Margin="0,2,4,0"/></StackPanel>
<CheckBox x:Name="ProxySwitch" Grid.Column="1" Width="44" Height="36" VerticalAlignment="Center" IsEnabled="False" ToolTip="切换 Windows 系统代理；Clash Verge 需保持运行" AutomationProperties.Name="系统代理"><CheckBox.Template><ControlTemplate TargetType="CheckBox"><Grid Background="Transparent"><Border x:Name="Rail" Width="38" Height="20" CornerRadius="10" Background="{DynamicResource BrushE2E9F5}"/><Ellipse x:Name="Thumb" Width="14" Height="14" Fill="White" Margin="6,0,0,0" HorizontalAlignment="Left"/></Grid><ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="Rail" Property="Background" Value="{DynamicResource Brush326BD5}"/><Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/><Setter TargetName="Thumb" Property="Margin" Value="0,0,6,0"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger></ControlTemplate.Triggers></ControlTemplate></CheckBox.Template></CheckBox>
</Grid></Border>
</StackPanel></Border>
<StackPanel x:Name="HardwareRows"><TextBlock Text="正在读取硬件…" Foreground="{DynamicResource Brush5E6C80}" FontSize="12" Margin="0,10,0,0"/></StackPanel>
<TextBlock x:Name="Status" Foreground="{DynamicResource Brush5E6C80}" Text="额度每分钟更新 · 硬件每 2 秒" FontSize="12" TextWrapping="Wrap" Margin="0,10,0,6"/>
<Border BorderBrush="{DynamicResource BrushDCE3EE}" BorderThickness="0,1,0,0"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="50"/><ColumnDefinition Width="84"/><ColumnDefinition Width="84"/><ColumnDefinition Width="44"/></Grid.ColumnDefinitions>
<CheckBox x:Name="Pin" Content="置顶" IsChecked="True" Height="44"/>
<CheckBox x:Name="Auto" Content="开机启动" Grid.Column="1" Height="44"/>
<CheckBox x:Name="Dark" Content="深色模式" Grid.Column="2" Height="44"/>
<Button x:Name="Refresh" Grid.Column="3" Width="44" Height="44" ToolTip="刷新额度和流量" AutomationProperties.Name="刷新"><Path Data="M 17 8 A 7 7 0 1 0 17 15 M 17 3 L 17 8 L 12 8" Stroke="{DynamicResource Brush4D6485}" StrokeThickness="1.6" Width="20" Height="20"/></Button>
</Grid></Border>
</StackPanel></Border></Window>
"@
$window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$rows=$window.FindName('Rows');$status=$window.FindName('Status');$refresh=$window.FindName('Refresh')
$hardwareRows=$window.FindName('HardwareRows')
$trafficRows=$window.FindName('TrafficRows')
$proxySwitch=$window.FindName('ProxySwitch');$proxyStatus=$window.FindName('ProxyStatus')
$script:proxyWorker=[powershell]::Create();$script:proxyPending=$null;$script:proxyNext=[datetime]::MinValue
function Render-ProxyState($State) {
 $proxySwitch.IsChecked=[bool]$State.enabled;$proxySwitch.IsEnabled=[bool]$State.available
 $proxyStatus.Text=$State.detail
}
$proxySwitch.Add_Click({
 $desired=[bool]$this.IsChecked;$proxySwitch.IsEnabled=$false;$proxyStatus.Text='正在切换…'
 [void]$script:proxyWorker.Commands.Clear()
 [void]$script:proxyWorker.AddScript({param($root,$enabled) $ErrorActionPreference='Stop';. (Join-Path $root 'proxy-control.ps1');Set-SystemProxyEnabled $enabled}).AddArgument($base).AddArgument($desired)
 $script:proxyPending=$script:proxyWorker.BeginInvoke()
})
$script:hardwareWorker=[powershell]::Create()
[void]$script:hardwareWorker.AddScript({param($root) . (Join-Path $root 'hardware.ps1'); Get-HardwareSnapshot}).AddArgument($base)
$script:hardwarePending=$null;$script:hardwareNext=[datetime]::MinValue;$script:hardwarePassed=$false
function Render-Hardware($data) {
 $script:lastHardwareData=$data
 Set-HardwareRows $hardwareRows $data
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
try{$pos=Get-Content -Raw "$base\position.json" | ConvertFrom-Json;$window.Left=[Math]::Max($screen.Left,[Math]::Min($pos.left,$screen.Right-$window.Width));$window.Top=[Math]::Max($screen.Top,[Math]::Min($pos.top,$screen.Bottom-350))}catch{}
$window.Add_ContentRendered({$window.UpdateLayout();$window.Top=[Math]::Max($screen.Top,[Math]::Min($window.Top,$screen.Bottom-$window.ActualHeight))})
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
 if(-not $data.ok){$status.Foreground=Get-WidgetColor '#98541C';$status.Text=$data.error + $(if($script:lastSuccess){'（显示上次成功数据）'});return}
 $rows.Children.Clear()
 $trafficRows.Children.Clear();$trafficFound=$false
 $script:lastQuotaData=$data
 foreach($r in $data.rows){
  if($r.name -match '主套餐剩余流量$'){
   [void]$trafficRows.Children.Add((New-QuotaCard $r -Embedded));$trafficFound=$true
  }else{[void]$rows.Children.Add((New-QuotaCard $r))}
 }
 if(-not $trafficFound){[void](Add-WidgetText $trafficRows '流量暂不可用' 14 '#5E6C80' 'Normal' '0,4,0,4')}
 if(@($data.rows).Count -eq 0){[void](Add-WidgetText $rows '当前账号暂无额度数据' 14 '#5E6C80')}
 $script:lastSuccess=[datetime]::Now;$script:passed=$true;$status.Foreground=Get-WidgetColor '#5E6C80';$status.Text='更新于 '+$script:lastSuccess.ToString('HH:mm')+' · 硬件每 2 秒';if($data.errors.Count -gt 0){$status.Foreground=Get-WidgetColor '#98541C';$status.Text+=' · '+($data.errors -join '；')}
}
function Set-WidgetTheme([bool]$Dark) {
 $statusText=$status.Text;$lastSuccess=$script:lastSuccess
 $wasError=$status.Foreground.ToString() -eq ([Windows.Media.BrushConverter]::new().ConvertFromString((Get-WidgetColor '#98541C'))).ToString()
 $script:darkMode=$Dark
 foreach($color in $script:WidgetPalette.Keys){$window.Resources['Brush'+$color.Substring(1)]=[Windows.Media.BrushConverter]::new().ConvertFromString((Get-WidgetColor $color))}
 $window.FindName('Dark').IsChecked=$Dark
 if($script:lastQuotaData){Render-Quota $script:lastQuotaData}
 if($script:lastHardwareData){Render-Hardware $script:lastHardwareData}
 $script:lastSuccess=$lastSuccess;$status.Text=$statusText
 $status.Foreground=Get-WidgetColor $(if($wasError){'#98541C'}else{'#5E6C80'})
}
$window.FindName('Dark').IsChecked=$script:darkMode
$window.FindName('Dark').Add_Click({
 Set-WidgetTheme ([bool]$this.IsChecked)
 try{@{darkMode=$script:darkMode}|ConvertTo-Json|Set-Content -LiteralPath "$base\appearance.json" -Encoding UTF8}catch{$status.Text='主题已切换，但无法保存偏好'}
})
function Save-WidgetPreview([string]$Name) {
 $window.UpdateLayout();$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap([int]$window.ActualWidth,[int]$window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($window)
 $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$file=[IO.File]::Create((Join-Path $base $Name));try{$encoder.Save($file)}finally{$file.Close()}
}
$refresh.Add_Click({Begin-Refresh})
$timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({
 if($SmokeTest -and [datetime]::Now -gt $smokeDeadline){$window.Close();return}
 if($script:proxyPending -and $script:proxyPending.IsCompleted){
  try{$proxyResult=$script:proxyWorker.EndInvoke($script:proxyPending);if($proxyResult.Count -gt 0){Render-ProxyState $proxyResult[0]}}
  catch{Render-ProxyState (Get-SystemProxyState);$proxyStatus.Text='切换失败，请检查 Clash 设置'}
  $script:proxyPending=$null;$script:proxyNext=[datetime]::Now.AddSeconds(2)
 }
 if(-not $script:proxyPending -and [datetime]::Now -ge $script:proxyNext){Render-ProxyState (Get-SystemProxyState);$script:proxyNext=[datetime]::Now.AddSeconds(2)}
 if($script:hardwarePending -and $script:hardwarePending.IsCompleted){
  try{$samples=$script:hardwareWorker.EndInvoke($script:hardwarePending);if($samples.Count -gt 0){Render-Hardware $samples[0];$script:hardwarePassed=$true}}catch{}
  $script:hardwarePending=$null;$script:hardwareNext=[datetime]::Now.AddSeconds(2)
 }
 if(-not $script:hardwarePending -and [datetime]::Now -ge $script:hardwareNext){$script:hardwarePending=$script:hardwareWorker.BeginInvoke()}
 try{
  if($script:worker -and $script:worker.HasExited){
   if($script:worker.ExitCode -eq 0){Render-Quota (Get-Content -Raw -Encoding UTF8 "$base\quota.json" | ConvertFrom-Json)}else{$status.Text='读取失败，将在一分钟内重试';$status.Foreground=Get-WidgetColor '#98541C'}
   $script:worker.Dispose();$script:worker=$null;$refresh.IsEnabled=$true
  }
  if(-not $script:worker -and [datetime]::Now -ge $script:next){Begin-Refresh}
  if($SmokeTest -and $script:passed -and $script:hardwarePassed){
   Save-WidgetPreview 'preview.png'
   Set-WidgetTheme $false;Save-WidgetPreview 'preview-light.png'
   Set-WidgetTheme $true;Save-WidgetPreview 'preview-dark.png'
   $window.Close()
  }
 }catch{$status.Text='刷新异常，将自动重试';$status.Foreground=Get-WidgetColor '#98541C';$refresh.IsEnabled=$true;if($script:worker){if(-not $script:worker.HasExited){& taskkill.exe /PID $script:worker.Id /T /F 2>$null | Out-Null};$script:worker.Dispose();$script:worker=$null};$script:next=[datetime]::Now.AddSeconds(60);$_ | Out-String | Set-Content "$base\widget-error.log"}
})
$window.Add_Closed({$timer.Stop();if($script:worker -and -not $script:worker.HasExited){ & taskkill.exe /PID $script:worker.Id /T /F 2>$null | Out-Null };@{left=$window.Left;top=$window.Top}|ConvertTo-Json|Set-Content "$base\position.json"})
$smokeDeadline=[datetime]::Now.AddSeconds(40)
$timer.Start()
try{[void]$window.ShowDialog()}finally{$script:proxyWorker.Stop();$script:proxyWorker.Dispose();$script:hardwareWorker.Stop();$script:hardwareWorker.Dispose();$mutex.ReleaseMutex();$mutex.Dispose()}
