# LKL BBR for Centos 7 #

### How it works ###

```
   +---------------------------------------------------------------------------+
   |                                                                           |
   |                                                                           |
   |               +--------------+                       +----------------+   |
   |               |              |                       |                |   |
   |   +-----------> iptables *nat+------+            +--->Application(ss) +---+
   |   |           |              |      |            |   |                |
+--v---+---+       +--------------+      |            |   +----------------+
|          |                             |            |
|          |       +---------------------v------------+--------------------+
| Internet |       |                      tap0 device                      |
|          |       +---------------------+------------^--------------------+
|          |                             |            |
+----------+                             |            |
                                  +------v------------+--------+
                                  |                            |
                                  |  haproxy under lkl kernel, |
                                  |  with bbr-tcp stack        |
                                  |                            |
                                  +----------------------------+
```

By combinating several components (graph above), this solution makes it possible to have tcp-bbr stack running on non-hardwared virtualizations (specificly, openvz). But this also works on kvm/vmware/everything else, and without installing third party kernels and boot configures.

### What are them concisted of ?###

The project contains binary executables, which are complied from projects listed below:

* Linux Kernel LKL https://github.com/lkl/linux
* Shadowsock-libev https://github.com/shadowsocks/shadowsocks-libev
* Shadowsocks Simple-obfs https://github.com/shadowsocks/simple-obfs

And with some more applications installed from OS sources (epel repository).

* iptables
* haproxy
* dependencies ...(pcre openssl mbedtls libsodium libev c-ares libcap)


### How do I get set up? ###
Under Centos 7 64bit OS, run `./setup.sh`

### Why not other OSs ? ###

Mostly becaulse binary compatable, `obfs-server` and `shadowsocks-libev` need to recompile to match other OSs.

### How to compile (skip this if you're a normal user) ###

If you'd like to port the project running under other OS, it's fully possible.

#### liblkl-hijack.so ####

The customized lkl kernel here, is a bit different by selecting BBR and only as the default TCP alogrithm, removing filesystem supports, to reduce size, etc. The kernel config is `lklconfig`. By compile your own `liblkl-hijack.so`, clone the lkl source, copy `lklconfig` as `.config` in the root directory, and run 

```
sed -i 's/defconfig/oldconfig/' tools/lkl/Makefile
make -C tools/lkl
```

Other headups please refer to the lkl project, lastly remember to strip the `liblkl-hijack.so`, it trims size to around 6 MiB.

#### obfs-server ####

Nothing is customized, refer to the `simple-obfs` project.

### About shadowsocks service ? ###

Defaultly, 2 shadowsocks service is up running on port 80 and 443 under obfuscating as http/https protocols.

Set your clients as listed below, and everything should just work.

Config 1

* IP: `YOUR.SERVER.IP`
* PORT: `80`
* PASSWORD: `lkl666`
* METHOD: `rc4-md5`
* PLUGIN: `obfs-local`
* PLUGIN_OPTS: `obfs=http;obfs-host=outlook.office.com`

Config 2

* IP: `YOUR.SERVER.IP`
* PORT: `443`
* PASSWORD: `lkl666`
* METHOD: `rc4-md5`
* PLUGIN: `obfs-local`
* PLUGIN_OPTS: `obfs=tls;obfs-host=outlook.office.com`

For security reasons, you should (or not if you're lazy) change the PASSWORD/METHOD in your own flavor. To do so, edit files under `/etc/shadowsocks-libev` accordingly.

On finished editing, restart shadowsocks service by commands:

* `systemctl restart shadowsocks-libev-server@obfstls`
* `systemctl restart shadowsocks-libev-server@obfshttp`

And if you do not want/need obfuscating, remove plugin lines in the config json. example as below:
```
{
    "server":"0.0.0.0",
    "server_port":443,
    "password":"lkl666",
    "timeout":600,
    "method":"aes-256-gcm"
}
```

One last thing, if you want to use other ports, there are more to configure, and hope you do understand them all:

* iptables `/etc/sysconfig/iptables` (`systemctl restart iptables` to restart after changing, same below)
* haproxy `/etc/haproxy/haproxy.cfg` (`systemctl restart haproxy`, this might have problems, try `ifup tap0`, restart OS if needed)
* Shadowsocks `/etc/shadowsocks-libev/*.json`( see ablove )

You might need to figure out how all this components working together, to customize them.

Finally, have luck and hope your server won't get blocked.
