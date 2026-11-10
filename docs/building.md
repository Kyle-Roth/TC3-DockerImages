# Building

## Credentials

Copy `.env.example` to `.env` and set `BHF_USER` / `BHF_PASSWORD` (myBeckhoff login). Builds use
them as a BuildKit secret only; `scripts/verify-no-secrets.sh` checks every image for them.

If set when the container starts, the entrypoint writes them to `/etc/apt/auth.conf.d/bhf.conf` so
`apt-get` works inside the container (visible in `docker inspect`).

## Local use

```sh
make list                 # profiles and their packages
make build PROFILE=motion  # build for this machine
make verify PROFILE=motion # secret scan
make build-all verify-all
docker compose up -d      # run TC_IMAGE from .env
```

The compose file runs `privileged: true` (realtime, EFI variables, host NICs). Real-time
behaviour needs a PREEMPT_RT host kernel such as Beckhoff RT Linux.

To add a profile, see [`profiles/README.md`](../profiles/README.md).

## CI

`.forgejo/workflows/build-images.yml` builds, scans and smoke-tests every profile, then pushes
to `ghcr.io/<GHCR_OWNER>/tc31-xar`. The GitHub repository is a push mirror of this one; images
are pushed from Forgejo CI, not GitHub Actions.

| Trigger | Pushes |
|---------|--------|
| Weekly (Mon 12:00 UTC), manual | `<profile>`, `<profile>-YYYYMMDD`, `latest` |
| Push to `master` | `<profile>-dev`, `<profile>-<sha>` |
| Pull request | nothing |

- Runner label `catthehacker-latest-armbox` (`ghcr.io/catthehacker/ubuntu:act-latest`), with
  `container.docker_host: "automount"` in the runner config.
- Secrets: `BHF_USER`, `BHF_PASSWORD`, `GHCR_TOKEN` (GitHub classic PAT with `write:packages`).
- Variables: `GHCR_OWNER` (GitHub user or org that owns the packages); optional `GHCR_USER`
  (token owner, default `GHCR_OWNER`) and `IMAGE_SOURCE` (GitHub repo URL; labels the image so
  the package links to the repo).
- New GHCR packages are private: set each one to public once in its package settings.
