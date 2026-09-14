variable "tenancy_ocid" {
  description = "OCI tenancy OCID. Resource Manager fills this automatically."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment OCID where CrisisWeave resources will be created."
  type        = string
}

variable "region" {
  description = "OCI region. Resource Manager fills this automatically; Always Free compute must be created in the tenancy home region."
  type        = string
}

variable "availability_domain_name" {
  description = "Availability domain for the Ampere A1 VM. Choose another if Oracle reports out of host capacity."
  type        = string
}

variable "ssh_public_key" {
  description = "Optional SSH public key for emergency administration. Leave empty if you will use OCI Console/Cloud Shell only."
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_source_cidr" {
  description = "IPv4 CIDR allowed to reach SSH when an SSH public key is supplied. Ignored when SSH is disabled. Narrow this to your trusted public IP whenever possible."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.ssh_source_cidr))
    error_message = "ssh_source_cidr must be a valid IPv4 CIDR such as 203.0.113.10/32."
  }
}

variable "api_hostname" {
  description = "Optional DNS hostname already pointing to the VM public IP. Leave blank for HTTP bootstrap on port 80; add DNS later before real sensitive data."
  type        = string
  default     = ""

  validation {
    condition = trimspace(var.api_hostname) == "" || (
      !can(regex("[/:\\s]", trimspace(var.api_hostname))) &&
      can(regex("^[A-Za-z0-9.-]+$", trimspace(var.api_hostname)))
    )
    error_message = "api_hostname must be blank or a plain DNS hostname without scheme, path, port, or whitespace."
  }
}

variable "ocpus" {
  description = "Ampere A1 OCPUs. Default matches the 2026 Always Free allowance."
  type        = number
  default     = 2
  validation {
    condition     = var.ocpus > 0 && var.ocpus <= 2
    error_message = "To remain inside the documented 2026 Always Free allowance, ocpus must be <= 2."
  }
}

variable "memory_gbs" {
  description = "Ampere A1 memory in GB. Default matches the 2026 Always Free allowance."
  type        = number
  default     = 12
  validation {
    condition     = var.memory_gbs >= 1 && var.memory_gbs <= 12
    error_message = "To remain inside the documented 2026 Always Free allowance, memory_gbs must be <= 12."
  }
}

variable "boot_volume_gbs" {
  description = "Boot volume size in GB. The default leaves headroom inside the tenancy-wide Always Free block-storage allowance."
  type        = number
  default     = 50
  validation {
    condition     = var.boot_volume_gbs >= 47 && var.boot_volume_gbs <= 100
    error_message = "boot_volume_gbs must be between 47 and 100 GB."
  }
}
