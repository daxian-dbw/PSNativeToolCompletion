using namespace System.Management.Automation.Language

[scriptblock]$cover_all_completion = {
    param(
        [string] $wordToComplete,
        [CommandAst] $commandAst,
        [int] $cursorPosition
    )

    $compDir = Join-Path $PSScriptRoot 'completion'
    $command = [System.IO.Path]::GetFileNameWithoutExtension($commandAst.GetCommandName())
    $compFile = Join-Path $compDir "__${command}.ps1"

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

Register-ArgumentCompleter -NativeFallback -ScriptBlock $cover_all_completion
