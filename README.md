# RT-Linux-Docker

TwinCAT 3.1 XAR (user mode) runtime images for Beckhoff RT Linux, built in several
**flavors** from one parameterized Dockerfile and published to the Forgejo container registry.

| Flavor   | Contents                                                       |
|----------|----------------------------------------------------------------|
| `basic`  | `tc31-xar-um`, `adstool`                                       |
| `motion` | basic + `tf5000-nc-ptp-xar` (NC PTP)                           |
| `all`    | union of every other flavor (computed automatically), also tagged `latest` |

Images: `<forgejo-host>/<owner>/tc31-xar:<flavor>`, plus `<flavor>-YYYYMMDD` and `<flavor>-<git sha>`.

## Layout

```
docker/            Dockerfile, entrypoints, apt sources, SysStartupState.reg
flavors/*.conf     one file per flavor (see flavors/TEMPLATE.conf.example)
scripts/           build.sh, list-flavors.sh, verify-no-secrets.sh, discover-packages.sh
.forgejo/workflows/build-images.yml   CI: build → verify → push, one job per flavor
```

## Adding a flavor

Copy `flavors/TEMPLATE.conf.example` to `flavors/<name>.conf` and follow the steps in its header.
In short: set `DESCRIPTION`, `PACKAGES` (find names with `make discover-packages`) and `PLATFORMS`.
CI builds every `flavors/*.conf` as its own job, and `all` picks up the new packages automatically.

## Local builds

```sh
cp .env.example .env              # fill in BHF_USER / BHF_PASSWORD (myBeckhoff login)
make list-flavors
make build-image FLAVOR=basic     # host platform, loaded into local docker as tc31-xar:basic
make verify-image FLAVOR=basic    # fail if any credential ended up in the image
make build-all verify-all
# push manually (multi-arch needs QEMU/binfmt locally):
docker login git.example.com
make push-image FLAVOR=all REGISTRY=git.example.com IMAGE_OWNER=myorg
```

## Credentials

Put your real credentials in **`.env`** at the repo root (git-ignored, template: `.env.example`):

```sh
BHF_USER=you@example.com
BHF_PASSWORD=your-password
```

`make` / `scripts/*.sh` and `docker compose` read it automatically. Lookup order for builds:
`BHF_USER`/`BHF_PASSWORD` from the environment → `.env` → the netrc file `APT_AUTH_CONF`
(default `docker/apt-config/bhf.conf`, which only holds generic placeholder values).
Real credentials are **never** stored in an image or in git:

- `.env` is git-ignored. `bhf.conf` and `*.netrc` are excluded from the build context (`docker/.dockerignore`).
- From `BHF_USER`/`BHF_PASSWORD` the scripts write a temporary netrc file (mode 600) and delete it on exit.
- The build only reads them through a BuildKit secret mount (`--secret id=apt`), and a final
  scrub step removes any `auth.conf`/netrc files.
- `scripts/verify-no-secrets.sh` scans every layer, the image config and the build history
  for the login/password values. CI runs it before pushing.

### Runtime apt credentials

To install extra packages inside a running container, pass the credentials when you start it.
`docker-compose.yml` already passes `BHF_USER`/`BHF_PASSWORD` from `.env`.
The entrypoint writes them to `/etc/apt/auth.conf.d/bhf.conf` (mode 600) in the container
only, and removes `BHF_PASSWORD` from the environment before starting the TwinCAT service:

```yaml
# docker-compose.yml
services:
  tc31-xar:
    image: <forgejo-host>/<owner>/tc31-xar:basic
    environment:
      BHF_USER: ${BHF_USER}          # or list form:  - BHF_USER=${BHF_USER}
      BHF_PASSWORD: ${BHF_PASSWORD}
```

```sh
# preferred: secret file (does not show up in `docker inspect`)
docker run -v $PWD/my-bhf.netrc:/run/secrets/bhf:ro -e BHF_AUTH_FILE=/run/secrets/bhf tc31-xar:basic
# or environment variables
docker run -e BHF_USER=... -e BHF_PASSWORD=... tc31-xar:basic
docker run --rm -e BHF_USER=... -e BHF_PASSWORD=... tc31-xar:basic sh -c 'apt-get update && apt-get install -y tf...'
```

`BHF_HOSTS` overrides the host list (default `deb.beckhoff.com deb-mirror.beckhoff.com`).
Values passed with `-e` are visible to anyone who can run `docker inspect` on the container. Use the
secret-file option on shared hosts.

## Forgejo CI setup

Workflow: `.forgejo/workflows/build-images.yml`. It runs on pushes to `master`, PRs (build and
verify only, no push), weekly, and manually (optional comma-separated `flavors` input).

Runner: a Forgejo runner with `container.docker_host: "automount"` in its `config.yml` (so jobs can
use the host Docker daemon) and the label `catthehacker-latest-armbox`
(`docker://ghcr.io/catthehacker/ubuntu:act-latest`); change `runs-on` in the workflow for another
runner. The host can be amd64 or arm64; the other
architecture is built through QEMU.

| Kind     | Name             | Purpose                                                    |
|----------|------------------|------------------------------------------------------------|
| secret   | `BHF_USER`       | myBeckhoff login for deb.beckhoff.com                      |
| secret   | `BHF_PASSWORD`   | myBeckhoff password                                        |
| secret   | `REGISTRY_TOKEN` | Forgejo access token with `write:package` scope            |
| variable | `REGISTRY`       | optional, registry host (default: Forgejo server host)     |
| variable | `IMAGE_OWNER`    | optional, package owner (default: repository owner)        |
| variable | `REGISTRY_USER`  | optional, login user for the token (default: workflow actor) |

## Running

```sh
make run-containers    # docker compose, uses TC_IMAGE / AMS_NETID / BHF_* from .env
```

`docker-compose.yml` runs the container with `privileged: true` (Beckhoff's default). This allows
realtime scheduling, reading EFI variables (Beckhoff IPC hardware info) and using host devices/NICs.
On dev/test hosts, `cap_add: [SYS_NICE]` is enough for realtime scheduling (see the comment in the
compose file). A realtime (PREEMPT_RT) host kernel such as Beckhoff RT Linux is needed for real RT.
Otherwise the runtime logs `Realtime kernel is not active` but still runs.
