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

[ $# -gt 0 ] && exec "$@"
exec /usr/bin/TcSystemServiceUm -f 0x7 -i "${AMS_NETID}" -p /var/run/TcSystemServiceUm.pid
