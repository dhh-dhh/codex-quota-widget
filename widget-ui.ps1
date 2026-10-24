function Add-WidgetText {
 param($Parent,[string]$Text,[double]$Size=14,[string]$Color='#23334B',[string]$Weight='Normal',[string]$Margin='0')
 $textBlock=New-Object Windows.Controls.TextBlock
 $textBlock.Text=$Text;$textBlock.FontSize=$Size;$textBlock.Foreground=Get-WidgetColor $Color
 $textBlock.FontWeight=$Weight;$textBlock.Margin=$Margin;$textBlock.TextWrapping='Wrap'
 [void]$Parent.Children.Add($textBlock)
 return $textBlock
}

$script:WidgetPalette=@{
 '#23334B'='#F8FAFC';'#E2E9F5'='#3A3549';'#326BD5'='#A174FF';'#B26520'='#F0B775'
 '#5E6C80'='#A6B0C4';'#EDF2FF'='#25242F';'#D7E3FC'='#4D3E66';'#2858AD'='#C4B5FD'
 '#4D6485'='#C6C3D4';'#E7EDF8'='#3B3151';'#4D5F78'='#CCC7DC';'#FFFFFF'='#25242F'
 '#A4B2C7'='#756687';'#FBFCFF'='#1E1E24';'#D4DDEA'='#4A405B';'#263C5B'='#F8FAFC'
 '#DCE3EE'='#4A4258';'#98541C'='#F0B775';'#FEFEFE'='#1E1E24'
}
$script:WidgetLightPalette=@{
 '#23334B'='#30343B';'#E2E9F5'='#CED1D5';'#326BD5'='#657B9A';'#B26520'='#986025'
 '#5E6C80'='#626973';'#EDF2FF'='#DDDFE2';'#D7E3FC'='#C5C8CD';'#2858AD'='#465E7F'
 '#4D6485'='#5B6675';'#E7EDF8'='#D1D5DA';'#4D5F78'='#505A68';'#FFFFFF'='#E6E8EB'
 '#A4B2C7'='#9DA3AC';'#FBFCFF'='#E4E5E7';'#D4DDEA'='#BCC1C8';'#263C5B'='#343B46'
 '#DCE3EE'='#C3C7CD';'#98541C'='#88581F';'#FEFEFE'='#F0F1F2'
}
function Get-WidgetColor([string]$Color) {
 if($script:darkMode -and $script:WidgetPalette.ContainsKey($Color)){return $script:WidgetPalette[$Color]}
 if(-not $script:darkMode -and $script:WidgetLightPalette.ContainsKey($Color)){return $script:WidgetLightPalette[$Color]}
 return $Color
}
function New-TicketTexture {
 $lines=New-Object Windows.Media.GeometryGroup
 [void]$lines.Children.Add([Windows.Media.LineGeometry]::new([Windows.Point]::new(0,0),[Windows.Point]::new(20,0)))
 [void]$lines.Children.Add([Windows.Media.LineGeometry]::new([Windows.Point]::new(0,0),[Windows.Point]::new(0,20)))
 $gridColor=if($script:darkMode){[Windows.Media.Color]::FromArgb(22,124,58,237)}else{[Windows.Media.Color]::FromArgb(18,80,88,100)}
 $pen=[Windows.Media.Pen]::new([Windows.Media.SolidColorBrush]::new($gridColor),0.7)
 $drawing=[Windows.Media.GeometryDrawing]::new($null,$pen,$lines)
 $brush=[Windows.Media.DrawingBrush]::new($drawing)
 $brush.Viewport=[Windows.Rect]::new(0,0,20,20);$brush.ViewportUnits='Absolute';$brush.TileMode='Tile';$brush.Stretch='Fill'
 $brush.Freeze();return $brush
}
function New-WidgetBar($Value) {
 $bar=New-Object Windows.Controls.ProgressBar
 $bar.Minimum=0;$bar.Maximum=100;$bar.Value=if($null -eq $Value){0}else{$Value}
 $bar.Height=4;$bar.Background=Get-WidgetColor '#E2E9F5';$bar.Foreground=Get-WidgetColor '#326BD5';$bar.BorderThickness=0
 return $bar
}

function New-QuotaRing($Value,[string]$Display) {
 $grid=New-Object Windows.Controls.Grid;$grid.Width=72;$grid.Height=72
 $track=New-Object Windows.Shapes.Ellipse;$track.Stroke=Get-WidgetColor '#E2E9F5';$track.StrokeThickness=5;$track.Margin=4
 [void]$grid.Children.Add($track)
 if($null -ne $Value -and $Value -gt 0){
  if($Value -ge 100){
   $indicator=New-Object Windows.Shapes.Ellipse;$indicator.Margin=4
  }else{
   $indicator=New-Object Windows.Shapes.Path
   $angle=$Value/100*2*[math]::PI
   $x=36+29.5*[math]::Sin($angle);$y=36-29.5*[math]::Cos($angle)
   $geometry=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'M 36 6.5 A 29.5 29.5 0 {0} 1 {1} {2}',[int]($Value -gt 50),$x,$y)
   $indicator.Data=[Windows.Media.Geometry]::Parse($geometry)
   $indicator.StrokeStartLineCap='Round';$indicator.StrokeEndLineCap='Round'
  }
  $indicator.Stroke=if($Value -lt 20){Get-WidgetColor '#B26520'}else{Get-WidgetColor '#326BD5'};$indicator.StrokeThickness=5
  [void]$grid.Children.Add($indicator)
 }
 $number=Add-WidgetText $grid $Display 22 '#23334B' 'SemiBold'
 $number.TextWrapping='NoWrap';$number.HorizontalAlignment='Center';$number.VerticalAlignment='Center'
 $grid.ToolTip='账户剩余额度'
 return $grid
}

function New-QuotaCard {
 param($Row,[switch]$Embedded)
 $detail=if($Row.detail){($Row.detail -replace '\s*·\s*每分钟刷新\s*$','') -replace '^已用\s*/\s*总量：','已用 '}
 elseif($Row.resetsAt){[DateTimeOffset]::FromUnixTimeSeconds($Row.resetsAt).ToLocalTime().ToString('MM 月 dd 日 HH:mm')+' 重置'}
 else{'重置时间暂无数据'}
 if($Row.name -eq 'codex' -and -not $Row.displayValue){
  $card=New-Object Windows.Controls.Grid;$card.Margin='0,2,0,12'
  $first=New-Object Windows.Controls.ColumnDefinition;$first.Width=86
  [void]$card.ColumnDefinitions.Add($first);[void]$card.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
  $display=if($null -eq $Row.remaining){'--'}else{"$($Row.remaining)%"}
  $ring=New-QuotaRing $Row.remaining $display
  [void]$card.Children.Add($ring)
  $copy=New-Object Windows.Controls.StackPanel;$copy.VerticalAlignment='Center'
  [Windows.Controls.Grid]::SetColumn($copy,1);[void]$card.Children.Add($copy)
  $label=switch($Row.minutes){10080{'AI 每周剩余'} 300{'AI 5 小时剩余'} 1440{'AI 每日剩余'} default{'AI 剩余额度'}}
  [void](Add-WidgetText $copy $label 14 '#23334B' 'SemiBold')
  [void](Add-WidgetText $copy $detail 12 '#5E6C80' 'Normal' '0,6,0,0')
  return $card
 }
 $compact=$Row.name -match '主套餐剩余流量$'
 $card=New-Object Windows.Controls.Border;$card.Background=Get-WidgetColor '#EDF2FF';$card.BorderBrush=Get-WidgetColor '#D7E3FC'
 $card.BorderThickness=1;$card.CornerRadius=14;$card.Padding=if($compact){'12,5'}else{'12'};$card.Margin='0,0,0,12'
 if($Embedded){$card.BorderThickness=0;$card.Background='Transparent';$card.Padding=0;$card.Margin=0}
 $stack=New-Object Windows.Controls.StackPanel;$card.Child=$stack
 $title=$Row.name;$provider=''
 if($title -match '^(.+?) · (.+)$'){$provider=$Matches[1];$title=$Matches[2]}
 $heading=New-Object Windows.Controls.DockPanel
 if($provider -and -not $compact){$source=Add-WidgetText $heading $provider 12 '#5E6C80';[Windows.Controls.DockPanel]::SetDock($source,'Right');$source.Margin='8,1,0,0'}
 $label=Add-WidgetText $heading $title 14 '#23334B';$label.VerticalAlignment='Center'
 $card.ToolTip=if($provider){$provider+' · '+$title}else{$title}
 [void]$stack.Children.Add($heading)
 $value=if($Row.displayValue){$Row.displayValue}elseif($null -eq $Row.remaining){'暂无数据'}else{"$($Row.remaining)%"}
 $number=New-Object Windows.Controls.TextBlock;$number.Foreground=Get-WidgetColor '#2858AD';$number.FontSize=28
 $number.FontWeight='SemiBold';$number.Margin='0,4,0,9';$number.TextWrapping='Wrap'
 if($compact){$number.FontSize=20;$number.Margin='8,0,0,0';$number.TextWrapping='NoWrap'}
 if($value -match '^(.*)\s+(GB|MB|TB|KB|B)$'){
  $digits=New-Object Windows.Documents.Run;$digits.Text=$Matches[1];[void]$number.Inlines.Add($digits)
  $unit=New-Object Windows.Documents.Run;$unit.Text=' '+$Matches[2];$unit.FontSize=if($compact){12}else{15};$unit.FontWeight='Normal';[void]$number.Inlines.Add($unit)
 }else{$number.Text=$value}
 if($compact){[Windows.Controls.DockPanel]::SetDock($number,'Right');$heading.Children.Insert(0,$number)}else{[void]$stack.Children.Add($number)}
 if($null -ne $Row.remaining){$bar=New-WidgetBar $Row.remaining;if($compact){$bar.Margin='0,3,0,0'};[void]$stack.Children.Add($bar)}
 $detailMargin=if($compact){'0,3,0,0'}else{'0,7,0,0'}
 [void](Add-WidgetText $stack $detail 12 '#5E6C80' 'Normal' $detailMargin)
 return $card
}

function Set-AccountRows($Container,$AccountRows,$Errors) {
 $group=New-Object Windows.Controls.Grid;$group.Margin='0,2,0,12'
 [void]$group.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
 [void]$group.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
 foreach($provider in @('codex','deepseek')){
  $panel=New-Object Windows.Controls.Border;$panel.Background=Get-WidgetColor '#EDF2FF';$panel.BorderBrush=Get-WidgetColor '#D7E3FC'
  $panel.BorderThickness=1;$panel.CornerRadius=12;$panel.Padding=8
  $panel.Margin=if($provider -eq 'codex'){'0,0,4,0'}else{'4,0,0,0'}
  $stack=New-Object Windows.Controls.StackPanel;$panel.Child=$stack
  $title=if($provider -eq 'codex'){'Codex'}else{'DeepSeek'}
  [void](Add-WidgetText $stack $title 13 '#23334B' 'SemiBold' '0,0,0,5')
  $items=@($AccountRows | Where-Object {$_.providerId -eq $provider -or ($provider -eq 'codex' -and $_.name -eq 'codex') -or ($provider -eq 'deepseek' -and $_.name -match '^DeepSeek · ')})
  foreach($item in $items){
   if($provider -eq 'codex'){
    $display=if($null -eq $item.remaining){'--'}else{"$($item.remaining)%"}
    $ring=New-QuotaRing $item.remaining $display
    $view=New-Object Windows.Controls.Viewbox;$view.Width=54;$view.Height=54;$view.HorizontalAlignment='Left';$view.Child=$ring
    [void]$stack.Children.Add($view)
    $label=switch($item.minutes){10080{'每周剩余'} 300{'5 小时剩余'} 1440{'每日剩余'} default{'剩余额度'}}
    [void](Add-WidgetText $stack $label 11 '#5E6C80' 'Normal' '0,4,0,0')
    $reset=if($item.resetsAt){[DateTimeOffset]::FromUnixTimeSeconds($item.resetsAt).ToLocalTime().ToString('MM/dd HH:mm')+' 重置'}else{'重置时间未知'}
    [void](Add-WidgetText $stack $reset 10 '#5E6C80' 'Normal' '0,2,0,0')
   }else{
    [void](Add-WidgetText $stack $item.displayValue 23 '#2858AD' 'SemiBold' '0,9,0,8')
    [void](Add-WidgetText $stack 'API 账户余额' 11 '#5E6C80')
    $panel.ToolTip=$item.detail
   }
  }
  if($items.Count -eq 0){
   [void](Add-WidgetText $stack '--' 25 '#2858AD' 'SemiBold' '0,9,0,8')
   $missingKey=$provider -eq 'deepseek' -and ($Errors -join ' ') -match 'deepseek-key.local.txt'
   [void](Add-WidgetText $stack $(if($missingKey){'待配置密钥'}else{'暂不可用'}) 11 '#5E6C80')
   $panel.ToolTip=($Errors -join '；')
  }
  if($provider -eq 'deepseek'){[Windows.Controls.Grid]::SetColumn($panel,1)}
  [void]$group.Children.Add($panel)
 }
 [void]$Container.Children.Add($group)
}

function Set-HardwareRows($Container,$Data) {
 $Container.Children.Clear()
 $items=@(foreach($gpu in $Data.gpus){@{label='显卡占用';percent=$gpu.percent;detail=$gpu.name;tooltip=$gpu.name}})
 if($items.Count -eq 0){$items=@(@{label='显卡占用';percent=$null;detail='暂不可用';tooltip='需要 NVIDIA 驱动'})}
 $items+=@{label='内存占用';percent=$Data.memoryPercent;detail=$(if($null -ne $Data.memoryPercent){"$($Data.usedGB) / $($Data.totalGB) GB"}else{'暂不可用'});tooltip='物理内存占用'}
 foreach($item in $items){
  $grid=New-Object Windows.Controls.Grid;$grid.Margin='0,5,0,6';$grid.ToolTip=$item.tooltip
  foreach($width in @('*','64','49')){$column=New-Object Windows.Controls.ColumnDefinition;$column.Width=[Windows.GridLengthConverter]::new().ConvertFromString($width);[void]$grid.ColumnDefinitions.Add($column)}
  $copy=New-Object Windows.Controls.StackPanel
  [void](Add-WidgetText $copy $item.label 14 '#23334B')
  $detail=if($item.label -eq '显卡占用' -and $item.percent -ne $null){$item.detail -replace '^NVIDIA GeForce ','GPU · '}else{$item.detail}
  $caption=Add-WidgetText $copy $detail 12 '#5E6C80' 'Normal' '0,2,0,0';$caption.TextTrimming='CharacterEllipsis';$caption.TextWrapping='NoWrap'
  [void]$grid.Children.Add($copy)
  $bar=New-WidgetBar $item.percent;$bar.Margin='0,0,8,0';$bar.VerticalAlignment='Center';if($item.percent -ge 85){$bar.Foreground=Get-WidgetColor '#B26520'}
  [Windows.Controls.Grid]::SetColumn($bar,1);[void]$grid.Children.Add($bar)
  $display=if($null -eq $item.percent){'--'}else{"$($item.percent)%"}
  $number=Add-WidgetText $grid $display 17 '#23334B' 'SemiBold'
  $number.TextWrapping='NoWrap';$number.HorizontalAlignment='Right';$number.VerticalAlignment='Center';[Windows.Controls.Grid]::SetColumn($number,2)
  [void]$Container.Children.Add($grid)
 }
}
