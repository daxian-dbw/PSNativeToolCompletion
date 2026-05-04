using namespace System.Management.Automation.Language

$fsprod = Get-PSProvider -PSProvider FileSystem -ErrorAction Stop
$Script:CompDir = Join-Path $fsprod.Home '.pwsh' 'completions'

if (-not (Test-Path $Script:CompDir -PathType Container)) {
    $null = New-Item $Script:CompDir -ItemType Directory -ErrorAction Stop
}

[scriptblock]$cover_all_completion = {
    param(
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [int] $cursorPosition
    )

    $command = [System.IO.Path]::GetFileNameWithoutExtension($commandAst.GetCommandName())
    $compFile = Join-Path $Script:CompDir "__${command}.ps1"

    if (Test-Path $compFile) {
        $compAst = [Parser]::ParseFile($compFile, [ref]$null, [ref]$null)
        $compScript = $compAst.GetScriptBlock()

        ## Register completer for the native command lazily, upon the first tab completion on the command.
        $compModule = New-Module -Name "completion-${command}" -ScriptBlock $compScript
        $compModule = Import-Module $compModule -Global -PassThru

        ## Try to trigger the completion script block for the current tab.
        $toolCompSb = $null
        $sbArgument = Find-NativeCompleter -CompAst $compAst

        if ($sbArgument -is [VariableExpressionAst]) {
            $sbVarName = $sbArgument.VariablePath.UserPath
            $toolCompSb = & $compModule Get-Variable $sbVarName -ValueOnly
        }
        elseif ($sbArgument -is [ScriptBlockExpressionAst]) {
            $toolCompSb = $sbArgument.ScriptBlock.GetScriptBlock()
        }

        if ($toolCompSb) {
            & $compModule $toolCompSb $wordToComplete $commandAst $cursorPosition
        }
    }
}

## Register the 'fall-back' completer for native commands.
Register-ArgumentCompleter -NativeFallback -ScriptBlock $cover_all_completion

function Get-CompletionScript {
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Position = 0)]
        [string[]] $Command
    )

    Write-Verbose "Completion script folder: $Script:CompDir"

    if (Test-Path $Script:CompDir) {
        try {
            Push-Location $Script:CompDir

            if ($Command) {
                $processedNames = $Command | ForEach-Object { "__$_.ps1" }
                Get-ChildItem $processedNames
            }
            else {
                Get-ChildItem
            }
        }
        finally {
            Pop-Location
        }
    }
}

function Add-CompletionScript {
    param(
        [Parameter(Mandatory)]
        [string] $Command,

        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $InputScript,

        [Parameter()]
        [switch] $AllowExtensionCompletion
    )

    Begin {
        $list = [System.Collections.Generic.List[string]]::new()
    }

    Process {
        $list.Add($InputScript)
    }

    End {
        $script = $list.Count -gt 1 ? $list -join "`n" : $list[0]
        $path = Join-Path $Script:CompDir "__$Command.ps1"
        Set-Content -Path $path -Value $script -NoNewline -ErrorAction Stop

        if ($AllowExtensionCompletion) {
            WrapNativeCompleter -ScriptPath $path -Overwrite
        }
    }
}

$Script:WrapSbName = '__wrap_completer'
$Script:WrapSbContent = @'
${{__wrap_completer}} = {{
    param($WordToComplete, $CommandAst, $CursorPosition)

    try {{
        $result = & ${0} $WordToComplete $CommandAst $CursorPosition
        if ($null -ne $result -and ($result -isnot [string] -or $result -ne '')) {{
            return $result
        }}
    }} catch {{
        ## Exception thrown. No completion results.
    }}

    {1}
}}
'@

$Script:ExtensionSb = {
    param($WordToComplete, $CommandAst, $CursorPosition)

    $command = $null
    $elements = $CommandAst.CommandElements
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $ele = $elements[$i]
        if ($ele -isnot [StringConstantExpressionAst]) {
            break
        }

        if ($ele.Value.StartsWith('-')) {
            break
        }

        $eleValue = $ele.Value
        if ($ele.Extent.StartOffset -gt $CursorPosition) {
            break
        }

        $command += "_$eleValue"
    }

    if ($command) {
        $prefix = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
        if ($WordToComplete -and $command.EndsWith($WordToComplete)) {
            $candidates = [System.IO.Directory]::EnumerateFiles($PSScriptRoot, "${prefix}${command}*.ps1") |
                ForEach-Object {
                    $name = [System.IO.Path]::GetFileNameWithoutExtension($_)
                    $start = $name.LastIndexOf('_', $prefix.Length + $command.Length - 1)
                    if ($name.IndexOf('_', $start + 1) -eq -1) {
                        $name.Substring($start + 1)
                    }
                }

            if ($candidates) {
                return $candidates
            }
        }
        else {
            $extensionScript = Join-Path $PSScriptRoot "${prefix}${command}.ps1"
            if (Test-Path $extensionScript -PathType Leaf) {
                return & $extensionScript $WordToComplete $CommandAst $CursorPosition
            }
        }
    }
}

function WrapperScript {
    param($CompSbVerName)

    $extSbAst = $Script:ExtensionSb.Ast
    $endBlockText = $extSbAst.EndBlock.Extent.Text
    $paramBlockText = $extSbAst.ParamBlock.Extent.Text
    $Script:WrapSbContent -f $CompSbVerName, $endBlockText.SubString($paramBlockText.Length)
}

function WrapNativeCompleter {
    param([string] $ScriptPath, [switch] $Overwrite)

    $ScriptPath = (Resolve-Path $ScriptPath).ProviderPath
    $compAst = [Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
    $completer = Find-NativeCompleter -CompAst $compAst

    if ($completer) {
        $cmdAst = $completer.Parent
        $indents = ' ' * $cmdAst.Extent.StartColumn
    }

    if ($completer -is [VariableExpressionAst]) {
        ## Insert the wrapper script block definition.
        $sbVarName = $completer.VariablePath.UserPath
        $wrapper = WrapperScript -CompSbVerName $sbVarName
        $insertText = @"
${wrapper}

${indents}
"@
    }
    elseif ($completer -is [ScriptBlockExpressionAst]) {
        $wrapper = WrapperScript -CompSbVerName '__original_completer'
        $insertText = @"
`${__original_completer} = $sbText

${indents}${wrapper}

${indents}
"@
    }
    else {
        throw "Unsupported script block argument type: $($completer.GetType().FullName)"
    }

    if ($insertText) {
        $content = Get-Content $ScriptPath -Raw
        $normalizeCR = $IsWindows -and -not $content.Contains("`r`n")

        ## Replace the original completer script block variable with the new wrapper script block variable.
        $start = $completer.Extent.StartOffset
        $length = $completer.Extent.Text.Length
        $content = $content.Remove($start, $length)
        $content = $content.Insert($start, "`${$Script:WrapSbName}")

        ## Insert the wrapper script block definition.
        if ($normalizeCR) {
            $insertText = $insertText.Replace("`r`n", "`n")
        }

        $target = $Overwrite ? $ScriptPath : "$ScriptPath.bak"
        $content.Insert($cmdAst.Extent.StartOffset, $insertText) | Set-Content $target -NoNewline -ErrorAction Stop
    }
}

function Find-NativeCompleter {
    param([ScriptBlockAst] $CompAst)

    $cmdAst = $CompAst.Find({
        param($ast)
        $ast -is [CommandAst] -and $ast.GetCommandName() -eq 'Register-ArgumentCompleter'
    }, $false)

    if ($cmdAst) {
        $sbArgIndex = [int]::MaxValue
        $elements = $cmdAst.CommandElements

        for ($i = 1; $i -lt $elements.Count; $i++) {
            $item = $elements[$i]
            if ($item -is [CommandParameterAst] -and $item.ParameterName -eq 'ScriptBlock') {
                ## Found the '-ScriptBlock' parameter. The next element will be the argument.
                $sbArgIndex = $i + 1
                break
            }
        }

        if ($sbArgIndex -lt $elements.Count) {
            $sbArgument = $elements[$sbArgIndex]
            return $sbArgument
        }
    }
}
