# CrisisWeave on OCI Always Free

This branch is a self-contained Oracle Cloud Infrastructure Resource Manager stack for deploying the CrisisWeave backend without keeping a personal computer online.

It creates:

- one `VM.Standard.A1.Flex` ARM VM, default 2 OCPUs / 12 GB RAM
- a 50 GB boot volume by default
- a VCN, public subnet, route table and internet gateway
- ingress for HTTP/HTTPS and optional SSH only when an SSH public key is provided
- Ubuntu 24.04 ARM
- Docker + Docker Compose
- the reviewed CrisisWeave backend stack from `davidmariscalf/crisisweave-infra`

The Terraform configuration refuses values above 2 OCPUs or 12 GB RAM and checks that the selected region is the tenancy home region. Oracle Always Free limits are tenancy-wide; existing resources can consume the same allowance.

## Deploy from a phone

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/davidmariscalf/crisisweave-infra/archive/refs/heads/oci-free-deploy.zip)

In Oracle Resource Manager supply:

- `tenancy_ocid`
- `compartment_ocid`
- your OCI home-region identifier
- optionally an SSH public key
- optionally a DNS hostname already pointing to the future VM IP

Keep the defaults `2 OCPU`, `12 GB RAM`, and `50 GB boot volume` unless you have independently verified your remaining Always Free allocation.

If `api_hostname` is blank, CrisisWeave starts in HTTP bootstrap mode on port 80. That is suitable only for synthetic/testing data. After deployment, point a DNS hostname at the `public_ip` output and enable HTTPS before any real sensitive data.

The VM bootstrap generates CrisisWeave's token pepper and internal worksites token locally. They are not Terraform variables, outputs, GitHub secrets, or Resource Manager outputs.

## After deployment

Wait 5-10 minutes for cloud-init to install Docker, build the images and start the stack. Resource Manager displays `public_ip` and `health_url` outputs.

For administration without a local computer, use OCI Cloud Shell in the browser. The first CrisisWeave administrator is deliberately not created automatically; run the repository's `deploy/stack/bootstrap-admin.sh` from the VM when you are ready.

## Important

Always Free capacity is not guaranteed. Oracle can return an out-of-host-capacity error; try a different availability-domain index or try again later. A successful deployment is not a production-security certification. Do not load real survivor or volunteer data until DNS/TLS, off-host backups, recovery testing, identity/MFA and operational ownership are configured.
