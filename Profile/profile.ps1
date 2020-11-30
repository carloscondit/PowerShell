# Устанавливаем корневую папку            
$Root = "c:\Distr"             
            
# Переходим в каталог со скриптами           
Set-Location "$Root\Scripts"             
            
# Включаем отладочную и дополнительную информацию по умолчанию (чтобы не приходилось указывать ключ -Verbose)            
$VerbosePreference = "Continue"            
$DebugPreference = "Continue"

# Проверяем, обладает ли пользователь повышенными привилегиями (Позаимствовано из PSCX)            
$IsElevated = $false            
foreach ($sid in [Security.Principal.WindowsIdentity]::GetCurrent().Groups) {            
  if ($sid.Translate([Security.Principal.SecurityIdentifier]).IsWellKnown([Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid)) {            
    $IsElevated = $true            
  }            
}

# Добавляем папки с утилитами в $env:path            
"$Root","$Root\Scripts" | ForEach-Object {            
  Write-Verbose "`t$_"            
  $env:path += ";$_"            
}
# Добавляем функции sudo и resudo, чтобы можно было запускать/перезапускать команды с правами администратора одной командой не выходя из консоли
# Источник http://www.outsidethebox.ms/20532/

function resudo (
  [switch]$NoProfile
) {
  $cmdline = "-NoExit -command $((Get-History)[-1].commandline)"
  if ($NoProfile) { $cmdline = "-NoProfile $cmdLine" }
  Start-Process -FilePath powershell -ArgumentList $cmdline -Verb runas
}
 
function sudo (
  [scriptblock]$sb,
  [switch]$NoProfile
) {
  $cmdline = "-NoExit -command $sb"
  if ($NoProfile) { $cmdline = "-NoProfile $cmdLine" }
  Start-Process -FilePath powershell -ArgumentList $cmdline -Verb runas
}

# Изменяем цвета текста, чтобы было легче читать.
if ($IsCoreCLR) {
  $esc = "`e"
}
else {
  $esc = $([char]0x1b)
}
 
Set-PSReadLineOption -Colors @{
  Parameter        = "$esc[96m"
  Operator         = "$esc[38;5;47m"
  Comment          = "$esc[92m"
  String           = "$esc[38;5;51m"
  InlinePrediction = "$esc[38;2;47;112;4m"
}

# Если это не PowerShell ISE и версия модуля PSReadLine выше или равна 2.2.0, то добавляем функцию автодополения на основе истории команд. 
if ((!$psISE) -and ((Get-Module PSReadline).version -ge '2.2.0')) {
  Set-PSReadLineOption -PredictionSource History
}

# Добавляем функцию приглашения, чтобы было видно с какими правами запущен процесс PowerShell
function prompt {            
  [Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath            
  $path = (Get-Location).path -replace '^(.*?[^:]:\\).+(\\.+?)$', ('$1' + [char]8230 + '$2') -replace '^.+?::' -replace '^(\\\\.+?\\).+(\\.+?)$', ('$1' + [char]8230 + '$2')            
  $id = ([int](Get-History -Count 1).Id) + 1            
  $prefix = "[PS <$id> "            
  if ($NestedPromptLevel) { $prefix += "($NestedPromptLevel) " }            
  if ($isElevated) { $Color = "Red" } else { $Color = "White" }            
  write-host $prefix -ForegroundColor $Color -NonewLine            
  write-host ($path) -foregroundcolor "Gray" -NonewLine            
  write-host "]" -ForegroundColor $Color -NonewLine            
  " "            
}     