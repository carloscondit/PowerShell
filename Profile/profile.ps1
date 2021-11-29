<#
Как использовать один файл для всех версий PowerShell. TL;DR Dot-sourcing
https://www.networkadm.in/configure-one-powershell-profile-for-many-users/
#>
#region Preferences
# Устанавливаем корневую папку            
$Root = "C:\Distr"             
            
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
"$Root", "$Root\Scripts" | ForEach-Object {            
  Write-Verbose "Добавляем в переменную среду Path каталог ""$_"""            
  $env:path += ";$_"            
}

# Изменяем цвета текста, чтобы было легче читать.
$PSReadlineModule = Get-Module PSReadline
if ($IsCoreCLR) {
  $esc = "`e"
}
else {
  $esc = $([char]0x1b)
}

$Colors = @{
  Parameter = "$esc[96m"
  Operator  = "$esc[38;5;47m"
  Comment   = "$esc[92m"
  String    = "$esc[38;5;51m"
}

$PSReadLineParams = @{}
# Если это не PowerShell ISE и версия модуля PSReadLine выше или равна 2.2.0, то добавляем в параметры команды Set-PSReadLineOption
# включение функции автодополения на основе истории команд и добавляем в массив Colors цвет этих подсказок
if ((!$psISE) -and ($PSReadlineModule.version -ge '2.2.0')) {
  $PSReadLineParams.Add('PredictionSource', 'History')
  $Colors.Add('InlinePrediction', "$esc[38;2;47;112;4m")
}
$PSReadLineParams.Add('Colors', $Colors)
Set-PSReadLineOption @PSReadLineParams
#endregion

#region Functions
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

#Добавялем функцию для расшифровки кодов ошибок в текст с помощью утилиты certutil.
#Подробнее тут https://www.outsidethebox.ms/19362/
Function Convert-Error {
  param ([int]$Err = "")
  #Перед отправкой кода ошибки утилите certutil, нужно его сконвертировать
  #в HEX. Для этого используется оператор -f и его спецификатор 'X'.
  certutil -error $('0x{0:X}' -f $err)
  #Альтернативный метод перевода кода ошибки в HEX, используя метод ToString
  #со спецификатором 'X'.
  #certutil -error $('0x'+($err).ToString("X"))
}

#Добавляем функции для удобного ежедневного открытия рандомых справок по командлетам и about топикам
function Get-RandomAboutTopic {
  Get-Random -input (Get-Help about*) | Get-Help -ShowWindow    
}

function Get-RandomWindowsHelp {
  Get-Command -Module Microsoft*, Cim*, PS*, ISE | Get-Random | Get-Help -ShowWindow    
}

# Добавляем функцию приглашения, чтобы было видно с какими правами запущен процесс PowerShell.
# А также строчку оповедение о приближени Нового Года.
# Подробнее про оповещение тут: https://jdhitsolutions.com/blog/powershell/7956/friday-fun-a-powershell-christmas-prompt/
# А про изменение самой строки приглашения: https://xaegr.wordpress.com/2009/06/01/myprofile/
Function Prompt {
  $now = Get-Date
  if ($now.DayOfYear -eq (Get-Date -Year $now.Year -Month 12 -Day 11).DayOfYear) {
    if ($env:wt_Session -OR ($host.name -match "studio")) {
      #При необходимости добавляем скрипт с функциями конвертирования эмоджи
      # Подробнее тут: https://gist.github.com/jdhitsolutions/31e20c58645b59e42725f0aac0297b6f
      #. C:\Distr\Scripts\Fun\PSEmoji.ps1
      #Получаем следующий год
      $NextYear = ($now.AddYears(1)).Year
      #Получаем количество времени до нового года
      $time = [datetime]"1 January $NextYear" - $now
      #Превращаем это время в строку без милисекунд
      $timestring = $time.ToString("dd' дней и 'hh':'mm':'ss")
      #Получаем рандомную строку из декоративных символов
      #Можно указать конкретный эмоджи или сконвертировать из значений, если доступна функция ConvertTo-Emoji
      # $Snow = ""
      # $shootingStar = ConvertTo-Emoji 127776
      $snow = "❄"
      $sparkles = "✨"
      $snowman = "⛄"
      $santa = "🎅"
      $mrsClaus = "🤶"
      $tree = "🎄"
      $present = "🎁"
      $notes = "🎵"
      $bow = "🎀"
      $star = "🌟"
      $shootingStar = "🌠"
      $myChars = $santa, $mrsClaus, $tree, $present, $notes, $bow, $star, $shootingStar, $snow, $snowman, $sparkles
      #Получаем несколько рандомных символов 
      $front = -join ($myChars | Get-Random -Count 2)
      $back = -join ($myChars | Get-Random -Count 2)
      
      #Формируем саму строку
      $text = "Новый год наступит через $timestring"
      
      #Получаем каждый символ из строки и рандомно назначаем ему цвет из ANSI последовательности
      $colorText = $text.tocharArray() | ForEach-Object {
        $i = Get-Random -Minimum 1 -Maximum 50
        switch ($i) {
          { $i -le 50 -AND $i -ge 45 } { $seq = "$esc[1;5;38;5;199m" }
          { $i -le 45 -AND $i -ge 40 } { $seq = "$esc[1;5;38;11;199m" }
          { $i -le 40 -AND $i -ge 30 } { $seq = "$esc[1;38;5;50m" }
          { $i -le 20 -and $i -gt 15 } { $seq = "$esc[1;5;38;5;1m" }
          { $i -le 16 -and $i -gt 10 } { $seq = "$esc[1;38;5;47m" }
          { $i -le 10 -and $i -gt 5 } { $seq = "$esc[1;5;38;5;2m" }
          default { $seq = "$esc[1;37m" }
        }
        "$seq$_$esc[0m"
      } #foreach
      
      #Пишем эту строку в консоль на отдельную линию
      Write-Host "$front $($colortext -join '') $back" #-NoNewline #-foregroundcolor $color
    } #if Host is Windows Terminal or VS code
  } #If December 
  if ($PSReadlineModule.Version -eq '2.0.0') {
    Write-Host "Внимание! Используемая версия модуля 'PSReadline' с багом. Обновите её." -ForegroundColor Red
  }  
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
} #end function Prompt

#Это прокси-функция для Get-Help. Она проверяет наличие у командлета онлайн справки и если такая есть, то по умолчанию открывате ее.
#Если онлайн справки нет, то вместо ошибки откроет локальную справку в консоли.
#Взял отсюда: https://community.idera.com/database-tools/powershell/powertips/b/tips/posts/better-powershell-help-part-3
function Get-Help {
  #Клонируем блок параметров из оригинального командлета Get-Help
  [CmdletBinding(DefaultParameterSetName = 'AllUsersView', HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=113316')]
  param(
    [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
    [string]
    $Name,

    [Parameter(ParameterSetName = 'Online', Mandatory)]
    [switch]
    $Online,

    [ValidateSet('Alias', 'Cmdlet', 'Provider', 'General', 'FAQ', 'Glossary', 'HelpFile', 'ScriptCommand', 'Function', 'Filter', 'ExternalScript', 'All', 'DefaultHelp', 'Workflow', 'DscResource', 'Class', 'Configuration')]
    [string[]]
    $Category,

    [string]
    $Path,

    [string[]]
    $Component,

    [string[]]
    $Functionality,

    [string[]]
    $Role,

    [Parameter(ParameterSetName = 'DetailedView', Mandatory)]
    [switch]
    $Detailed,

    [Parameter(ParameterSetName = 'AllUsersView')]
    [switch]
    $Full,

    [Parameter(ParameterSetName = 'Examples', Mandatory)]
    [switch]
    $Examples,

    [Parameter(ParameterSetName = 'Parameters', Mandatory)]
    [string]
    $Parameter,

    [Parameter(ParameterSetName = 'ShowWindow', Mandatory)]
    [switch]
    $ShowWindow
  )

  #блоки begin, process, и end нужны для работы конвейера
  begin {
    #Мы будем вносить изменения в команду только если указаны параметры
    #-Name, -Category, и -Online
    if ( (@($PSBoundParameters.Keys) -ne 'Name' -ne 'Category' -ne 'Online').Count -eq 0) {
      #Проверяем доступность онлайн справки
      $help = Microsoft.PowerShell.Core\Get-Command -Name $Name 
      #Меняем значение парметра -Online в зависимости от доступности онлайн справки
      $PSBoundParameters['Online'] = [string]::IsNullOrWhiteSpace($help.HelpUri) -eq $false
    }#if parameters exist
    
    #После внесения изменений в параметры вызываем оригинальнуый команлет Get-Help с
    #параметрами из $PSBoundParameters
    $cmd = Get-Command -Name 'Get-Help' -CommandType Cmdlet
    $proxy = { & $cmd @PSBoundParameters }.GetSteppablePipeline($myInvocation.CommandOrigin)
    $proxy.Begin($PSCmdlet)
  }#begin
    
  process { $proxy.Process($_) }
    
  end { $proxy.End() }
    
  #справка от оригинального командлета Get-Help для этой прокси-функции
  <#
      .ForwardHelpTargetName Microsoft.PowerShell.Core\Get-Help
      .ForwardHelpCategory Cmdlet
  #>
}#end proxy-function Get-Help
#endregion
