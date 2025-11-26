using namespace System.Management.Automation.Language

$fsprod = Get-PSProvider -PSProvider FileSystem -ErrorAction Stop
$Script:CompDir = Join-Path $fsprod.Home '.pwsh' 'completions'

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
        $cmdAst = $compAst.Find({
            param($ast)
            $ast -is [CommandAst] -and $ast.GetCommandName() -eq 'Register-ArgumentCompleter'
        }, $false)

        if ($cmdAst) {
            $sbArgIndex = [int]::MaxValue
            $elements = $cmdAst.CommandElements

            for ($i = 1; $i -le $elements.Count; $i++) {
                $item = $elements[$i]
                if ($item -is [CommandParameterAst] -and $item.ParameterName -eq 'ScriptBlock') {
                    ## Found the '-ScriptBlock' parameter. The next element will be the argument.
                    $sbArgIndex = $i + 1
                    break
                }
            }

            if ($sbArgIndex -le $elements.Count) {
                $toolCompSb = $null
                $sbArgument = $elements[$sbArgIndex]

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
        [string] $InputScript
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
        Set-Content -Path $path -Value $script -ErrorAction Stop
    }
}
