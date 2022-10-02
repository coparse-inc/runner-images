################################################################################
##  File:  Install-Imdisk.ps1
##  Desc:  Install Imdisk (from Arsenal Image Mounter)
################################################################################

# Download the latest imdiskinst.exe
$imdiskDir = "C:\imdisk"
$imdiskName = "imdiskinst.exe"
$imdiskPath = "$imdiskDir\$imdiskName"
New-Item -Path $imdiskDir -ItemType Directory
# Should probably just mirror this, unreliable HTTP-only isn't great for a device driver
Start-DownloadWithRetry -Url "http://www.ltr-data.se/files/imdiskinst.exe" -Name $imdiskName -DownloadPath $imdiskDir
$hash = (Get-FileHash $imdiskPath).Hash

if ($hash -ne "cdcd8e76e6e631b66318b743fd3a5ee2c270c1509fdb5679f2b78c6332859a02") {
  Write-Host "[Error]: Unable to validate imdisk installer"
  Write-Host $hash
  exit 1
}

# Install
$env:IMDISK_SILENT_SETUP = 1
& $imdiskPath -y
