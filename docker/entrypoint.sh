#!/bin/sh
# Optionally set up Beckhoff apt credentials (BHF_USER/BHF_PASSWORD) in the
# container, then run the given command or, by default, the TwinCAT system service.
set -e

if [ -n "${BHF_USER:-}" ] && [ -n "${BHF_PASSWORD:-}" ]; then
    mkdir -p /etc/apt/auth.conf.d
    ( umask 077
      for host in deb.beckhoff.com deb-mirror.beckhoff.com; do
          echo "machine $host login $BHF_USER password $BHF_PASSWORD"
      done > /etc/apt/auth.conf.d/bhf.conf )
fi
unset BHF_PASSWORD   # keep it out of the service's environment

# Login account for "Add Route" from TwinCAT Engineering. TcSystemServiceUm checks the
# password via /usr/bin/tcauth (PAM) and only accepts users in the "sudo" or "wheel" group;
# without that the route request is silently dropped. Beckhoff RT Linux default: Administrator/1.
TC_ADMIN_USER=${TC_ADMIN_USER:-Administrator}
if [ -n "${TC_ADMIN_PASSWORD:-}" ]; then
    id -u "$TC_ADMIN_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/sh "$TC_ADMIN_USER"
    usermod -aG sudo "$TC_ADMIN_USER"
    echo "$TC_ADMIN_USER:$TC_ADMIN_PASSWORD" | chpasswd
fi
unset TC_ADMIN_PASSWORD

[ $# -gt 0 ] && exec "$@"
exec /usr/bin/TcSystemServiceUm -f 0x7 -i "${AMS_NETID}" -p /var/run/TcSystemServiceUm.pid
