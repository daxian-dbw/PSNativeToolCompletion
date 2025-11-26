## PSNativeToolCompletion

This PowerShell module enables lazy loading of argument completion scripts for native commands.
It leverages the new 'fall-back' completer for native commands -- `Register-ArgumentCompleter -NativeFallback`.

When tab completion is triggered for a native command,
it checks for a corresponding completion script,
loads and registers it on-demand,
and then provides completions—minimizing startup overhead and only loading completion logic as needed.
