# TC3-DockerImages

Docker containers pre-installed with TwinCAT 3.1 XAR, for amd64 and arm64. Feel free to recommend profiles with different package configurations

## Considerations for installation

This was built following [TC_XAR_Container_Sample](github.com/Beckhoff/TC_XAR_Container_Sample/tree/main). As stated there, these docker containers are designed for an Industrial PC running Beckhoff Real-Time Linux. They will only work if your environment meets the following prerequisites:

**Beckhoff IPC as Beckhoff RT Linux host:**
- [Setup and Install](https://infosys.beckhoff.com/english.php?content=../content/1033/beckhoff_rt_linux/17350447499.html) the Beckhoff Real-Time Linux® Distribution on a supported IPC.
- [Configure access to Beckhoff package server](https://infosys.beckhoff.com/english.php?content=../content/1033/beckhoff_rt_linux/17350408843.html)
- Install the required host packages from the default Debian package sources:

```bash
sudo apt update
sudo apt install --yes docker.io docker-compose make tcsysconf
```

## Images

| Image | Contents |
|-------|----------|
| `ghcr.io/kyle-roth/tc31-xar:basic`                | TwinCAT runtime, `adstool` |
| `ghcr.io/kyle-roth/tc31-xar:EtherCAT_sim`         | basic + TE1111 EtherCAT simulation |
| `ghcr.io/kyle-roth/tc31-xar:communication`        | basic + all communication (`tf6*`) |
| `ghcr.io/kyle-roth/tc31-xar:motion`               | basic + TF5000 NC PTP |
| `ghcr.io/kyle-roth/tc31-xar:hmi`                  | basic + TF2000 HMI server |
| `ghcr.io/kyle-roth/tc31-xar:full`, also `:latest` | every TwinCAT package (`tc* tf* te*`)|

Tags per image:

- `<profile>`, `<profile>-YYYYMMDD`: weekly release
- `<profile>-dev`, `<profile>-<sha>`: latest `master` commit

Building, credentials and CI: [`docs/building.md`](docs/building.md).
