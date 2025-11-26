# PSNativeToolCompletion

This PowerShell module enables lazy loading of argument completion scripts for native commands.
It leverages the new 'fall-back' completer for native commands -- `Register-ArgumentCompleter -NativeFallback` (introduced in PowerShell v7.6).

When tab completion is triggered for a native command, it checks for a corresponding completion script,
loads and registers it on-demand, and then provides completions.
It minimizes startup overhead and only loads completion logic as needed.

## Installing latest version from main

### Prerequisites

1. The `PSResourceGet` module is installed.
2. A `SecretVault` is created called `default`.

### Instructions

#### Setup a PAT to read the feed.

Create a [Personal Access Token (Classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) with `package:read` permission.
At the time of writing, this is the only type of token that allows these premissions.

```powershell
## The command should prompt for the secret.
Set-Secret -Name GitHubPackageRead
```

Register the Repository.
This assumes you called you vault `default` as described in the prerequisites.

```powershell
Register-PSResourceRepository `
    -name daxian-dbw `
    -uri https://nuget.pkg.github.com/daxian-dbw/index.json `
    -ApiVersion V3 `
    -CredentialInfo @{ VaultName='default'; SecretName='GitHubPackageRead' } `
    -Trusted
```

Then, you can install the module:

```powershell
Install-PSResource -Name PSNativeToolCompletion -Repository daxian-dbw
```
