# Monitoring

The repository can use GitHub Actions for public availability checks without storing a monitoring API key.

After `crisisweave.thedev.me` is approved and TLS is live, monitor both the Netlify origin and the custom-domain URL.

Backend monitoring should use `/healthz` for liveness and `/readyz` for dependency readiness. Do not place bearer tokens in workflow files. If authenticated probes are ever required, store credentials only in the hosting or monitoring provider's secret store.
