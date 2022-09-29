# The MIT License (MIT) Copyright © 2020 Koninklijke Philips N.V, https://www.philips.com
Start-Transcript -Path "C:\runner-startup.log" -Append

# Create or update user
$run_as="runner-runner"
Add-Type -AssemblyName "System.Web"
$password = [System.Web.Security.Membership]::GeneratePassword(24, 4)
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$username = $run_as
if (!(Get-LocalUser -Name $username -ErrorAction Ignore)) {
    New-LocalUser -Name $username -Password $securePassword
    Write-Host "Created new user ($username)"
}
else {
    Set-LocalUser -Name $username -Password $securePassword
    Write-Host "Changed password for user ($username)"
}
# Add user to groups
foreach ($group in @("Administrators")) {
    if ((Get-LocalGroup -Name "$group" -ErrorAction Ignore) -and
        !(Get-LocalGroupMember -Group "$group" -Member $username -ErrorAction Ignore)) {
        Add-LocalGroupMember -Group "$group" -Member $username
        Write-Host "Added $username to $group group"
    }
}

Push-Location C:\actions-runner

$configCmd = "${runner_config} --unattended --name ${runner_name} --work `"_work`""
Write-Host "Configure GH Runner as user $run_as"
Invoke-Expression $configCmd

Write-Host "Starting the runner as user $run_as"

Write-Host  "Installing the runner as a service"

$action = New-ScheduledTaskAction -WorkingDirectory "C:\actions-runner" -Execute "run.cmd"
$trigger = Get-CimClass "MSFT_TaskRegistrationTrigger" -Namespace "Root/Microsoft/Windows/TaskScheduler"
Register-ScheduledTask -TaskName "runnertask" -Action $action -Trigger $trigger -User $username -Password $password -RunLevel Highest -Force
Write-Host "Starting the runner in persistent mode"
Write-Host "Starting runner after $(((get-date) - (gcim Win32_OperatingSystem).LastBootUpTime).tostring("hh':'mm':'ss''"))"

Pop-Location

Stop-Transcript
