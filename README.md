# TC3-DockerImages

TwinCAT 3.1 XAR (user mode) runtime images on Debian, one image per **flavor**, built for
amd64 and arm64 and pushed to the Forgejo registry as `git.kyleroth.dev/beckhoff/tc31-xar:<flavor>`.

| Tag | Updated by |
|-----|------------|
| `<flavor>`, `<flavor>-YYYYMMDD`, `latest` (= `full`) | weekly schedule and manual runs |
| `<flavor>-dev`, `<flavor>-<sha>` | every push to `master` |

| Flavor   | Packages |
|----------|----------|
| `basic`  | `tc31-xar-um`, `adstool` |
| `motion` | basic + `tf5000-nc-ptp-xar` (NC PTP) |
| `full`   | every flavor's packages, also tagged `latest` |

To add a flavor, see [`flavors/README.md`](flavors/README.md).

## Credentials

Copy `.env.example` to `.env` (git-ignored) and set `BHF_USER` / `BHF_PASSWORD` to your myBeckhoff
login. The scripts read it for builds and `docker compose` passes it into the container.

Credentials never end up in an image: the build only sees them as a BuildKit secret, and
`scripts/verify-no-secrets.sh` scans every layer, the image config and the history for them.
CI runs that check before pushing.

If `BHF_USER` / `BHF_PASSWORD` are set when the container starts, the entrypoint writes them to
`/etc/apt/auth.conf.d/bhf.conf` so `apt-get` works inside the container. Values passed this way
are visible in `docker inspect`.

## Local use

```sh
make list                 # flavors and their packages
make build FLAVOR=motion  # build for this machine's platform
make verify FLAVOR=motion # secret scan
make build-all verify-all
docker compose up -d      # run TC_IMAGE from .env
```

The compose file uses `privileged: true` (Beckhoff's default) for realtime scheduling, EFI
variables and host NICs. Real-time behaviour needs a PREEMPT_RT host kernel such as Beckhoff RT Linux.

## CI

`.forgejo/workflows/build-images.yml` builds, scans and smoke-tests every flavor, then pushes
amd64 + arm64 images. Weekly (Mondays 12:00 UTC) and manual runs push the release tags; pushes to
`master` push only the `-dev` / `-<sha>` tags, so merged changes reach `<flavor>` and `latest` at the
next weekly or manual run. Pull requests only build and verify.

- Runner label `catthehacker-latest-armbox` (`ghcr.io/catthehacker/ubuntu:act-latest`), with
  `container.docker_host: "automount"` in the runner config.
- Secrets: `BHF_USER`, `BHF_PASSWORD`, `REGISTRY_TOKEN` (Forgejo token with package write access).
- Variable (optional): `REGISTRY_USER`, the token owner's username (default: the user who triggered the run).
