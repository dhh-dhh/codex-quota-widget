function Add-WidgetText {
 param($Parent,[string]$Text,[double]$Size=14,[string]$Color='#23334B',[string]$Weight='Normal',[string]$Margin='0')
 $textBlock=New-Object Windows.Controls.TextBlock
 $textBlock.Text=$Text;$textBlock.FontSize=$Size;$textBlock.Foreground=Get-WidgetColor $Color
 $textBlock.FontWeight=$Weight;$textBlock.Margin=$Margin;$textBlock.TextWrapping='Wrap'
 [void]$Parent.Children.Add($textBlock)
 return $textBlock
}

$script:WidgetPalette=@{
 '#23334B'='#EEEEEE';'#E2E9F5'='#333333';'#326BD5'='#82B7FF';'#B26520'='#F0B775'
 '#5E6C80'='#AAAAAA';'#EDF2FF'='#1C1C1C';'#D7E3FC'='#383838';'#2858AD'='#A9CDFF'
 '#4D6485'='#C4C4C4';'#E7EDF8'='#2A2A2A';'#4D5F78'='#C4C4C4';'#FFFFFF'='#181818'
 '#A4B2C7'='#666666';'#FBFCFF'='#101010';'#D4DDEA'='#383838';'#263C5B'='#EEEEEE'
 '#DCE3EE'='#333333';'#98541C'='#F0B775';'#FEFEFE'='#101010'
}
function Get-WidgetColor([string]$Color) {
 if($script:darkMode -and $script:WidgetPalette.ContainsKey($Color)){return $script:WidgetPalette[$Color]}
 return $Color
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
