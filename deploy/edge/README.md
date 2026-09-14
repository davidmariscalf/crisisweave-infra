# Backend TLS edge profile

Caddy is the recommended lightweight TLS/reverse-proxy option for a small Docker-based CrisisWeave deployment. Its pinned version is recorded in `../../ecosystem/components.lock.json`. It is not currently deployed by this repository.

## Boundary

Only the edge proxy should listen on the public backend ports. Keep these services on a private application network:

- `crisisweave-platform`
- `crisisweave-worksites`
- oauth2-proxy, when enabled
- Prometheus / blackbox exporter
- OpenBao

Never expose the worksite write service directly to the internet.

## Example

`Caddyfile.example` assumes `api.example.org` will be replaced at deployment time with the real API hostname. Caddy terminates TLS and proxies to the platform. If oauth2-proxy protects a browser route, route that surface through oauth2-proxy instead of trusting arbitrary identity headers at the platform.

## Required controls

- DNS must point the chosen API hostname to the deployment.
- TCP 80/443 are the only intended public service ports for this profile.
- Platform and worksite ports stay internal.
- Preserve Caddy access logs without logging Authorization headers or request bodies.
- Set upstream request/body/time limits at both Caddy and CrisisWeave.
- Monitor TLS expiry and `/healthz`/`/readyz` from outside the host.

Automatic HTTPS is useful operationally, but it does not make an unreviewed backend production-ready. Authentication, authorisation, encrypted storage, backup and monitoring remain separate layers.
