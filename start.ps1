# PowerShell single-command launcher for Jugaad App
param (
    [switch]$Web,
    [switch]$All,
    [switch]$BackendOnly,
    [switch]$Windows,
    [string]$Device = ""
)

$argsList = @()
if ($Web) { $argsList += "--web" }
if ($All) { $argsList += "--all" }
if ($BackendOnly) { $argsList += "--backend-only" }
if ($Windows) { $argsList += "-w" }
if ($Device) { $argsList += "-d", $Device }

python "$PSScriptRoot\run_all.py" @argsList
