#!/bin/sh

# Auto Script Install Radius Monitor + Database + Mysql
# By HideSSH 


openwrt_arch=$(uname -m)
openwrt_version=$(grep ^VERSION= /etc/os-release | cut -d '"' -f 2)
script_version="v1.1.0"
script_changelog="Fixed - Last Edit: 08-10-2024"

cd /tmp
#===========================================================================================================================
dl_ipk() {
    # Mendapatkan arsitektur sistem
    local arch=$(uname -m)
    local name_ipk=$(echo "$1" | cut -d'|' -f1)
    local base_url=$(echo "$1" | cut -d'|' -f2)
    local dir_url="${base_url}/${arch}/packages"
    
    wget -qO- "$dir_url" | sed -n 's/.*href="\([^"]*'$name_ipk'[^"]*\)".*/\1/p' | sort -V | tail -n1 | {
        read dl_package
        if [ -z "$dl_package" ]; then
            echo "Tidak dapat menemukan paket $name_ipk untuk arsitektur $arch."
            exit 1
        fi
        
        download_url="${dir_url}/${dl_package}"
        
        wget "$download_url" -O /tmp/$name_ipk.ipk
        if [ $? -ne 0 ]; then
            echo "Gagal mendownload paket $name_ipk."
            exit 1
        fi
        
        opkg install /tmp/$name_ipk.ipk
        if [ $? -ne 0 ]; then
            echo "Gagal menginstal paket $name_ipk."
            exit 1
        fi
        
        rm /tmp/$name_ipk.ipk
    }
}
#===========================================================================================================================

#===========================================================================================================================
# Cek lolcat dan git
if ! opkg list-installed | grep -q "^lolcat " || ! opkg list-installed | grep -q "^git " || ! opkg list-installed | grep -q "^git-http "; then
    echo "Update PKG and install lolcat and git"
    opkg update
    if [ "$(printf '%s\n' "21.02" "$openwrt_version" | sort -V | head -n1)" = "$openwrt_version" ]; then
        dl_ipk "lolcat|https://downloads.openwrt.org/snapshots/packages/$openwrt_arch/packages"
    else
        opkg install lolcat
    fi
    opkg install git
    opkg install git-http
fi
#===========================================================================================================================

#===========================================================================================================================
# CMD Install
cmdinstall() {
local MAX_TIME=60
while true; do
  local start_time=$(date +%s)
  echo "Notes: $2 ..." | lolcat
  echo "Mohon Tunggu Sebentar.." | lolcat
  echo "Pastikan koneksi internet lancar.." | lolcat
  local output=$($1 2>&1)
  local exit_code=$?
  local end_time=$(date +%s)
  local elapsed_time=$((end_time - start_time))
  if [ $exit_code -eq 0 ]; then
    if [ $elapsed_time -gt $MAX_TIME ]; then
      echo "${2} berhasil, tapi koneksi lambat (waktu: ${elapsed_time}s)." | lolcat
    else
      echo "${2} berhasil." | lolcat
    fi
    sleep 3
    clear
    break
  else
    if [ $elapsed_time -gt $MAX_TIME ]; then
      echo "${2} gagal, mungkin karena koneksi lambat (waktu: ${elapsed_time}s). Mengulangi..." | lolcat
    else
      echo "${2} gagal. Mengulangi..." | lolcat
    fi
    echo "Log kesalahan:" | lolcat
    echo "$output" | lolcat
    sleep 2
    clear
  fi
  sleep 5
done
}
#===========================================================================================================================


clone_gh() {
    local REPO_URL="$1"
    local BRANCH="$2"
    local TARGET_DIR="$3"
    rm -rf $TARGET_DIR
    echo "Cloning repository..." | lolcat
    cmdinstall "git clone -b $BRANCH $REPO_URL $TARGET_DIR" "Clone Repo"
}

#===========================================================================================================================
# Cek Update Di Github | HASH
echo "Currently checking script updates..." | lolcat
GITHUB_URL="https://raw.githubusercontent.com/rtaserver/RadiusMonitor/radius/autoscript"
LOCAL_SCRIPT="/usr/bin/radmoninstaller"
LOCAL_HASH=$(sha256sum "$LOCAL_SCRIPT" | awk '{ print $1 }')
TEMP_FILE="/tmp/radmontmp"
wget -qO "$TEMP_FILE" "$GITHUB_URL" &>/dev/null
REMOTE_HASH=$(sha256sum "$TEMP_FILE" | awk '{ print $1 }')
clear
if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
  echo "Update local scripts with the latest scripts."
  sleep 3
  cp "$LOCAL_SCRIPT" "${LOCAL_SCRIPT}.bak"
  mv "$TEMP_FILE" "$LOCAL_SCRIPT"
  chmod +x "$LOCAL_SCRIPT"
  exec "$LOCAL_SCRIPT"
else
  echo "The script is up to date, no update needed." | lolcat
  sleep 2
fi
rm -f "$TEMP_FILE"
#===========================================================================================================================

#===========================================================================================================================
# Install PHP8 Pkg
install_packages_php8() {
    cmdinstall "opkg update" "Update PKG"
    cmdinstall "opkg remove libgd --force-depends" "Remove LibGD"
    if [ "$(echo "$openwrt_version" | cut -d'.' -f1)" = "23" ]; then
        cmdinstall "opkg install libopenssl-legacy" "Install Lib Legacy"
    fi
    cmdinstall "opkg install php8 php8-cgi php8-cli php8-fastcgi php8-fpm \
    php8-mod-bcmath php8-mod-calendar php8-mod-ctype php8-mod-curl php8-mod-dom php8-mod-exif \
    php8-mod-fileinfo php8-mod-filter php8-mod-gd php8-mod-iconv php8-mod-intl php8-mod-mbstring php8-mod-mysqli \
    php8-mod-mysqlnd php8-mod-opcache php8-mod-openssl php8-mod-pdo php8-mod-pdo-mysql php8-mod-phar php8-mod-session \
    php8-mod-xml php8-mod-xmlreader php8-mod-xmlwriter php8-mod-zip" "Install PHP8"
    clear
}
configur_php8() {
    sed -i -E "s|memory_limit = [0-9]+M|memory_limit = 100M|g" /etc/php.ini
    sed -i -E "s|display_errors = On|display_errors = Off|g" /etc/php.ini
    uci set uhttpd.main.index_page='index.php'
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci commit uhttpd
    /etc/init.d/uhttpd restart
}
#===========================================================================================================================

#===========================================================================================================================

install_packages_pear() {
    cmdinstall "wget -O go-pear.phar https://pear.php.net/go-pear.phar" "Download Bahan Pear"
    ln -s /usr/bin/php-cli /usr/bin/php
    clear
}
configur_pear() {
    echo "Tutorial:" | lolcat
    echo " > 1. Saat ditanya '1-12, all or Enter to continue:', Klik Enter" | lolcat
    echo " > 2. Kemudian Ketik 'Y' dan tekan Enter" | lolcat
    echo " > 3. Lanjut tekan Enter lagi" | lolcat
    echo ""
    echo -n "Tekan Enter untuk melanjutkan ke instalasi: " | lolcat
    read -r
    echo ""
    php go-pear.phar
    cmdinstall "/root/pear/bin/pear install DB" "Install DB Pear"
    rm -rf go-pear.phar
}
#===========================================================================================================================
#===========================================================================================================================
install_packages_mariadb() {
    cmdinstall "opkg update" "Update PKG"
    cmdinstall "opkg install mariadb-server mariadb-server-extra mariadb-client mariadb-client-extra libmariadb nano" "Install MariaDB"
    clear
}
configur_mariadb() {
    sed -i -E "s|option enabled '0'|option enabled '1'|g" /etc/config/mysqld
    sed -i -E "s|# datadir		= /srv/mysql|datadir	= /usr/share/mysql|g" /etc/mysql/conf.d/50-server.cnf
    sed -i -E "s|127.0.0.1|0.0.0.0|g" /etc/mysql/conf.d/50-server.cnf
    cmdinstall "/etc/init.d/mysqld restart" "Merestart Mysqld"
    cmdinstall "/etc/init.d/mysqld reload" "Mereload Mysqld"

    echo -n "Masukan Password Baru Untuk MariaDB root: " | lolcat
    read root_password
    echo ""
    mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${root_password}');"
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password}';"
    mysql -u root -p"${root_password}" <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

    mysql -u root -p"${root_password}" -e "CREATE DATABASE radius CHARACTER SET utf8";
    mysql -u root -p"${root_password}" -e "GRANT ALL ON radius.* TO 'radius'@'localhost' IDENTIFIED BY 'radius' WITH GRANT OPTION";
}
#===========================================================================================================================
#===========================================================================================================================
install_packages_radmon() {
    clone_gh "https://github.com/Maizil41/RadiusMonitor.git" "main" "/www/RadiusMonitor"
    clone_gh "https://github.com/Maizil41/radiusbilling.git" "main" "/www/raddash"
    cd /tmp
    cmdinstall "wget https://raw.githubusercontent.com/rtaserver/RadiusMonitor/refs/heads/radius/radius_monitor.sql" "Download SQL"
    clear
}
configur_radmon() {
    echo "Menginstall Database Radius Monitor." | lolcat
    echo -n "Masukan MariaDB root password: " | lolcat
    read root_password
    echo ""
    mysql -u root -p"${root_password}" radius -e "SET FOREIGN_KEY_CHECKS = 0; $(mysql -u root -p"${root_password}" radius -e 'SHOW TABLES' | awk '{print "DROP TABLE IF EXISTS `" $1 "`;"}' | grep -v '^Tables' | tr '\n' ' ') SET FOREIGN_KEY_CHECKS = 1;"
    mysql -u root -p"${root_password}" radius < /tmp/radius_monitor.sql
    rm -rf /tmp/radius_monitor.sql
    mysql -u root -p"${root_password}" radius < /www/RadiusMonitor/radmon.sql
    mysql -u root -p"${root_password}" radius < /www/raddash/raddash.sql
    cat <<'EOF' >/usr/lib/lua/luci/controller/radmon.lua
module("luci.controller.radmon", package.seeall)
function index()
entry({"admin","services","radmon"}, template("radmon"), _("Radius Monitor"), 3).leaf=true
end
EOF

    cat <<'EOF' >/usr/lib/lua/luci/view/radmon.htm
<%+header%>
<div class="cbi-map"><br/>
<iframe id="rad_mon" style="width: 100%; min-height: 100vh; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("rad_mon").src = window.location.protocol + "//" + window.location.host + "/RadiusMonitor";
</script>
<%+footer%>
EOF

chmod +x /usr/lib/lua/luci/view/radmon.htm
}
#===========================================================================================================================
#===========================================================================================================================
install_packages_phpmyadmin() {
    if [ -d "/www/phpmyadmin" ]; then rm -rf /www/phpmyadmin; fi
    if [ -d "/www/phpMyAdmin-5.2.1-all-languages" ]; then rm -rf /www/phpMyAdmin-5.2.1-all-languages; fi
    cd /www
    cmdinstall "wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip" "Download PhpMyAdmin"
    cmdinstall "unzip phpMyAdmin-5.2.1-all-languages.zip" "Mengekstrak Bahan"
    rm -rf phpMyAdmin-5.2.1-all-languages.zip
    mv phpMyAdmin-5.2.1-all-languages phpmyadmin
}
configur_phpmyadmin() {
    mv /www/phpmyadmin/config.sample.inc.php /www/phpmyadmin/config.inc.php
    sed -i -E "s|localhost|127.0.0.1|g" /www/phpmyadmin/config.inc.php
    sed -i "/\$cfg\['Servers'\]\[.*\]\['AllowNoPassword'\] = false;/a \$cfg\['AllowThirdPartyFraming'\] = true;" /www/phpmyadmin/config.inc.php
    cat <<'EOF' >/usr/lib/lua/luci/controller/phpmyadmin.lua
module("luci.controller.phpmyadmin", package.seeall)
function index()
entry({"admin","services","phpmyadmin"}, template("phpmyadmin"), _("PhpMyAdmin"), 3).leaf=true
end
EOF

    cat <<'EOF' >/usr/lib/lua/luci/view/phpmyadmin.htm
<%+header%>
<div class="cbi-map"><br/>
<iframe id="phpmyadmin" style="width: 100%; min-height: 100vh; border: none; border-radius: 2px;"></iframe>
</div>
<script type="text/javascript">
document.getElementById("phpmyadmin").src = window.location.protocol + "//" + window.location.host + "/phpmyadmin";
</script>
<%+footer%>
EOF

chmod +x /usr/lib/lua/luci/view/phpmyadmin.htm
}
#===========================================================================================================================
#===========================================================================================================================
install_packages_freeradius() {
    cmdinstall "opkg update" "Update PKG"
    cmdinstall "opkg install freeradius3 freeradius3-common freeradius3-default freeradius3-mod-always freeradius3-mod-attr-filter \
    freeradius3-mod-chap freeradius3-mod-detail freeradius3-mod-digest freeradius3-mod-eap \
    freeradius3-mod-eap-gtc freeradius3-mod-eap-md5 freeradius3-mod-eap-mschapv2 freeradius3-mod-eap-peap \
    freeradius3-mod-eap-pwd freeradius3-mod-eap-tls freeradius3-mod-eap-ttls freeradius3-mod-exec \
    freeradius3-mod-expiration freeradius3-mod-expr freeradius3-mod-files freeradius3-mod-logintime \
    freeradius3-mod-mschap freeradius3-mod-pap freeradius3-mod-preprocess freeradius3-mod-radutmp \
    freeradius3-mod-realm freeradius3-mod-sql freeradius3-mod-sql-mysql freeradius3-mod-sqlcounter \
    freeradius3-mod-unix freeradius3-utils libfreetype wget-ssl curl unzip tar zoneinfo-asia" "Install Freeradius"
    clear
    clone_gh "https://github.com/rtaserver/RadiusMonitor.git" "radius" "/tmp/radmoninstaller"
    clear
}
configur_freeradius() {
    /etc/init.d/radiusd stop

    rm -rf /etc/freeradius3
    cd /tmp/radmoninstaller/etc
    mv freeradius3 /etc/freeradius3

    rm -rf /usr/share/freeradius3
    cd /tmp/radmoninstaller/usr/share
    mv freeradius3 /usr/share/freeradius3

    cd /etc/freeradius3/mods-enabled
    ln -s ../mods-available/always
    ln -s ../mods-available/attr_filter
    ln -s ../mods-available/chap
    ln -s ../mods-available/detail
    ln -s ../mods-available/digest
    ln -s ../mods-available/eap
    ln -s ../mods-available/exec
    ln -s ../mods-available/expiration
    ln -s ../mods-available/expr
    ln -s ../mods-available/files
    ln -s ../mods-available/logintime
    ln -s ../mods-available/mschap
    ln -s ../mods-available/pap
    ln -s ../mods-available/preprocess
    ln -s ../mods-available/radutmp
    ln -s ../mods-available/realm
    ln -s ../mods-available/sql
    ln -s ../mods-available/sradutmp
    ln -s ../mods-available/unix

    cd /etc/freeradius3/sites-enabled
    ln -s ../sites-available/default
    ln -s ../sites-available/inner-tunnel

    rm -rf /tmp/radmoninstaller
    
    if ! grep -q '/etc/init.d/radiusd restart' /etc/rc.local; then
        sed -i '/exit 0/i /etc/init.d/radiusd restart' /etc/rc.local
    fi
}
#===========================================================================================================================
#===========================================================================================================================
install_packages_chilli() {
    cmdinstall "opkg update" "Update PKG"
    cmdinstall "opkg install coova-chilli" "Install Chilli"
    clear
    clone_gh "https://github.com/rtaserver/RadiusMonitor.git" "radius" "/tmp/radmoninstaller"
    clear
}
configur_chilli() {
    /etc/init.d/chilli stop
    rm -rf /etc/config/chilli
    rm -rf /etc/init.d/chilli

    mv /tmp/radmoninstaller/etc/config/chilli /etc/config/chilli
    mv /tmp/radmoninstaller/etc/init.d/chilli /etc/init.d/chilli
    mv /tmp/radmoninstaller/usr/share/hotspotlogin /usr/share/hotspotlogin
    ln -s /usr/share/hotspotlogin /www/hotspotlogin
    
    chmod +x /etc/init.d/chilli
    rm -rf /tmp/radmoninstaller
}
#===========================================================================================================================
#===========================================================================================================================
configur_netfirewall() {
    # Config Network
    echo "Menambahkan konfigurasi jaringan baru untuk br-hotspot..." | lolcat
    echo "Daftar semua Network Device di OpenWrt..." | lolcat

    # List all network devices
    ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | while read -r device; do
        case "$device" in
            lo|br-lan|br-hotspot|tun0|utun)
                continue
                ;;
            *)
                echo "Device: $device" | lolcat
                ;;
        esac
    done

    echo ""
    echo "Masukkan Network Device yang tersedia. Jika kosong, 'wlan0' akan digunakan." | lolcat
    echo -n "Masukkan Network Device: " | lolcat
    read dev_hotspot

    if [ -z "$dev_hotspot" ]; then
        dev_hotspot="wlan0"
    fi

    echo "Mengonfigurasi 'br-hotspot' dengan device '$dev_hotspot'..." | lolcat
    uci set network.hotspot=device
    uci set network.hotspot.name='br-hotspot'
    uci set network.hotspot.type='bridge'
    uci set network.hotspot.ipv6='0'
    uci add_list network.hotspot.ports="${dev_hotspot}"

    uci set network.voucher=interface
    uci set network.voucher.name='voucher'
    uci set network.voucher.proto='static'
    uci set network.voucher.device='br-hotspot'
    uci set network.voucher.ipaddr='10.10.30.1'
    uci set network.voucher.netmask='255.255.255.0'

    uci set network.chilli=interface
    uci set network.chilli.proto='none'
    uci set network.chilli.device='tun0'

    uci commit network

    echo "Konfigurasi jaringan telah diperbarui." | lolcat
    
    sleep 3

    ## Config Firewall
    if ! uci show firewall | grep -q "firewall\.tun="; then
        echo "Adding 'tun' zone..." | lolcat
        uci set firewall.tun=zone
        uci set firewall.tun.name='tun'
        uci set firewall.tun.input='ACCEPT'
        uci set firewall.tun.output='ACCEPT'
        uci set firewall.tun.forward='REJECT'
        uci add_list firewall.tun.network='chilli'
    else
        echo "'tun' zone already exists." | lolcat
    fi

    sleep 3

    forwarding_exists=false
    for i in $(uci show firewall | grep -o "firewall.@forwarding\[[0-9]\+\]"); do
        src=$(uci get ${i}.src)
        dest=$(uci get ${i}.dest)
        if [ "$src" = "tun" ] && [ "$dest" = "wan" ]; then
            forwarding_exists=true
            break
        fi
    done

    if [ "$forwarding_exists" = false ]; then
        echo "Adding forwarding from 'tun' to 'wan'..." | lolcat
        uci add firewall forwarding
        uci set firewall.@forwarding[-1].src='tun'
        uci set firewall.@forwarding[-1].dest='wan'
    else
        echo "Forwarding from 'tun' to 'wan' already exists." | lolcat
    fi

    uci add_list firewall.@zone[0].network='voucher'

    uci commit firewall

    echo "Firewall configuration check and update complete." | lolcat

    sleep 3
}
#===========================================================================================================================
while true; do
    clear
    echo "================================================" | lolcat
    echo "           Auto Script | RadiusChilli           " | lolcat
    echo "================================================" | lolcat
    echo ""
    echo "    [*]     RadiusChilli By : HideSSH   [*]" | lolcat
    echo "    [*]    Radius Monitor By : HideSSH  [*]" | lolcat
    echo "    [*]   Auto Script By : HideSSH  [*]" | lolcat
    echo ""
    echo "================================================" | lolcat
    echo "  -> Version : ${script_version}" | lolcat
    echo "  -> Changelog : ${script_changelog}" | lolcat
    echo "================================================" | lolcat
    echo " > 1 - Install Packages PHP8"
    echo " > 2 - Install Packages PEAR DB"
    echo " > 3 - Install Packages MariaDB"
    echo " > 4 - Install Packages Radius Monitor + Database"
    echo " > 5 - Install Packages PhpMyAdmin (Opsional)"
    echo " > 6 - Install Packages Freeradius3 + Config"
    echo " > 7 - Install Packages Chilli + Config"
    echo " > 8 - Install Network Firewall Hotspot"
    echo ""
    echo " > 9 - Reload Freeradius And Chilli"
    echo "================================================" | lolcat
    echo ""
    echo " > 10 - Update Script"
    echo " > 11 - Update Radius Monitor"
    echo ""
    echo "================================================" | lolcat
    echo " > X - Exit Script"
    echo "================================================" | lolcat
    echo "  Notes: Rekomendasi Restart / Reboot OpenWrt"
    echo "         Setelah Semua Installasi Selesai"
    echo "================================================" | lolcat

    echo -n "Silahkan pilih menu (1-12) or (13-14 For Update): " | lolcat
    read choice

    case $choice in
        1)
            echo "Installing PHP8 packages..." | lolcat
            sleep 2
            clear
            install_packages_php8
            configur_php8
            clear
            echo "Installation completed successfully!" | lolcat
            ;;
        2)
            echo "Installing PEAR packages..." | lolcat
            sleep 2
            clear
            install_packages_pear
            configur_pear
            clear
            echo "Installation completed successfully!" | lolcat
            ;;
        3)
            echo "Installing MariaDB packages..." | lolcat
            sleep 2
            clear
            install_packages_mariadb
            configur_mariadb
            clear
            echo "Installation completed successfully!" | lolcat
            ;;
        4)
            echo "Installing Radius Monitor packages..." | lolcat
            sleep 2
            clear
            install_packages_radmon
            configur_radmon
            clear
            echo "Installation completed successfully!" | lolcat
            IP=$(uci get network.lan.ipaddr)
            echo "Direct Link : http://${IP}/RadiusMonitor/" | lolcat
            echo "Menu : Services -> Radius Monitor" | lolcat
            sleep 3
            ;;
        5)
            echo "Installing PhpMyAdmin packages..." | lolcat
            sleep 2
            clear
            install_packages_phpmyadmin
            configur_phpmyadmin
            clear
            echo "Installation completed successfully!" | lolcat
            IP=$(uci get network.lan.ipaddr)
            echo "Direct Link : http://${IP}/phpmyadmin/" | lolcat
            echo "Menu : Services -> PhpMyAdmin" | lolcat
            sleep 3
            ;;
        6)
            echo "Installing Freeradius3 packages..." | lolcat
            sleep 2
            clear
            install_packages_freeradius
            configur_freeradius
            clear
            echo "Installation completed successfully!" | lolcat
            ;;
        7)
            echo "Installing Chilli packages..." | lolcat
            sleep 2
            clear
            install_packages_chilli
            configur_chilli
            clear
            echo "Installation completed successfully!" | lolcat
            ;;
        8)
            echo "Configuring Network Firewall Hotspot..." | lolcat
            sleep 2
            clear
            configur_netfirewall
            clear
            echo "Installation completed successfully!" | lolcat
            ;;
        9)
            echo "Reloading Freeradius..." | lolcat
            cmdinstall "/etc/init.d/radiusd restart" "Reload Freeradius"
            echo "Reloading Chilli..." | lolcat
            cmdinstall "/etc/init.d/chilli restart" "Reload Chilli"
            ;;
        10)
            echo "Update Script.." | lolcat
            bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RadiusMonitor/radius/autoscript')"
            ;;
        11)
            echo "Update Radius Monitor.." | lolcat
            clone_gh "https://github.com/Maizil41/RadiusMonitor.git" "main" "/www/RadiusMonitor"
            clone_gh "https://github.com/Maizil41/radiusbilling.git" "main" "/www/raddash"
            echo "Menginstall Database Radius Monitor." | lolcat
            echo -n "Masukan MariaDB root password: " | lolcat
            read root_password
            echo ""
            mysql -u root -p"${root_password}" radius < /www/RadiusMonitor/radmon.sql
            mysql -u root -p"${root_password}" radius < /www/raddash/raddash.sql
            ;;
        x|X)
            echo "Exiting..." | lolcat
            exit
            ;;
        *)
            echo "Invalid option selected!" | lolcat
            ;;
    esac

    echo "Kembali ke menu..." | lolcat
    cd /tmp
    sleep 2
done
