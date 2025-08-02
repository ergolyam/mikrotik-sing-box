# mikrotik-sing-box

## Preparation

1. **Connect the flash drive to mikrotik and format it to ext4.**:
    - Go to `System > Disks > Format drive`.
    - Select slot `usb1` and file system `ext4` and press start.
    - Wait until the start button is available again.
    - When it is available, everything is ready.

2. **We need to install the `container` package**:
    - Go to the site [Software Packages](https://mikrotik.com/download).
    - Download `Extra packages` for your architecture.
    - Pull out the `container*.npk` installation file and drop it into the root of the mikrotik's file system.
    - Enable container in mikrotik.
        ```plaintext
        /system/device-mode update container=yes
        ```

    - Restart the router.
        ```plaintext
        /system reboot
        ```

- After restarting, the package from the file system will disappear and an item will be added to the winbox, `container`.

3. **Configuring `container` plugin**:
    - You need to register at [docker.io](https://hub.docker.com/).
    - After registering, enter the following command, where username and password are your login and password from [docker.io](https://hub.docker.com/).
        ```plaintext
        /container/config set registry-url=https://registry-1.docker.io tmpdir=/usb1/docker/pull username=<username> password=<password>
        ```

4. **Creating a bridge for our future containers**:
    ```plaintext
    /interface/bridge add name=Bridge-Docker port-cost-mode=short
    /ip/address add address=192.168.254.1/24 interface=Bridge-Docker network=192.168.254.0
    ```

5. **Configuring the DoH [DNS-DNSoverHTTPS(DoH)](https://help.mikrotik.com/docs/pages/viewpage.action?pageId=83099652#DNS-DNSoverHTTPS(DoH))**
    ```plaintext
    /tool/fetch url="https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem"
    /certificate import file-name=DigiCertGlobalRootCA.crt.pe
    /ip/dns set use-doh-server=https://cloudflare-dns.com/dns-query verify-doh-cert=yes
    /ip/dns set servers=1.1.1.1
    ```
    - Redirect absolutely all dns requests through doh except local ones:
        ```plaintext
        /ip/firewall/address-list add address=10.0.0.0/8 list=local
        /ip/firewall/address-list add address=172.16.0.0/12 list=local
        /ip/firewall/address-list add address=192.168.0.0/16 list=local
        /ip/firewall/nat add action=redirect chain=dstnat dst-address-list=!local dst-port=53 in-interface-list=LAN protocol=udp
        /ip/firewall/nat add action=redirect chain=dstnat dst-address-list=!local dst-port=53 in-interface-list=LAN protocol=tcp
        ```
    - Go to https://www.dnsleaktest.com/ and make sure the dns `Cloudflare` is there.

## Installation sing-box

1. **Create a virtual interface**:
    - Replace `X` with any unused number (for example, `192.168.254.2/24`).  
        ```plaintext
        /interface/veth add address=192.168.254.X/24 gateway=192.168.254.1 name=SING-BOX
        ```
    - This command creates a new VETH (virtual Ethernet) interface on your MikroTik device.

2. **Add the virtual interface to the main bridge**:
    ```plaintext
    /interface/bridge/port add bridge=bridge interface=SING-BOX
    ```
    - This ensures traffic from the SING-BOX interface can reach other LAN interfaces via the main bridge.

4. **Pull the sing-box container image**:
    ```plaintext
    /container add remote-image=ergolyam/mikrotik-sing-box interface=SING-BOX root-dir=usb1/docker/sing-box dns=1.1.1.1 start-on-boot=yes envlist=vless
    ```
    - The `remote-image` option specifies which container image to pull from Docker Hub.  
    - `interface=SING-BOX` sets the VETH interface for the container.  
    - `root-dir=usb1/docker/sing-box` is where container data will be stored.  
    - Watch the download progress by running:
        ```plaintext
        /log/print interval=5
        ```

5. **Set up sing-box env's**:
    ```plaintext
    /container/envs
    add name=vless key=REMOTE_ADDRESS value=127.0.0.1
    add name=vless key=REMOTE_PORT value=443
    add name=vless key=ID value=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    add name=vless key=PUBLIC_KEY value=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    add name=vless key=SHORT_ID value=123456
    add name=vless key=FLOW value=xtls-rprx-vision
    add name=vless key=FINGER_PRINT value=chrome
    add name=vless key=SERVER_NAME value=t.me
    ```

6. **Start the container**:
    ```plaintext
    /container start [find interface=SING-BOX]
    ```
    - This command starts the container that was just created.
    - Now you can connect via any socks or http client to our container via ip `192.168.254.X` and port `1080`.

## Configuring split tunneling

1. **Configure the term of dns addresses**:
    ```plaintext
    /ip/dns set address-list-extra-time=1d
    ```

2. **Configuring the route tables**:
    ```plaintext
    /routing/table add disabled=no fib name=vless_mark
    /ip/route add disabled=no distance=22 dst-address=0.0.0.0/0 gateway=192.168.254.X%Bridge-Docker pref-src="" routing-table=vless_mark scope=30 suppress-hw-offload=no target-scope=10
    ```

3. **Make a mangle rule to wrap our hosts in the route table**:
    ```plaintext
    /ip/firewall/mangle add action=mark-connection chain=prerouting comment="In vless" connection-mark=no-mark dst-address-list=in_vless_FWD in-interface-list=LAN new-connection-mark=to_vless passthrough=yes
    /ip/firewall/mangle add action=mark-routing chain=prerouting comment="To vless" connection-mark=to_vless in-interface-list=LAN new-routing-mark=vless_mark passthrough=no routing-mark=!vless_mark
    ```

4. **Disable forward fasttrack connection to speed up routing**:
    ```plaintext
    /ip/firewall/filter disable [find action=fasttrack-connection]
    ```
    - You can also simply exclude labeled traffic:
        ```plaintext
        /ip/firewall/filter set [find action=fasttrack-connection] packet-mark=no-mark connection-mark=no-mark
        ```

5. **Add hosts that we want to pass through sing-box**:
    ```plaintext
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=googlevideo.com type=FWD
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=youtube.com type=FWD
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=youtubei.googleapis.com type=FWD
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=ytimg.com type=FWD
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=youtu.be type=FWD
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=ggpht.com type=FWD
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=rutracker.org type=FWD
    /ip/dns/static add address-list=in_vless_FWD forward-to=localhost match-subdomain=yes name=rutracker.cc type=FWD
    ```

6. **Clear the dns cache and restart the router**:
    ```plaintext
    /ip/dns/cache flush
    /system reboot
    ```

