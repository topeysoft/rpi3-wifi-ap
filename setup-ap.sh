#!/bin/bash
#
# This version uses September 2016 rpi jessie image, please use this image
#

if [ "$EUID" -ne 0 ]
	then echo "Must be root"
	exit
fi

if [[ $# -lt 1 ]]; 
	then echo "You need to pass a password!"
	echo "Usage:"
	echo "sudo $0 yourChosenPassword [apName]"
	exit
fi

APPASS="$1"
APSSID="ElyirHub.AP"

if [[ $# -eq 2 ]]; then
	APSSID=$2
fi

apt-get remove --purge hostapd -y
apt-get install hostapd dnsmasq -y

cat > /etc/systemd/system/hostapd.service <<EOF
[Unit]
Description=Hostapd IEEE 802.11 Access Point
After=sys-subsystem-net-devices-wlan0.device
BindsTo=sys-subsystem-net-devices-wlan0.device

[Service]
Type=forking
PIDFile=/var/run/hostapd.pid
ExecStart=/usr/sbin/hostapd -B /etc/hostapd/hostapd.conf -P /var/run/hostapd.pid

[Install]
WantedBy=multi-user.target

EOF

cat > /etc/dnsmasq.conf <<EOF
interface=lo,uap0
no-dhcp-interface=lo,wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=10.0.0.2,10.0.0.5,255.255.255.0,12h
EOF
# cat > /etc/dnsmasq.conf <<EOF
# interface=wlan0
# dhcp-range=10.0.0.2,10.0.0.5,255.255.255.0,12h
# EOF

cat > /etc/hostapd/hostapd.conf <<EOF
interface=uap0
hw_mode=g
channel=10
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
wpa_passphrase=$APPASS
ssid=$APSSID
EOF

# sed -i -- 's/allow-hotplug wlan0//g' /etc/network/interfaces
# sed -i -- 's/iface wlan0 inet manual//g' /etc/network/interfaces
# sed -i -- 's/    wpa-conf \/etc\/wpa_supplicant\/wpa_supplicant.conf//g' /etc/network/interfaces


cat > /usr/local/bin/hostapdstart <<EOF
#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
iw dev wlan0 interface add uap0 type __ap
service dnsmasq restart
sysctl net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 ! -d 10.0.0.0/24 -j MASQUERADE
ifup uap0
hostapd /etc/hostapd/hostapd.conf
EOF

chmod 775 /usr/local/bin/hostapdstart

cat > /etc/network/interfaces <<EOF
source-directory /etc/network/interfaces.d

auto lo
auto eth0
auto wlan0
auto uap0

iface eth0 inet dhcp
iface lo inet loopback

allow-hotplug wlan0

iface wlan0 inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

iface uap0 inet static
  address 10.0.0.1
  netmask 255.255.255.0
  network 10.0.0.0
  broadcast 10.0.0.255
  gateway 10.0.0.1
EOF



#Uncomment #DAEMON_CONF="
sed -i -- 's/#DAEMON_CONF="/DAEMON_CONF="/g' /etc/sysctl.conf
#Change value of DAEMON_CONF to "/etc/hostapd/hostapd.conf" if not already that
sed -i -- 's/DAEMON_CONF=""/DAEMON_CONF="/etc/hostapd/hostapd.conf"/g' /etc/sysctl.conf


#Remove /bin/bash /usr/local/bin/hostapdstart if already exists"
sed -i -- 's:/bin/bash /usr/local/bin/hostapdstart::g' /etc/rc.local
#Add "/bin/bash /usr/local/bin/hostapdstart" right before exit 0
sed -i -- 's: exit 0 :/bin/bash /usr/local/bin/hostapdstart \n  exit 0 :g' /etc/rc.local


# echo "denyinterfaces wlan0" >> /etc/dhcpcd.conf

systemctl enable hostapd
service hostapd start
service dnsmasq start
echo "Access point creation complete!"
#echo "All done! Please reboot"