output "instance_id" {
  description = "OCI instance OCID."
  value       = oci_core_instance.crisisweave.id
}

output "public_ip" {
  description = "Public IPv4 address of the CrisisWeave host."
  value       = oci_core_instance.crisisweave.public_ip
}

output "bootstrap_url" {
  description = "Initial API URL. If api_hostname was blank this is HTTP bootstrap only; configure DNS/TLS before real sensitive data."
  value       = trimspace(var.api_hostname) == "" ? "http://${oci_core_instance.crisisweave.public_ip}" : "https://${var.api_hostname}"
}

output "health_url" {
  description = "Public health endpoint after the bootstrap has completed."
  value       = trimspace(var.api_hostname) == "" ? "http://${oci_core_instance.crisisweave.public_ip}/healthz" : "https://${var.api_hostname}/healthz"
}

output "next_steps" {
  description = "Post-deploy instructions."
  value = trimspace(var.api_hostname) == "" ? join("\n", [
    "CrisisWeave is bootstrapping on the VM. Wait about 5-10 minutes, then open the health_url output.",
    "This HTTP bootstrap endpoint is for synthetic/testing use only. Point a DNS hostname at public_ip, set CW_API_HOST on the VM, and restart the stack before any real sensitive data.",
    "Use OCI Cloud Shell or an SSH key to run deploy/stack/bootstrap-admin.sh when you are ready to create the first operator."
    ]) : join("\n", [
    "CrisisWeave is bootstrapping on the VM. Wait about 5-10 minutes, then open the health_url output.",
    "Caddy will request HTTPS automatically once the hostname resolves to public_ip.",
    "Use OCI Cloud Shell or an SSH key to run deploy/stack/bootstrap-admin.sh when you are ready to create the first operator."
  ])
}
