#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

set -o errexit
#set -o pipefail
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

PORT=""
PASS=""

userinput () {
  echo "Enter Port for shadowsocks:"
  read PORT
  echo "Enter Password for shadowsocks:"
  read PASS
  
  if [[ -z "$PORT" || -z "$PASS" ]]; then
    echo "port / pass must not be empty."
    exit 1
  fi
}

os_check() {
  if [[ $(uname -m) != "x86_64" ]]; then
    echo "x86_64 only!"
    exit 1
  fi
  
  if ! command -v rpm || ! command -v systemctl; then
    echo "Centos / Fedora supported only. !"
    exit 1
  fi
  
  if ! cat /dev/net/tun 2>&1 | grep -q 'File descriptor in bad state'; then
    echo "TAP driver not enabled, enable it your vps panel."
    exit 1
  fi
}

setup_ss () {
  if command -v dnf; then
    dnf install -y $__dir/progs/shadowsocks-libev*.rpm
  else
    yum localinstall -y $__dir/progs/shadowsocks-libev*.rpm
  fi

  install -m755 $__dir/progs/obfs-server /usr/local/bin/
  setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/obfs-server

  # shadowsocks
  install -m644 $__dir/confs/{ss,obfshttp,obfstls}.json /etc/shadowsocks-libev
  sed -i "s/##PORT##/$PORT/; s/##PASS##/$PASS/;" /etc/shadowsocks-libev/*.json 
  systemctl enable shadowsocks-libev-server@ss
  systemctl start shadowsocks-libev-server@ss
  systemctl status shadowsocks-libev-server@ss.service
}

setup_kcp () {
  local kcppkg=$(ls $__dir/progs/kcptun-*|head -n1)
  tar xvfa $kcppkg -C /tmp/ server_linux_amd64
  install -m755 /tmp/server_linux_amd64 /usr/local/bin/kcps
  rm -fv /tmp/server_linux_amd64

  install -m644 $__dir/confs/kcps.json /etc/
  install -m644 $__dir/confs/kcps.service /etc/systemd/system/
  sed -i "s/##PORT##/$PORT/; s/##PASS##/$PASS/;" /etc/kcps.json

  systemctl daemon-reload
  systemctl enable kcps.service
  systemctl start kcps.service
  systemctl status kcps.service

  if command -v python2; then
    echo "KCP Client Options:"
    python2 $__dir/progs/kcpargs.py /etc/kcps.json
  fi
}

setup_lkl () {
  yum clean all
  yum makecache
  yum install -y epel-release
  yum install -y haproxy iptables-services
  install -m644 $__dir/progs/liblkl-hijack.so /usr/local/lib64/
  
  install -m644 $__dir/confs/ifcfg-tap0 /etc/sysconfig/network-scripts/
  ifup tap0 || true
  
  install -m644 $__dir/confs/haproxy.cfg /etc/haproxy/
  install -m644 $__dir/confs/haproxy.service /etc/systemd/system/
  sed -i "s/##PORT##/$PORT/" /etc/haproxy/haproxy.cfg

  systemctl daemon-reload
  systemctl enable haproxy.service
  systemctl start haproxy.service
  systemctl status haproxy.service
  echo "..... wait lkl linux to wakeup"
  sleep 5
  ping -c4 10.0.0.2

  # iptables
  if [[ -f /etc/sysconfig/iptables ]]; then
    mv /etc/sysconfig/{iptables,iptables.orig}
  fi

  install -m644 $__dir/confs/iptables /etc/sysconfig/
  sed -i "s/##PORT##/$PORT/" /etc/sysconfig/iptables
  systemctl stop firewalld || true
  systemctl disable firewalld || true
  systemctl enable iptables
  systemctl restart iptables
  systemctl status iptables
  
  # sysctl
  if ! sysctl net.ipv4.ip_forward | grep '= 1'; then
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/98-ipfwd.conf
    sysctl --system
  fi
}


uninstall_lkl () {
  systemctl stop haproxy.service
  ifdown tap0
  ip link delete tap0||true

  rm -fv /etc/sysconfig/network-scripts/tap0 
  rm -fv /usr/local/lib64/liblkl-hijack.so
  rm -fv /etc/sysconfig/iptables 
  if [[ -e /etc/sysconfig/iptables.orig ]]; then
    mv /etc/sysconfig/{iptables.orig,iptables}
  fi 
  rm -fv /etc/sysctl.d/98-ipfwd.conf
}



menu () {
  select ACTION in SS SS_LKL SS_KCP SS_LKL_KCP REMOVE_LKL; do
    case $ACTION in
      "SS")
        userinput
        setup_ss
        break
        ;;
      "SS_LKL")
        userinput
        setup_ss
        setup_lkl
        break
        ;;
      "SS_KCP")
        userinput
        setup_ss
        setup_kcp
        break
        ;;
      "SS_LKL_KCP")
        userinput
        setup_ss
        setup_lkl
        setup_kcp
        break
        ;;
      "REMOVE_LKL")
        uninstall_lkl
        break;;
    esac
  done
}

main () {
  os_check
  menu
}

main
