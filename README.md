# TC3-DockerImages

TwinCAT 3.1 XAR runtime (user mode) on Debian, for amd64 and arm64.

## Images

| Image | Contents |
|-------|----------|
| `ghcr.io/Kyle-Roth/tc31-xar:basic`                | TwinCAT runtime, `adstool` |
| `ghcr.io/Kyle-Roth/tc31-xar:EtherCAT_sim`         | basic + TE1111 EtherCAT simulation |
| `ghcr.io/Kyle-Roth/tc31-xar:communication`        | basic + all communication (`tf6*`) |
| `ghcr.io/Kyle-Roth/tc31-xar:motion`               | basic + TF5000 NC PTP |
| `ghcr.io/Kyle-Roth/tc31-xar:hmi`                  | basic + TF2000 HMI server |
| `ghcr.io/Kyle-Roth/tc31-xar:full`, also `:latest` | every TwinCAT package (`tc* tf* te*`)|

Tags per image:

- `<profile>`, `<profile>-YYYYMMDD`: weekly release
- `<profile>-dev`, `<profile>-<sha>`: latest `master` commit

Building, credentials and CI: [`docs/building.md`](docs/building.md).
