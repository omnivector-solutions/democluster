packer {
  required_version = ">= 1.7.0"
  required_plugins {
    qemu = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

locals {
  qemu_arch = {
    "amd64" = "x86_64"
    "arm64" = "aarch64"
  }
  uefi_imp = {
    "amd64" = "OVMF"
    "arm64" = "AAVMF"
  }
  qemu_machine = {
    "amd64" = "ubuntu,accel=kvm"
    "arm64" = "virt"
  }
  qemu_cpu = {
    "amd64" = "host"
    "arm64" = "cortex-a57"
  }
}

variable "ubuntu_series" {
  type        = string
  default     = "noble"
  description = "The codename of the Ubuntu series to build."
}

variable "architecture" {
  type        = string
  default     = "amd64"
  description = "The architecture to build the image for (amd64 or arm64)"
}

variable "http_directory" {
  type    = string
  default = "http"
}

source "null" "dependencies" {
  communicator = "none"
}

source "null" "final" {
  communicator = "none"
}

source "qemu" "stage0" {
  boot_wait      = "2s"
  cpus           = 4
  disk_image     = true
  disk_size      = "5G"
  format         = "qcow2"
  headless       = true
  http_directory = var.http_directory
  iso_checksum   = "file:https://cloud-images.ubuntu.com/${var.ubuntu_series}/current/SHA256SUMS"
  iso_url        = "https://cloud-images.ubuntu.com/${var.ubuntu_series}/current/${var.ubuntu_series}-server-cloudimg-${var.architecture}.img"
  memory         = 4096
  qemu_binary    = "qemu-system-${lookup(local.qemu_arch, var.architecture, "")}"
  qemuargs = [
    ["-machine", "${lookup(local.qemu_machine, var.architecture, "")}"],
    ["-cpu", "${lookup(local.qemu_cpu, var.architecture, "")}"],
    ["-serial", "stdio"],
    ["-device", "virtio-gpu-pci"],
    ["-drive", "if=pflash,format=raw,id=ovmf_code,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd"],
    ["-drive", "if=pflash,format=raw,id=ovmf_vars,file=/usr/share/OVMF/OVMF_VARS_4M.fd"],
    ["-drive", "file=seeds-cloudimg.iso,format=raw"],
    ["-drive", "file=output-stage0/packer-stage0,format=qcow2"]
  ]
  shutdown_command = "sudo -S shutdown -P now"
  ssh_password     = "ubuntu"
  ssh_username     = "ubuntu"
  ssh_timeout      = "20m"
}

build {
  name    = "stage0.deps"
  sources = ["source.null.dependencies"]

  provisioner "shell-local" {
    inline = [
      "cp /usr/share/OVMF/OVMF_VARS_4M.fd OVMF_VARS_4M.fd",
      "cloud-localds seeds-cloudimg.iso user-data meta-data"
    ]
    inline_shebang = "/bin/bash -e"
  }
}

build {
  name    = "stage0.image"
  sources = ["source.qemu.stage0"]

  provisioner "shell" {
    valid_exit_codes = [
      "0",
      "1",
      "2"
    ]
    inline = [
      "bash -c 'sleep 60'",
      "bash -c 'python3 -W ignore /usr/bin/cloud-init status --wait'",
      "bash -c 'sudo cloud-init clean --logs'",
    ]
  }
}

build {
  name    = "final"
  sources = ["source.null.final"]

  post-processor "shell-local" {
    inline = [
        "mkdir -p final",
        "cp output-stage0/packer-stage0 final/democluster.img",
        "rm -rf output-stage0/",
        "chmod -R 777 final",
    ]
  }
}
