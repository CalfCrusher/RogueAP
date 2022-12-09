
#!/bin/bash

INTERNET_CARD="wlan0" # The device who is connected to internet
AP_CARD="wlan1" # The device who act as AP (an Alfa card with ap capabilities)

# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
	echo -e "\n\n[*] Restoring original state.."
    	# Restoring original state..
    	kill $(pidof wpa_supplicant)
    	kill $(pidof hostapd)
    	kill $(pidof dnsmasq)
	ip link set $AP_CARD down
	ip link set $INTERNET_CARD down
    	iptables -F
    	echo 0 > /proc/sys/net/ipv4/ip_forward
	exit 1
}

echo -e "\n[*] Stop NetworkManager and connect to device who is connected to internet"
# Stop NetworkManager and connect to device who is connected to internet
systemctl stop NetworkManager
ip link set $INTERNET_CARD up
wpa_supplicant -i $INTERNET_CARD -c wpa_supplicant.conf &
sleep 10
dhclient $INTERNET_CARD
sleep 3

echo -e "\n[*] Configure routing (mon0 is for aireplay)."
# Configure routing (mon0 is for aireplay). $AP_CARD is our rogueap (Alfa card)
iw $AP_CARD interface add mon0 type monitor
ip link set $AP_CARD up
ifconfig $AP_CARD 192.168.88.1 netmask 255.255.255.0
route add -net 192.168.88.0 netmask 255.255.255.0 gw 192.168.88.1

echo -e "\n[*] Configure firewall rules"
# Configure firewall rules
iptables -F
iptables -X
iptables -A FORWARD -i $AP_CARD -o $INTERNET_CARD -j ACCEPT
iptables -A FORWARD -i $INTERNET_CARD -o $AP_CARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A POSTROUTING -o $INTERNET_CARD -j MASQUERADE

echo -e "\n[*] Enable porforwarding"
# Enable portforwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

echo -e "\n[*] Run hostapd and dnsmasq"
# Run hostapd and dnsmasq
hostapd -B ./hostapd.conf
sleep 2
dnsmasq -C ./dnsmasq.conf

echo -e "\n\n[!! RUNNING !!] .. ctrl+c to exit and clean"

# Run for 2 hours. Set to your needs.
for i in `seq 1 7200`; do
	sleep 1
done
