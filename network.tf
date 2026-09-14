resource "oci_core_vcn" "crisisweave" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.42.0.0/16"
  display_name   = "crisisweave-vcn"
  dns_label      = "crisisweave"

  freeform_tags = {
    ManagedBy = "CrisisWeave"
    Tier      = "AlwaysFree"
  }
}

resource "oci_core_internet_gateway" "crisisweave" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.crisisweave.id
  display_name   = "crisisweave-internet-gateway"
  enabled        = true
}

resource "oci_core_route_table" "crisisweave" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.crisisweave.id
  display_name   = "crisisweave-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.crisisweave.id
  }
}

resource "oci_core_security_list" "crisisweave" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.crisisweave.id
  display_name   = "crisisweave-security-list"

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
    description = "HTTP for Caddy bootstrap and ACME redirects"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
    description = "HTTPS for CrisisWeave API"
  }

  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"
    udp_options {
      min = 443
      max = 443
    }
    description = "HTTP/3 for Caddy"
  }

  dynamic "ingress_security_rules" {
    for_each = trimspace(var.ssh_public_key) == "" ? [] : [1]
    content {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        min = 22
        max = 22
      }
      description = "SSH enabled because an SSH public key was supplied"
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Outbound package, GitHub, DNS, ACME and monitoring access"
  }
}

resource "oci_core_subnet" "crisisweave" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.crisisweave.id
  cidr_block                 = "10.42.10.0/24"
  display_name               = "crisisweave-public-subnet"
  dns_label                  = "api"
  route_table_id             = oci_core_route_table.crisisweave.id
  security_list_ids          = [oci_core_security_list.crisisweave.id]
  prohibit_public_ip_on_vnic = false
}
