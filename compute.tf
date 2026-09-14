data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  api_site = trimspace(var.api_hostname) == "" ? ":80" : var.api_hostname
}

resource "oci_core_instance" "crisisweave" {
  availability_domain = var.availability_domain_name
  compartment_id      = var.compartment_ocid
  display_name        = "crisisweave"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.crisisweave.id
    assign_public_ip = true
    display_name     = "crisisweave-primary-vnic"
    hostname_label   = "crisisweave"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gbs
  }

  metadata = merge(
    {
      user_data = base64encode(templatefile("${path.module}/cloud-init.sh.tftpl", {
        api_site       = local.api_site
        allowed_origin = "https://crisisweave.netlify.app"
        infra_git_ref  = "main"
      }))
    },
    trimspace(var.ssh_public_key) == "" ? {} : {
      ssh_authorized_keys = trimspace(var.ssh_public_key)
    }
  )

  freeform_tags = {
    ManagedBy = "CrisisWeave"
    Tier      = "AlwaysFree"
  }

  lifecycle {
    precondition {
      condition     = length(data.oci_core_images.ubuntu.images) > 0
      error_message = "No Ubuntu 24.04 ARM image compatible with VM.Standard.A1.Flex was found in the selected region."
    }
  }
}
