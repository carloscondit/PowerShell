<#
Как использовать один файл для всех версий PowerShell. TL;DR Dot-sourcing
https://www.networkadm.in/configure-one-powershell-profile-for-many-users/
#>

#Добавляем пространства имен для работы умной подстановки знаков (Smart Insert/Delete)
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

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

# Добавляем функцию PSReadLine, которая не будет сохранять пароли в историю модуля
# https://twitter.com/lee_holmes/status/1172640465767682048
Set-PSReadLineOption -AddToHistoryHandler {
  param([string]$line)

  $sensitive = "password|asplaintext|token|key|secret"
  return ($line -notmatch $sensitive)
}

#Добавляем на клавишу Enter функцию по проверке синтаксиса команды перед ее выполнением
Set-PSReadLineKeyHandler -Chord 'Enter' -Function ValidateAndAcceptLine
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

#region Smart Insert/Delete
#https://github.com/PowerShell/PSReadLine/blob/master/PSReadLine/SamplePSReadLineProfile.ps1

# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience.  I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.
<#
Следующие 4 обработчика знаков написаны для упрощения ввода. При вводе символов 
открывающих одинарных/двойных кавычек или скобок автоматически добавлятеся закрывающий символ.
Также происходит с удалением этих знаков. В начале этого файла добавляются
необходимые пространства имен. Без них работать не будет.
#>

Set-PSReadLineKeyHandler -Key '"', "'" `
  -BriefDescription SmartInsertQuote `
  -LongDescription "Insert paired quotes if not already on a quote" `
  -ScriptBlock {
  param($key, $arg)

  $quote = $key.KeyChar

  $selectionStart = $null
  $selectionLength = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

  $line = $null
  $cursor = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

  # If text is selected, just quote it without any smarts
  if ($selectionStart -ne -1) {
    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    return
  }

  $ast = $null
  $tokens = $null
  $parseErrors = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

  function FindToken {
    param($tokens, $cursor)

    foreach ($token in $tokens) {
      if ($cursor -lt $token.Extent.StartOffset) { continue }
      if ($cursor -lt $token.Extent.EndOffset) {
        $result = $token
        $token = $token -as [StringExpandableToken]
        if ($token) {
          $nested = FindToken $token.NestedTokens $cursor
          if ($nested) { $result = $nested }
        }

        return $result
      }
    }
    return $null
  }

  $token = FindToken $tokens $cursor

  # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
  if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
    # If we're at the start of the string, assume we're inserting a new string
    if ($token.Extent.StartOffset -eq $cursor) {
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
      return
    }

    # If we're at the end of the string, move over the closing quote if present.
    if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
      return
    }
  }

  if ($null -eq $token -or
    $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket) {
    if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1) {
      # Odd number of quotes before the cursor, insert a single quote
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
    }
    else {
      # Insert matching quotes, move cursor to be in between the quotes
      [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    return
  }

  # If cursor is at the start of a token, enclose it in quotes.
  if ($token.Extent.StartOffset -eq $cursor) {
    if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or 
      $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword)) {
      $end = $token.Extent.EndOffset
      $len = $end - $cursor
      [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
      [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
      return
    }
  }

  # We failed to be smart, so just insert a single quote
  [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
}

Set-PSReadLineKeyHandler -Key '(', '{', '[' `
  -BriefDescription InsertPairedBraces `
  -LongDescription "Insert matching braces" `
  -ScriptBlock {
  param($key, $arg)

  $closeChar = switch ($key.KeyChar) {
    <#case#> '(' { [char]')'; break }
    <#case#> '{' { [char]'}'; break }
    <#case#> '[' { [char]']'; break }
  }

  $selectionStart = $null
  $selectionLength = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

  $line = $null
  $cursor = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    
  if ($selectionStart -ne -1) {
    # Text is selected, wrap it in brackets
    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
  }
  else {
    # No text is selected, insert a pair
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
  }
}

Set-PSReadLineKeyHandler -Key ')', ']', '}' `
  -BriefDescription SmartCloseBraces `
  -LongDescription "Insert closing brace or skip" `
  -ScriptBlock {
  param($key, $arg)

  $line = $null
  $cursor = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

  if ($line[$cursor] -eq $key.KeyChar) {
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
  }
  else {
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
  }
}

Set-PSReadLineKeyHandler -Key Backspace `
  -BriefDescription SmartBackspace `
  -LongDescription "Delete previous character or matching quotes/parens/braces" `
  -ScriptBlock {
  param($key, $arg)

  $line = $null
  $cursor = $null
  [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

  if ($cursor -gt 0) {
    $toMatch = $null
    if ($cursor -lt $line.Length) {
      switch ($line[$cursor]) {
        <#case#> '"' { $toMatch = '"'; break }
        <#case#> "'" { $toMatch = "'"; break }
        <#case#> ')' { $toMatch = '('; break }
        <#case#> ']' { $toMatch = '['; break }
        <#case#> '}' { $toMatch = '{'; break }
      }
    }

    if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch) {
      [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
    }
    else {
      [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
    }
  }
}

#endregion Smart Insert/Delete
