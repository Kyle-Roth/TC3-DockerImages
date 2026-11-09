# TC3-DockerImages

TwinCAT 3.1 XAR runtime (user mode) on Debian, for amd64 and arm64.

## Images

| Image | Contents |
|-------|----------|
| `git.kyleroth.dev/beckhoff/tc31-xar:basic`  | TwinCAT runtime, `adstool` |
| `git.kyleroth.dev/beckhoff/tc31-xar:motion` | basic + TF5000 NC PTP |
| `git.kyleroth.dev/beckhoff/tc31-xar:full`   | every TwinCAT package (`tc* tf* te*`), also `:latest` |

Tags per image:

- `<profile>`, `<profile>-YYYYMMDD`: weekly release
- `<profile>-dev`, `<profile>-<sha>`: latest `master` commit

Building, credentials and CI: [`docs/building.md`](docs/building.md).
