#!/bin/sh
echo "Starting setup container please wait"

cleanup() {
    echo "Stopping Xray and hev-socks5-tunnel"
    killall xray 2>/dev/null
    killall hev-socks5-tunnel 2>/dev/null
    exit 0
}
trap cleanup TERM

# tunnel
TUN="${TUN:-tun0}"
MTU="${MTU:-9000}"
IPV4="${IPV4:-198.18.0.1}"
IPV6="${IPV6:-}"
MARK="${MARK:-438}"
SOCKS5_UDP_MODE="${SOCKS5_UDP_MODE:-udp}"
SOCKS5_PORT="${SOCKS5_PORT:-1080}"
OTHER_ROUTE="${OTHER_ROUTE:-}"
LOG_LEVEL="${LOG_LEVEL:-warn}"
ETH_IFACE=$(ip -o link show | awk -F': ' '/link\/ether/ {print $2}' | cut -d'@' -f1 | head -n1)
GATEWAY="${GATEWAY:-$(ip route | awk -v iface="$ETH_IFACE" '$0 ~ "default" && $0 ~ iface {print $3}')}"

config_file() {
  cat > /opt/hs5t.yml << EOF
misc:
  log-level: '${LOG_LEVEL}'
tunnel:
  name: '${TUN}'
  mtu: ${MTU}
  ipv4: '${IPV4}'
  ipv6: '${IPV6}'
  post-up-script: '/route.sh'
socks5:
  address: '127.0.0.1'
  port: 1080
  udp: '${SOCKS5_UDP_MODE}'
  mark: ${MARK}
EOF
}

config_route() {
  echo "#!/bin/sh" > /route.sh
  chmod +x /route.sh
  echo "ip rule add from all uidrange 1000-1000 lookup 110 pref 28000" >> /route.sh
  echo "ip route flush table 110" >> /route.sh
  echo "ip route add default via $GATEWAY dev $ETH_IFACE metric 50 table 110" >> /route.sh
  echo "ip route del default" >> /route.sh
  echo "ip route add default via ${IPV4} dev ${TUN} metric 1" >> /route.sh
  echo "ip route add default via $GATEWAY dev $ETH_IFACE metric 10" >> /route.sh
  # exclude local network
  echo "ip route add 10.0.0.0/8 via $GATEWAY dev $ETH_IFACE" >> /route.sh
  echo "ip route add 172.16.0.0/12 via $GATEWAY dev $ETH_IFACE" >> /route.sh
  echo "ip route add 192.168.0.0/16 via $GATEWAY dev $ETH_IFACE" >> /route.sh
  echo "${OTHER_ROUTE}" >> /route.sh
}

# > /etc/resolv.conf
# for ip in $DNS; do
#     echo "nameserver $ip" >> /etc/resolv.conf
# done

adduser -u 1000 -D -H -h / -s /bin/sh xray
config_file
config_route
echo "Starting hev-socks5-tunnel"
/opt/hev-socks5-tunnel /opt/hs5t.yml &
echo "Starting Xray core"
su - xray -c "/opt/xray -config /etc/xray/config.json"
