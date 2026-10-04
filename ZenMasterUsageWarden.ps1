
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference='Stop'

$base=Split-Path -Parent $MyInvocation.MyCommand.Path
$settingsPath=Join-Path $base 'settings.json'

function Load-Settings {
 if(Test-Path $settingsPath){ try{return (Get-Content $settingsPath -Raw|ConvertFrom-Json)}catch{} }
 [pscustomobject]@{Percent=100;ResetAt=(Get-Date).AddDays(7).ToString('o');AlwaysOnTop=$false;X=40;Y=40;AutoRefresh=$true;RefreshMinutes=5}
}
function Save-Settings {
 [pscustomobject]@{Percent=[int]$script:percent;ResetAt=$script:resetAt.ToString('o');AlwaysOnTop=[bool]$form.TopMost;X=[int]$form.Left;Y=[int]$form.Top;AutoRefresh=[bool]$script:autoRefresh;RefreshMinutes=[int]$script:refreshMinutes}|
 ConvertTo-Json|Set-Content -Encoding UTF8 $settingsPath
}
function Stage([int]$p){
 if($p -le 0){@('jail','Rest. Recharge. Dream up more awesome ideas.','#C8A7FF')}
 elseif($p -le 9){@('verylow','Take a break. Seriously.','#FF6B86')}
 elseif($p -le 24){@('low','Easy there, overachiever.','#FF6B86')}
 elseif($p -le 49){@('medium',"You've got this.",'#FFD45C')}
 elseif($p -le 74){@('good','Plenty of fuel!','#77EF91')}
 else{@('high','Go make something awesome!','#77EF91')}
}
function Remaining {
 $s=$script:resetAt-(Get-Date)
 if($s.TotalSeconds -le 0){return 'Reset time reached - check Usage'}
 if($s.Days -gt 0){return ('Resets in {0}d {1}h' -f $s.Days,$s.Hours)}
 if($s.Hours -gt 0){return ('Resets in {0}h {1}m' -f $s.Hours,$s.Minutes)}
 ('Resets in {0}m' -f [math]::Max(0,$s.Minutes))
}
function UpdateUI {
 $i=Stage $script:percent
 $path=Join-Path $base ('assets\'+$i[0]+'.png')
 if(Test-Path $path){if($pet.Image){$pet.Image.Dispose()};$pet.Image=[Drawing.Image]::FromFile($path)}
 $pct.Text="$($script:percent)% remaining";$reset.Text=Remaining;$msg.Text=$i[1]
 $msg.ForeColor=[Drawing.ColorTranslator]::FromHtml($i[2]);$meter.Invalidate()
 $pin.Text=if($form.TopMost){'●'}else{'○'}
}


function Find-CodexExecutable {
  # 1) Normal PATH / CLI installation
  try {
    $cmd=Get-Command codex.exe -ErrorAction Stop
    if($cmd -and (Test-Path $cmd.Source)){return $cmd.Source}
  } catch {}
  try {
    $cmd=Get-Command codex -ErrorAction Stop
    if($cmd -and $cmd.Source -and (Test-Path $cmd.Source)){return $cmd.Source}
  } catch {}

  # 2) User override if they ever want to point Zen Master at a specific executable.
  if($env:CODEX_CLI_PATH -and (Test-Path $env:CODEX_CLI_PATH)){return $env:CODEX_CLI_PATH}

  # 3) Codex Desktop's runnable local cache. Current Windows builds commonly keep
  #    hash-versioned copies under LocalAppData\OpenAI\Codex\bin\<hash>\codex.exe.
  $root=Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
  if(Test-Path $root){
    $candidates=Get-ChildItem -Path $root -Filter codex.exe -File -Recurse -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending
    foreach($c in $candidates){
      try {
        # Prefer a complete cache folder when companion executables are present,
        # but accept codex.exe alone if that's all this build has.
        $dir=$c.DirectoryName
        $runner=Join-Path $dir 'codex-command-runner.exe'
        $sandbox=Join-Path $dir 'codex-windows-sandbox-setup.exe'
        if((Test-Path $runner) -and (Test-Path $sandbox)){return $c.FullName}
      } catch {}
    }
    if($candidates -and $candidates.Count -gt 0){return $candidates[0].FullName}
  }
  return $null
}

function Read-CodexRateLimits {
  try {
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $codexExe=Find-CodexExecutable
    if(-not $codexExe){ throw 'Codex executable not found on PATH or in the Codex Desktop local cache.' }
    $script:lastCodexPath=$codexExe
    $psi.FileName=$codexExe
    $psi.Arguments='app-server --listen stdio://'
    $psi.UseShellExecute=$false
    $psi.RedirectStandardInput=$true
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $psi.CreateNoWindow=$true
    $p=New-Object System.Diagnostics.Process
    $p.StartInfo=$psi
    if(-not $p.Start()){ throw 'Could not start codex app-server.' }

    # App-server JSON-RPC handshake. Keep this local/read-only; Codex owns authentication.
    $init='{"method":"initialize","id":1,"params":{"clientInfo":{"name":"zen-master-usage-warden","title":"Zen Master Usage Warden","version":"9.0.0"}}}'
    $p.StandardInput.WriteLine($init); $p.StandardInput.Flush()

    $deadline=(Get-Date).AddSeconds(10)
    $initialized=$false
    while((Get-Date) -lt $deadline -and -not $initialized){
      if(-not $p.StandardOutput.EndOfStream){
        $line=$p.StandardOutput.ReadLine()
        if($line){
          try{$j=$line|ConvertFrom-Json}catch{continue}
          if($j.id -eq 1){$initialized=$true}
        }
      } else { Start-Sleep -Milliseconds 80 }
    }
    if(-not $initialized){ throw 'Codex app-server did not initialize.' }

    $p.StandardInput.WriteLine('{"method":"initialized","params":{}}');$p.StandardInput.Flush()
    $p.StandardInput.WriteLine('{"method":"account/rateLimits/read","id":7}');$p.StandardInput.Flush()

    $deadline=(Get-Date).AddSeconds(12);$resp=$null
    while((Get-Date) -lt $deadline -and $null -eq $resp){
      if(-not $p.StandardOutput.EndOfStream){
        $line=$p.StandardOutput.ReadLine()
        if($line){
          try{$j=$line|ConvertFrom-Json}catch{continue}
          if($j.id -eq 7){$resp=$j}
        }
      } else { Start-Sleep -Milliseconds 80 }
    }
    try{$p.Kill()}catch{}
    if($null -eq $resp){ throw 'No rate-limit response from Codex.' }

    $snap=$resp.result.rateLimits
    if($null -eq $snap -and $resp.result.rateLimitsByLimitId){
      $snap=$resp.result.rateLimitsByLimitId.codex
    }
    if($null -eq $snap){ throw 'Codex returned no Codex rate-limit snapshot.' }

    $windows=@()
    if($snap.primary){$windows+=,$snap.primary}
    if($snap.secondary){$windows+=,$snap.secondary}
    if($windows.Count -eq 0){throw 'Codex returned no usage windows.'}

    # Prefer the weekly (10080-minute) window; otherwise use the longest returned window.
    $w=$windows | Sort-Object {[int]$_.windowDurationMins} -Descending | Select-Object -First 1
    $used=[double]$w.usedPercent
    $remaining=[int][math]::Round(100-$used)
    $remaining=[math]::Max(0,[math]::Min(100,$remaining))
    $resetRaw=$w.resetsAt
    if($resetRaw -is [double] -or $resetRaw -is [int] -or $resetRaw -is [long]){
      $reset=[DateTimeOffset]::FromUnixTimeSeconds([long]$resetRaw).LocalDateTime
    } else {
      $reset=[datetime]::Parse([string]$resetRaw).ToLocalTime()
    }
    return [pscustomobject]@{Percent=$remaining;ResetAt=$reset;WindowMinutes=[int]$w.windowDurationMins}
  } catch {
    return [pscustomobject]@{Error=$_.Exception.Message;CodexPath=$script:lastCodexPath}
  }
}
function Refresh-FromCodex {
  $r=Read-CodexRateLimits
  if($r.Error){
    $msg=[string]$r.Error
    if($msg -match 'not found'){$script:lastAutoStatus='Auto: Codex not found'}
    elseif($msg -match 'initialize'){$script:lastAutoStatus='Auto: handshake failed'}
    elseif($msg -match 'No rate-limit'){$script:lastAutoStatus='Auto: no rate data'}
    elseif($msg -match 'no usage windows'){$script:lastAutoStatus='Auto: no weekly data'}
    else{$script:lastAutoStatus='Auto: failed'}
    $script:lastAutoError=$msg
    if($status){$status.Text=$script:lastAutoStatus;$status.ForeColor=[Drawing.Color]::FromArgb(255,190,90)}
    return
  }
  $script:percent=[int]$r.Percent
  $script:resetAt=[datetime]$r.ResetAt
  $script:lastAutoStatus='Auto: Codex synced'
  if($status){$status.Text=$script:lastAutoStatus;$status.ForeColor=[Drawing.Color]::FromArgb(115,239,145)}
  Save-Settings
  UpdateUI
}

function EditUsage {
 $d=New-Object Windows.Forms.Form;$d.Text='Update Codex Fuel';$d.Size='330,225';$d.StartPosition='CenterParent'
 $d.FormBorderStyle='FixedDialog';$d.MaximizeBox=$false;$d.MinimizeBox=$false;$d.BackColor=[Drawing.Color]::FromArgb(20,31,46);$d.ForeColor='White'
 $a=New-Object Windows.Forms.Label;$a.Text='Percent remaining';$a.Location='18,18';$a.AutoSize=$true
 $n=New-Object Windows.Forms.NumericUpDown;$n.Location='18,42';$n.Width=120;$n.Minimum=0;$n.Maximum=100;$n.Value=$script:percent
 $b=New-Object Windows.Forms.Label;$b.Text='Weekly reset date/time';$b.Location='18,82';$b.AutoSize=$true
 $dt=New-Object Windows.Forms.DateTimePicker;$dt.Location='18,106';$dt.Width=275;$dt.Format='Custom';$dt.CustomFormat='ddd MMM d, yyyy  h:mm tt';$dt.Value=$script:resetAt
 $ok=New-Object Windows.Forms.Button;$ok.Text='Save';$ok.Location='126,148';$ok.Width=80;$ok.DialogResult='OK'
 $ca=New-Object Windows.Forms.Button;$ca.Text='Cancel';$ca.Location='213,148';$ca.Width=80;$ca.DialogResult='Cancel'
 $d.Controls.AddRange(@($a,$n,$b,$dt,$ok,$ca));$d.AcceptButton=$ok;$d.CancelButton=$ca
 if($d.ShowDialog($form)-eq 'OK'){$script:percent=[int]$n.Value;$script:resetAt=$dt.Value;Save-Settings;UpdateUI};$d.Dispose()
}

$s=Load-Settings;$script:percent=[int]$s.Percent
$script:autoRefresh = if($null -eq $s.AutoRefresh){$true}else{[bool]$s.AutoRefresh}
$script:refreshMinutes = if($null -eq $s.RefreshMinutes){5}else{[math]::Max(1,[int]$s.RefreshMinutes)}
$script:lastAutoStatus = 'Auto: waiting'

try{$script:resetAt=[datetime]::Parse($s.ResetAt)}catch{$script:resetAt=(Get-Date).AddDays(7)}

$form=New-Object Windows.Forms.Form
$form.Text='Zen Master Usage Warden';$form.ClientSize='310,390';$form.FormBorderStyle='None';$form.MinimumSize=New-Object Drawing.Size(220,285);$form.MaximumSize=New-Object Drawing.Size(620,780)
$form.BackColor=[Drawing.Color]::Fuchsia;$form.TransparencyKey=[Drawing.Color]::Fuchsia
$form.TopMost=[bool]$s.AlwaysOnTop;$form.ShowInTaskbar=$true;$form.StartPosition='Manual';$form.Location=New-Object Drawing.Point([int]$s.X,[int]$s.Y)

$pet=New-Object Windows.Forms.PictureBox;$pet.Location='45,0';$pet.Size='220,158';$pet.SizeMode='Zoom';$pet.BackColor=[Drawing.Color]::Transparent;$form.Controls.Add($pet)

$panel=New-Object Windows.Forms.Panel;$panel.Location='5,172';$panel.Size='300,205';$panel.BackColor=[Drawing.Color]::FromArgb(10,38,65);$form.Controls.Add($panel)
$panel.Add_Paint({
 param($sender,$e)
 $g=$e.Graphics;$g.SmoothingMode='AntiAlias'
 $pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(95,210,255),2)
 $r=New-Object Drawing.Rectangle(1,1,($sender.Width-3),($sender.Height-3))
 $g.DrawRectangle($pen,$r);$pen.Dispose()
})

$title=New-Object Windows.Forms.Label;$title.Text='✦  CODEX FUEL';$title.ForeColor=[Drawing.Color]::White;$title.Font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold);$title.Location='18,10';$title.AutoSize=$true
$pin=New-Object Windows.Forms.Button;$pin.FlatStyle='Flat';$pin.FlatAppearance.BorderSize=0;$pin.ForeColor='White';$pin.BackColor=[Drawing.Color]::Transparent;$pin.Location='238,4';$pin.Size='26,28';$pin.Font=New-Object Drawing.Font('Segoe UI',12)
$close=New-Object Windows.Forms.Button;$close.Text='×';$close.FlatStyle='Flat';$close.FlatAppearance.BorderSize=0;$close.ForeColor='White';$close.BackColor=[Drawing.Color]::Transparent;$close.Location='267,4';$close.Size='26,28';$close.Font=New-Object Drawing.Font('Segoe UI',13)
$pct=New-Object Windows.Forms.Label;$pct.ForeColor=[Drawing.Color]::White;$pct.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold);$pct.Location='20,45';$pct.AutoSize=$true
$meter=New-Object Windows.Forms.Panel;$meter.Location='20,72';$meter.Size='260,18';$meter.BackColor=[Drawing.Color]::FromArgb(52,78,105)
$meter.Add_Paint({
 param($sender,$e)
 $v=[math]::Max(0,[math]::Min(100,$script:percent));$w=[int](($sender.Width-2)*$v/100)
 if($w -gt 0){
   $c=if($v -le 9){[Drawing.Color]::FromArgb(255,92,105)}elseif($v -le 24){[Drawing.Color]::FromArgb(255,139,64)}elseif($v -le 49){[Drawing.Color]::FromArgb(255,205,76)}else{[Drawing.Color]::FromArgb(91,231,126)}
   $br=New-Object Drawing.SolidBrush($c);$e.Graphics.FillRectangle($br,1,1,$w,$sender.Height-2);$br.Dispose()
 }
})
$reset=New-Object Windows.Forms.Label;$reset.ForeColor=[Drawing.Color]::White;$reset.Font=New-Object Drawing.Font('Segoe UI',9);$reset.Location='20,100';$reset.AutoSize=$true
$msg=New-Object Windows.Forms.Label;$msg.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold);$msg.Location='20,126';$msg.Size='260,34'
$update=New-Object Windows.Forms.Button;$update.Text='Refresh now';$update.Location='20,166';$update.Size='110,28';$update.FlatStyle='Flat';$update.ForeColor='White';$update.BackColor=[Drawing.Color]::FromArgb(30,71,104)
$hide=New-Object Windows.Forms.Button;$hide.Text='Hide';$hide.Location='140,166';$hide.Size='70,28';$hide.FlatStyle='Flat';$hide.ForeColor='White';$hide.BackColor=[Drawing.Color]::FromArgb(30,71,104)
$status=New-Object Windows.Forms.Label;$status.Text=$script:lastAutoStatus;$status.ForeColor=[Drawing.Color]::FromArgb(160,210,230);$status.Font=New-Object Drawing.Font('Segoe UI',7.5);$status.Location='215,172';$status.Size='78,28'

$panel.Controls.AddRange(@($title,$pin,$close,$pct,$meter,$reset,$msg,$update,$hide,$status))

$sizeBtn=New-Object Windows.Forms.Button
$sizeBtn.Text='−'
$sizeBtn.FlatStyle='Flat';$sizeBtn.FlatAppearance.BorderSize=0
$sizeBtn.ForeColor='White';$sizeBtn.BackColor=[Drawing.Color]::Transparent
$sizeBtn.Location='212,4';$sizeBtn.Size='24,28';$sizeBtn.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
$panel.Controls.Add($sizeBtn)
$script:compact=$false
$sizeBtn.Add_Click({
  if(-not $script:compact){
    $script:compact=$true
    $form.ClientSize='245,310'
    $pet.Location='45,0';$pet.Size='155,112'
    $panel.Location='5,108';$panel.Size='235,195'
    $title.Location='12,8';$title.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
    $pin.Location='177,2';$close.Location='205,2';$sizeBtn.Location='150,2';$sizeBtn.Text='□'
    $pct.Location='14,39';$pct.Font=New-Object Drawing.Font('Segoe UI',9,[Drawing.FontStyle]::Bold)
    $meter.Location='14,64';$meter.Size='207,13'
    $reset.Location='14,86';$reset.Font=New-Object Drawing.Font('Segoe UI',7.5)
    $msg.Location='14,108';$msg.Size='207,31';$msg.Font=New-Object Drawing.Font('Segoe UI',8,[Drawing.FontStyle]::Bold)
    $update.Location='14,153';$update.Size='96,27';$hide.Location='118,153';$hide.Size='60,27';$status.Location='181,153';$status.Size='48,30';$status.Font=New-Object Drawing.Font('Segoe UI',6.5)
  } else {
    $script:compact=$false
    $form.ClientSize='310,390'
    $pet.Location='45,0';$pet.Size='220,158'
    $panel.Location='5,172';$panel.Size='300,205'
    $title.Location='18,10';$title.Font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold)
    $pin.Location='238,4';$close.Location='267,4';$sizeBtn.Location='212,4';$sizeBtn.Text='−'
    $pct.Location='20,45';$pct.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
    $meter.Location='20,72';$meter.Size='260,18'
    $reset.Location='20,100';$reset.Font=New-Object Drawing.Font('Segoe UI',9)
    $msg.Location='20,126';$msg.Size='260,34';$msg.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
    $update.Location='20,166';$update.Size='110,28';$hide.Location='140,166';$hide.Size='70,28';$status.Location='215,172';$status.Size='78,28';$status.Font=New-Object Drawing.Font('Segoe UI',7.5)
  }
  $panel.Invalidate();$meter.Invalidate()
})



$ctx=New-Object Windows.Forms.ContextMenuStrip
$miManual=$ctx.Items.Add('Manual Update Usage')
$miManual.Add_Click({EditUsage})
$miDiag=$ctx.Items.Add('Show Auto Diagnostics')
$miDiag.Add_Click({
  $path=if($script:lastCodexPath){$script:lastCodexPath}else{'(not found)'}
  $err=if($script:lastAutoError){$script:lastAutoError}else{'No error recorded.'}
  [Windows.Forms.MessageBox]::Show("Codex executable:`r`n$path`r`n`r`nAuto status:`r`n$($script:lastAutoStatus)`r`n`r`nLast error:`r`n$err",'Zen Master Auto Diagnostics','OK','Information')|Out-Null
})
$status.ContextMenuStrip=$ctx
$update.ContextMenuStrip=$ctx

$tip=New-Object Windows.Forms.ToolTip;$tip.SetToolTip($pin,'Toggle Always on Top');$tip.SetToolTip($hide,'Hide Zen Master')
$script:drag=$false
$down={param($s,$e)if($e.Button -eq 'Left'){$script:drag=$true;$p=[Windows.Forms.Cursor]::Position;$script:off=New-Object Drawing.Point(($p.X-$form.Left),($p.Y-$form.Top))}}
$move={if($script:drag){$p=[Windows.Forms.Cursor]::Position;$form.Location=New-Object Drawing.Point(($p.X-$script:off.X),($p.Y-$script:off.Y))}}
$up={$script:drag=$false;Save-Settings}
foreach($c in @($form,$pet,$panel,$title)){$c.Add_MouseDown($down);$c.Add_MouseMove($move);$c.Add_MouseUp($up)}

$pin.Add_Click({$form.TopMost=-not $form.TopMost;Save-Settings;UpdateUI})
$update.Add_Click({Refresh-FromCodex})
$hide.Add_Click({$form.WindowState=[Windows.Forms.FormWindowState]::Minimized})
$close.Add_Click({Save-Settings;$form.Close()})


$timer=New-Object Windows.Forms.Timer;$timer.Interval=30000;$timer.Add_Tick({UpdateUI});$timer.Start()
$autoTimer=New-Object Windows.Forms.Timer
$autoTimer.Interval=[int]($script:refreshMinutes*60*1000)
$autoTimer.Add_Tick({if($script:autoRefresh){Refresh-FromCodex}})
$autoTimer.Start()

UpdateUI
if($script:autoRefresh){Refresh-FromCodex}
[void]$form.ShowDialog()
$timer.Stop();$autoTimer.Stop()
