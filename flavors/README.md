# Flavors

Each `<name>.conf` here is one image, `tc31-xar:<name>`. To add one:

1. Find package names: `make discover-packages` (or `scripts/discover-packages.sh <regex>`).
2. Create `flavors/<name>.conf`:
   ```sh
   # what this flavor is for
   PACKAGES="tc31-xar-um adstool tf6250-modbus-tcp"
   # optional, default linux/amd64,linux/arm64. Check arm64 builds exist with:
   #   PLATFORM=linux/arm64 make discover-packages
   # PLATFORMS="linux/amd64"
   ```
3. Test it: `make build FLAVOR=<name> && make verify FLAVOR=<name>`.

CI builds every `*.conf` as its own job, and `all` picks up the new packages automatically.
