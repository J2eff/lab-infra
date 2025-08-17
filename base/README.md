# Base Module: Packer & Terraform Setup

This directory sets up the foundation for local VM provisioning using:

- **Packer**: Builds a golden Ubuntu 22.04 (Jammy) image with `cloud-init`
- **Terraform (libvirt)**: Applies that image to create VMs for labs

---

## Contents

- `jammy.json`: Packer build definition (ISO, boot config, provisioning scripts)
- `http/`: `cloud-init` files (`user-data`, `meta-data`) provided during image build
- `scripts/`: Provisioning scripts (e.g., `clean.sh`, `minimize.sh`)
- `ubuntu.pkr.hcl`: Optional HCL version of the same Packer config

---

## Usage Guide

```bash
cd base
packer init ubuntu.pkr.hcl   # Optional if using HCL
packer build jammy.json      # Builds Ubuntu QCOW2 image

cd ../..
tfenv install <version>      # If using tfenv
terraform -chdir=base/terraform init
terraform -chdir=base/terraform apply