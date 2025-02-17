# This file was autogenerated by the BETA 'packer hcl2_upgrade' command then manually formatted and updated.

# Avoid mixing go templating calls ( for example ```{{ upper(`string`) }}``` )
# and HCL2 calls (for example '${ var.string_value_example }' ). They won't be
# executed together and the outcome will be unknown.packer {

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# GH Action Runner
variable "runner_tarball" {
  description = "The URL to the tarball of the action runner"
  type        = string
  default     = "https://github.com/actions/runner/releases/download/v2.296.2/actions-runner-win-x64-2.296.2.zip"
}

variable "runner_config" {
  type      = string
  sensitive = true
}

variable "runner_name" {
  type      = string
  sensitive = true
}

# AWS Config
variable "region" {
  description = "The region to build the image in"
  type        = string
}

variable "instance_type" {
  description = "The instance type Packer will use for the builder"
  type        = string
  default     = "c5n.4xlarge"
}

variable "ebs_delete_on_termination" {
  description = "Indicates whether the EBS volume is deleted on instance termination."
  type        = bool
  default     = true
}

variable "associate_public_ip_address" {
  description = "If using a non-default VPC, there is no public IP address assigned to the EC2 instance. If you specified a public subnet, you probably want to set this to true. Otherwise the EC2 instance won't have access to the internet"
  type        = string
  default     = true
}

# GH Actions config
variable "agent_tools_directory" {
  type    = string
  default = "C:\\hostedtoolcache\\windows"
}

variable "helper_script_folder" {
  type    = string
  default = "C:\\Program Files\\WindowsPowerShell\\Modules\\"
}

variable "image_folder" {
  type    = string
  default = "C:\\image"
}

variable "image_os" {
  type    = string
  default = "win19"
}

variable "image_version" {
  type    = string
  default = "dev"
}

variable "imagedata_file" {
  type    = string
  default = "C:\\imagedata.json"
}

variable "install_password" {
  type      = string
  sensitive = true
}

variable "install_user" {
  type    = string
  default = "installer"
}

# "timestamp" template function replacement
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "githubrunner" {
  ami_name                    = "github-runner-windows-core-2019-${formatdate("YYYYMMDDhhmm", timestamp())}"
  communicator                = "winrm"
  instance_type               = var.instance_type
  region                      = var.region
  associate_public_ip_address = var.associate_public_ip_address

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2019-English-Core-ContainersLatest-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  tags = {
    OS_Version    = "windows-core-2019"
    Release       = "Latest"
    Base_AMI_Name = "{{ .SourceAMIName }}"
  }
  user_data_file = "./bootstrap_win.ps1"
  winrm_insecure = true
  winrm_port     = 5986
  winrm_use_ssl  = true
  winrm_username = "Administrator"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 150
    delete_on_termination = "${var.ebs_delete_on_termination}"
  }

  aws_polling {
    delay_seconds = 40
    max_attempts  = 100
  }
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/from-1.5/blocks/build
build {
  sources = [
    "source.amazon-ebs.githubrunner"
  ]

  provisioner "powershell" {
    inline = [
      "New-Item -Path ${var.image_folder} -ItemType Directory -Force"
    ]
  }
  provisioner "file" {
    destination = "C:/start-runner.ps1"
    content = templatefile("./start_runner.ps1", {
      runner_config = var.runner_config,
      runner_name   = var.runner_name
    })
  }
  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/ImageHelpers"
  }
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/SoftwareReport"
  }
  provisioner "file" {
    destination = "C:/"
    source      = "${path.root}/post-generation"
  }
  provisioner "file" {
    source      = "${path.root}/scripts/Tests"
    destination = "${var.image_folder}"
  }
  provisioner "file" {
    destination = "${var.image_folder}\\toolset.json"
    source      = "${path.root}/toolsets/toolset-2019.json"
  }
  provisioner "windows-shell" {
    inline = [
      "net user ${var.install_user} ${var.install_password} /add /passwordchg:no /passwordreq:yes /active:yes /Y",
      "net localgroup Administrators ${var.install_user} /add",
      "winrm set winrm/config/service/auth @{Basic=\"true\"}",
      "winrm get winrm/config/service/auth"
    ]
  }
  provisioner "powershell" {
    inline = [
      "if (-not ((net localgroup Administrators) -contains '${var.install_user}')) { exit 1 }"
    ]
  }
  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    inline = [
      "bcdedit.exe /set TESTSIGNING ON"
    ]
  }
  provisioner "powershell" {
    environment_vars = [
      "IMAGE_VERSION=${var.image_version}",
      "IMAGE_OS=${var.image_os}",
      "AGENT_TOOLSDIRECTORY=${var.agent_tools_directory}",
      "IMAGEDATA_FILE=${var.imagedata_file}"
    ]
    execution_policy = "unrestricted"
    scripts = [
      "${path.root}/scripts/Installers/Configure-Antivirus.ps1",
      "${path.root}/scripts/Installers/Install-PowerShellModules.ps1",
      "${path.root}/scripts/Installers/Install-WindowsFeatures.ps1",
      "${path.root}/scripts/Installers/Install-Choco.ps1",
      "${path.root}/scripts/Installers/Initialize-VM.ps1",
      "${path.root}/scripts/Installers/Update-ImageData.ps1",
      "${path.root}/scripts/Installers/Update-DotnetTLS.ps1"
    ]
  }
  provisioner "windows-restart" {
    restart_timeout = "30m"
  }
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Install-VCRedist.ps1",
      "${path.root}/scripts/Installers/Install-PowershellCore.ps1",
      "${path.root}/scripts/Installers/Install-WebPlatformInstaller.ps1"
    ]
  }
  provisioner "windows-restart" {
    restart_timeout = "10m"
  }
  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    scripts = [
      "${path.root}/scripts/Installers/Install-Imdisk.ps1",
      "${path.root}/scripts/Installers/Install-VS.ps1",
      "${path.root}/scripts/Installers/Install-NET48.ps1"
    ]
    valid_exit_codes = [0,
    3010]
  }
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Install-Wix.ps1",
      "${path.root}/scripts/Installers/Install-Vsix.ps1",
      "${path.root}/scripts/Installers/Install-CommonUtils.ps1",
      "${path.root}/scripts/Installers/Install-JavaTools.ps1"
    ]
  }
  provisioner "windows-restart" {
    restart_timeout = "10m"
  }
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Install-Toolset.ps1",
      "${path.root}/scripts/Installers/Configure-Toolset.ps1",
      "${path.root}/scripts/Installers/Install-NodeLts.ps1",
      "${path.root}/scripts/Installers/Install-Git.ps1",
      "${path.root}/scripts/Installers/Install-AWS.ps1",
      "${path.root}/scripts/Installers/Install-DotnetSDK.ps1",
      "${path.root}/scripts/Installers/Install-Mingw64.ps1",
      "${path.root}/scripts/Installers/Install-Zstd.ps1",
      "${path.root}/scripts/Installers/Install-NSIS.ps1",
      "${path.root}/scripts/Installers/Install-Vcpkg.ps1",
      "${path.root}/scripts/Installers/Install-RootCA.ps1",
      "${path.root}/scripts/Installers/Disable-JITDebugger.ps1",
      "${path.root}/scripts/Installers/Configure-DynamicPort.ps1",
      "${path.root}/scripts/Installers/Configure-GDIProcessHandleQuota.ps1",
      "${path.root}/scripts/Installers/Configure-Shell.ps1",
      "${path.root}/scripts/Installers/Enable-DeveloperMode.ps1",
      "${path.root}/scripts/Installers/Install-LLVM.ps1"
    ]
  }
  provisioner "powershell" {
    inline = [
      templatefile("./scripts/Installers/Install-GH-Action-Runner.ps1", {
        action_runner_url = var.runner_tarball
      })
    ]
  }
  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    scripts = [
      "${path.root}/scripts/Installers/Install-WindowsUpdates.ps1"
    ]
  }
  provisioner "windows-restart" {
    check_registry        = true
    restart_check_command = "powershell -command \"& {if ((-not (Get-Process TiWorker.exe -ErrorAction SilentlyContinue)) -and (-not [System.Environment]::HasShutdownStarted) ) { Write-Output 'Restart complete' }}\""
    restart_timeout       = "30m"
  }
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Wait-WindowsUpdatesForInstall.ps1",
    ]
  }
  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Run-NGen.ps1",
      "${path.root}/scripts/Installers/Finalize-VM.ps1"
    ]
    skip_clean = true
  }
  provisioner "windows-restart" {
    restart_timeout = "10m"
  }
  provisioner "powershell" {
    inline = [
      "if( Test-Path $Env:SystemRoot\\System32\\Sysprep\\unattend.xml ){ rm $Env:SystemRoot\\System32\\Sysprep\\unattend.xml -Force}",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }
}
