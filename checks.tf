data "oci_identity_region_subscriptions" "regions" {
  tenancy_id = var.tenancy_ocid
}

locals {
  home_regions = [for r in data.oci_identity_region_subscriptions.regions.region_subscriptions : r.region_name if r.is_home_region]
}

check "home_region" {
  assert {
    condition     = contains(local.home_regions, var.region)
    error_message = "The selected region is not the tenancy home region. Always Free compute must be created in the home region."
  }
}
