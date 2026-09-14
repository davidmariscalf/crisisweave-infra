# Free cloud deployment with OCI Resource Manager

CrisisWeave can be provisioned without keeping a personal computer online. The supported free-cloud prototype path uses Oracle Cloud Infrastructure Resource Manager plus the tenancy's Always Free Ampere A1 allocation.

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/davidmariscalf/crisisweave-infra/archive/refs/heads/oci-free-deploy.zip)

The button loads the self-contained `oci-free-deploy` branch into OCI Resource Manager. Resource Manager runs Terraform in Oracle's cloud, so no local Terraform installation or always-on personal computer is required.

## What it creates

The stack creates one `VM.Standard.A1.Flex` instance using defaults capped at 2 OCPUs and 12 GB RAM, a 50 GB boot volume, VCN, public subnet, internet gateway, route table and security rules for HTTP/HTTPS. SSH port 22 is only opened when an SSH public key is supplied.

The VM uses Ubuntu 24.04 ARM. Cloud-init installs Docker, clones `crisisweave-infra`, invokes the existing secure stack initializer, generates backend secrets locally, and starts `worksites`, `platform`, Caddy, Prometheus and blackbox_exporter with Docker Compose.

No backend token, pepper, password or private key is accepted as a Terraform variable or emitted as a Terraform output.

## From a phone

1. Open the Deploy to Oracle Cloud button and sign in to OCI.
2. Choose the compartment and an availability domain in your home region. Resource Manager supplies tenancy and region values automatically.
3. Keep 2 OCPUs, 12 GB RAM and 50 GB boot volume unless you have verified that another existing Always Free resource is consuming part of the tenancy-wide allowance.
4. Leave `api_hostname` blank if DNS is not ready. This starts a bootstrap HTTP endpoint for synthetic/testing use only.
5. Optionally paste an SSH public key. It is not required by the Terraform template itself.
6. Review the plan and run Apply.
7. After creation, wait roughly 5-10 minutes for cloud-init and use the `health_url` output to check readiness.

If Oracle reports out of host capacity, retry with another availability domain or later. Capacity is controlled by Oracle and cannot be guaranteed by CrisisWeave.

## HTTPS and real data

The no-hostname path deliberately starts as an HTTP bootstrap endpoint. Do not put survivor, volunteer or other sensitive operational data through that endpoint.

For real use, point a DNS hostname at the `public_ip` output, set `CW_API_HOST` on the host, restart the Compose stack and verify HTTPS. Caddy then manages the certificate. The requested `crisisweave.owns.it.com` hostname is currently intended for the public Netlify frontend; use a distinct API hostname when one is available.

## Administration without a PC

OCI Cloud Shell runs in the browser and can be used for administration from another device. CrisisWeave intentionally does not create a universal default administrator. The first operator must be bootstrapped explicitly with `deploy/stack/bootstrap-admin.sh`, and the resulting short-lived token must not be placed in GitHub, Terraform variables, issues, email or chat.

## Source and validation

The package used by the button is the `oci-free-deploy` branch of this repository. That branch is intentionally a small standalone Terraform root module rather than the entire infrastructure repository. Its GitHub Actions workflow runs `terraform fmt`, `terraform init`, `terraform validate` and a shell syntax check for the cloud-init bootstrap.

Always Free limits and eligibility remain Oracle account/tenancy properties, not a CrisisWeave guarantee. Existing OCI resources may consume the same free allowance.
