#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

arg1="${1:-}"

# allow command fail:
# fail_command || true

if [[ $(uname -m) != "x86_64" ]]; then
  echo "x86_64 only!"
  exit 1
fi

if ! command -v rpm || ! command -v systemctl; then
  echo "Centos 7 only!"
  exit 1
fi

yum clean all
yum makecache
yum install -y epel-release
yum install -y haproxy iptables-services pcre openssl mbedtls libsodium libev c-ares libcap
rpm -Uvh $__dir/progs/shadowsocks-libev*.rpm

install -m755 $__dir/progs/obfs-server /usr/local/bin/
setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/obfs-server
install -m644 $__dir/progs/liblkl-hijack.so /usr/local/lib64/

install -m644 $__dir/confs/ifcfg-tap0 /etc/sysconfig/network-scripts/
ifup tap0 || true

install -m644 $__dir/confs/haproxy.cfg /etc/haproxy/
install -m644 $__dir/confs/haproxy.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable haproxy.service
systemctl start haproxy.service

echo "..... wait lkl linux to wakeup"
sleep 5
ping -c4 10.0.0.2

# shadowsocks
install -m644 $__dir/confs/*.json /etc/shadowsocks-libev
systemctl enable shadowsocks-libev-server@obfshttp
systemctl enable shadowsocks-libev-server@obfstls
systemctl start shadowsocks-libev-server@obfshttp
systemctl start shadowsocks-libev-server@obfstls

# iptables
install -m644 $__dir/confs/iptables /etc/sysconfig/
systemctl disable firewalld || true
systemctl enable iptables
systemctl start iptables

# sysctl
if ! sysctl net.ipv4.ip_forward | grep '= 1'; then
  echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/98-ipfwd.conf
  sysctl --system
fi

