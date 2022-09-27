# The MIT License (MIT) Copyright © 2020 Koninklijke Philips N.V, https://www.philips.com

New-Item -ItemType Directory -Path C:\actions-runner ; Set-Location C:\actions-runner
Invoke-WebRequest -Uri ${action_runner_url} -OutFile actions-runner.zip
Expand-Archive -Path actions-runner.zip -DestinationPath .
Remove-Item actions-runner.zip

$action = New-ScheduledTaskAction -WorkingDirectory "C:\actions-runner" -Execute "PowerShell.exe" -Argument "-File C:\start-runner.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName "runnerinit" -Action $action -Trigger $trigger -User System -RunLevel Highest -Force
