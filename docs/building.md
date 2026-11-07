# Building

## Credentials

Copy `.env.example` to `.env` and set `BHF_USER` / `BHF_PASSWORD` (myBeckhoff login). Builds use
them as a BuildKit secret only; `scripts/verify-no-secrets.sh` checks every image for them.

If set when the container starts, the entrypoint writes them to `/etc/apt/auth.conf.d/bhf.conf` so
`apt-get` works inside the container (visible in `docker inspect`).

## Local use

```sh
make list                 # flavors and their packages
make build FLAVOR=motion  # build for this machine
make verify FLAVOR=motion # secret scan
make build-all verify-all
docker compose up -d      # run TC_IMAGE from .env
```

The compose file runs `privileged: true` (realtime, EFI variables, host NICs). Real-time
behaviour needs a PREEMPT_RT host kernel such as Beckhoff RT Linux.

To add a flavor, see [`flavors/README.md`](../flavors/README.md).

## CI

`.forgejo/workflows/build-images.yml` builds, scans and smoke-tests every flavor.

| Trigger | Pushes |
|---------|--------|
| Weekly (Mon 12:00 UTC), manual | `<flavor>`, `<flavor>-YYYYMMDD`, `latest` |
| Push to `master` | `<flavor>-dev`, `<flavor>-<sha>` |
| Pull request | nothing |

- Runner label `catthehacker-latest-armbox` (`ghcr.io/catthehacker/ubuntu:act-latest`), with
  `container.docker_host: "automount"` in the runner config.
- Secrets: `BHF_USER`, `BHF_PASSWORD`, `REGISTRY_TOKEN` (package write access).
- Variable (optional): `REGISTRY_USER`, the token owner (default: the user who triggered the run).
