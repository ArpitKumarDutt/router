#!/bin/sh

# luna firmware upgrade  script
# $1 image destination (0 or 1) 
# Kernel and root file system images are assumed to be located at the same directory named uImage and rootfs respectively
# ToDo: use arugements to refer to kernel/rootfs location.

k_img="uImage"
r_img="rootfs"
c_img="custconf"
img_ver="fwu_ver"
md5_cmp="md5.txt"
md5_cmd="/bin/md5sum"
#md5 run-time result
md5_tmp="md5_tmp" 
md5_rt_result="md5_rt_result.txt"
new_fw_ver="new_fw_ver.txt"
cur_fw_ver="cur_fw_ver.txt"
env_sw_ver="env_sw_ver.txt"
hw_ver_file="hw_ver"
skip_hwver_check="/tmp/skip_hwver_check"

# For YueMe framework
framework_img="framework.img"
framework_sh="framework.sh"
framework_upgraded=0

custconf_upgrade=0
fwu_size_file="fwu_len"
web_logo_oui1="=3894e0"
web_logo_oui2="=7ca96b"
web_logo_oui3="=5447e8"
web_logo_oui4="=a8e207"
web_logo_oui5="=b8b7db"
web_logo_oui6="=989db2"
weblock_ver2="/tmp/web_lockver"

echo `flash get ELAN_MAC_ADDR` > $weblock_ver2
if cat $weblock_ver2 | grep $web_logo_oui1; then
	echo "oui"$web_logo_oui1
elif cat $weblock_ver2 | grep $web_logo_oui2; then
	echo "oui"$web_logo_oui2
elif cat $weblock_ver2 | grep $web_logo_oui3; then
	echo "oui"$web_logo_oui3
elif cat $weblock_ver2 | grep $web_logo_oui4; then
	echo "oui"$web_logo_oui4
elif cat $weblock_ver2 | grep $web_logo_oui5; then
	echo "oui"$web_logo_oui5
elif cat $weblock_ver2 | grep $web_logo_oui6; then
	echo "oui"$web_logo_oui6
else
	echo "cusMac check failed."
	exit 1
fi
echo "cusMac check pass."

#Added by Grant, for mission#00015332
img_mtd_num="0"
if 
        cat /proc/mtd | grep \"k1\"
then    
	img_mtd_num=$1
else
#it's single mtd part.
	nv setenv sw_commit "0"
fi
echo "$1  ==>${img_mtd_num}"

# Stop this script upon any error
# set -e

if [ "`tar -tf $2 $framework_sh`" = "$framework_sh" ] && [ "`tar -tf $2 $framework_img`" = "$framework_img" ]; then
    echo "Updaing framework from $2"
    tar -xf $2 $framework_sh
    grep $framework_sh $md5_cmp > $md5_tmp
    $md5_cmd $framework_sh > $md5_rt_result
    diff $md5_rt_result $md5_tmp

    if [ $? != 0 ]; then 
        echo "$framework_sh md5_sum inconsistent, aborted image updating !"
        exit 1
    fi

    # Run firmware upgrade script extracted from image tar ball
    sh $framework_sh $2
    framework_upgraded=1
fi

if [ "`tar -tf $2 $k_img`" = '' ] && [ $framework_upgraded = 1 ]; then
    echo "No uImage for upgrading, skip"
    exit 2
fi

if [ "`tar -tf $2 $c_img`" = "$c_img" ]; then
    custconf_upgrade=1
fi


echo "Updating image $img_mtd_num with file $2"

# Find out kernel/rootfs mtd partition according to image destination
k_mtd="/dev/"`cat /proc/mtd | grep \"k"$img_mtd_num"\" | sed 's/:.*$//g'`
r_mtd="/dev/"`cat /proc/mtd | grep \"r"$img_mtd_num"\" | sed 's/:.*$//g'`
c_mtd="/dev/"`cat /proc/mtd | grep \"framework"$(($img_mtd_num+1))"\" | sed 's/:.*$//g'`
k_mtd_size=`cat /proc/mtd | grep \"k"$img_mtd_num"\" | sed 's/^.*: //g' | sed 's/ .*$//g'`
r_mtd_size=`cat /proc/mtd | grep \"r"$img_mtd_num"\" | sed 's/^.*: //g' | sed 's/ .*$//g'`
c_mtd_size=`cat /proc/mtd | grep \"framework"$(($img_mtd_num+1))"\" | sed 's/^.*: //g' | sed 's/ .*$//g'`
echo "kernel image is located at $k_mtd"
echo "rootfs image is located at $r_mtd"
if [ $custconf_upgrade = 1 ]; then
    echo "custconf image is located at $c_mtd"
fi

if [ -f $skip_hwver_check ]; then
    echo "Skip HW_VER check!!"
else
    img_hw_ver=`tar -xf $2 $hw_ver_file -O`
    mib_hw_ver=`flash get HW_HWVER | sed s/HW_HWVER=//g`
    if [ "$img_hw_ver" = "skip" ]; then
        echo "skip HW_VER check!!"
    else
        echo "img_hw_ver=$img_hw_ver mib_hw_ver=$mib_hw_ver"
        if [ "$img_hw_ver" != "$mib_hw_ver" ]; then
            echo "HW_VER $img_hw_ver inconsistent, aborted image updating !"
            exit 1
        fi
    fi
fi

# Extract kernel image
tar -xf $2 $k_img -O | md5sum | sed 's/-/'$k_img'/g' > $md5_rt_result
# Check integrity
grep $k_img $md5_cmp > $md5_tmp
diff $md5_rt_result $md5_tmp

if [ $? != 0 ]; then
    echo "$k_img""md5_sum inconsistent, aborted image updating !"
    exit 1
fi

# Extract rootfs image
tar -xf $2 $r_img -O | md5sum | sed 's/-/'$r_img'/g' > $md5_rt_result
# Check integrity
grep $r_img $md5_cmp > $md5_tmp
diff $md5_rt_result $md5_tmp

if [ $? != 0 ]; then
    # rm $r_img
    echo "$r_img""md5_sum inconsistent, aborted image updating !"
    exit 1
fi

if [ $custconf_upgrade = 1 ]; then
# Extract rootfs image
    tar -xf $2 $c_img -O | md5sum | sed 's/-/'$c_img'/g' > $md5_rt_result
# Check integrity
    grep $c_img $md5_cmp > $md5_tmp
    diff $md5_rt_result $md5_tmp

    if [ $? != 0 ]; then
        echo "$c_img""md5_sum inconsistent, aborted image updating !"
        exit 1
    fi
fi

if [ $custconf_upgrade = 1 ]; then
    echo "Integrity of $k_img, $r_img & $c_img is okay."
else
    echo "Integrity of $k_img & $r_img is okay."
fi

# Check upgrade firmware's version with current firmware version
tar -xf $2 $img_ver
if [ $? != 0 ]; then
	echo "1" > /var/firmware_upgrade_status
	echo "Firmware version incorrect: no fwu_ver in img.tar !"
	exit 1
fi

cat $img_ver > $new_fw_ver
cat /etc/version > $cur_fw_ver

cat $new_fw_ver | grep -n '^V[0-9]*.[0-9]*.[0-9]*-[0-9][0-9]*'
if [ $? != 0 ]; then
	echo "1" > /var/firmware_upgrade_status
	echo "Firmware version incorrect: `cat $new_fw_ver` !"
	exit 1
fi

echo "Try to upgrade firmware version from `cat $cur_fw_ver`"
echo "                                  to `cat $new_fw_ver`"

if [ "`cat $new_fw_ver`" == "`cat $cur_fw_ver`" ]; then
	echo "4" > /var/firmware_upgrade_status
    echo "Current firmware version already is `cat $cur_fw_ver` !"
    exit 1
fi

echo "Firware version check okay."

flash set CWMP_CONFIGURABLE 7
flash set DEVICE_TYPE 1
#flash set HW_CWMP_PRODUCTCLASS "SY-GPON-2010-WADONT"
#flash set FORCE_DEFAULT_PWD_CHANGE 5
#flash set WEB_VERIFICATION_CODE_ENABLE 1
#flash set WEB_LANGUAGE_SETTING_MODE 1
#flash set USER_LEVEL_ENABLE 0
#flash set SW_NEW_EXT_FUNC_01 1
flash set IPHOST2_SRV 0
flash set IPHOST_SRV 0
#flash set HW_SW_FOR_CUSTOMER 500
flash set HW_WAN_MAC_METHOD 1
flash set HW_WLAN1_REG_DOMAIN 1
flash set HW_WLAN0_REG_DOMAIN 1
flash set WLAN1_CHANNELWIDTH 1
flash set CF_PASS_DECRY_ENABLE 1
nv setenv sw_update_state 1

killall cwmpClient
killall spppd
killall vsntp
killall dnsmasq
killall udhcpd
killall udhcpc
killall monitord
killall igmpproxy
killall igmp_pid
killall cwmp
killall wscd-wlan0
killall mini_upnpd
killall miniupnpd
killall smbd
killall upnpmd_cp
killall iwcontrol
killall loopback
killall ftd
killall dropbear
killall boa
killall timely_function
killall wdg
killall ftpd
killall tftpd
killall nmbd
killall ecmh
killall telnetd
killall voip_gwdt
killall mainctrl
killall dhcrelay
killall routed
killall slogd
killall klogd
killall tcpdump
killall systemd
killall pondetect
killall configd
killall eponoamd
killall omci_app

sleep 2
echo 1 > /proc/sys/vm/drop_caches
sleep 2

ps
cat /proc/meminfo

tar -xf $2 $k_img
string="`ls -l | grep $k_img`"
mtd_size_dec="`printf %d 0x$k_mtd_size`"
img_size_dec="`expr substr "$string" 34 100 | sed 's/^ *//g' | sed 's/ .*$//g'`"
expr "$img_size_dec" \< "$mtd_size_dec" > /dev/null
if [ $? != 0 ]; then
	echo "uImage size too big($img_size_dec) !"
	echo "3" > /var/firmware_upgrade_status
	exit 1
fi
tar -xf $2 $r_img
string="`ls -l | grep $r_img`"
mtd_size_dec="`printf %d 0x$r_mtd_size`"
img_size_dec="`expr substr "$string" 34 100 | sed 's/^ *//g' | sed 's/ .*$//g'`"
expr "$img_size_dec" \< "$mtd_size_dec" > /dev/null
if [ $? != 0 ]; then
	echo "rootfs size too big($img_size_dec) !"
	echo "3" > /var/firmware_upgrade_status
	exit 1
fi

if [ $custconf_upgrade = 1 ]; then
	tar -xf $2 $c_img
	string="`ls -l | grep $c_img`"
	mtd_size_dec="`printf %d 0x$c_mtd_size`"
	img_size_dec="`expr substr "$string" 34 100 | sed 's/^ *//g' | sed 's/ .*$//g'`"
	expr "$img_size_dec" \< "$mtd_size_dec" > /dev/null
	if [ $? != 0 ]; then
		echo "custconf size too big($img_size_dec) !"
		echo "3" > /var/firmware_upgrade_status
		exit 1
	fi
fi

echo "nv setenv sw_tryactive $img_mtd_num"
nv setenv sw_tryactive $img_mtd_num

echo "Both uImage and rootfs size check okay, start updating ..."
# Erase kernel partition 
echo "Erasing $k_mtd..."
flash_eraseall $k_mtd
# Write kernel partition
echo "Writing $k_img to $k_mtd"
cp $k_img $k_mtd

rm $k_img

# Erase rootfs partition 
echo "Erasing $r_mtd..."
flash_eraseall $r_mtd
# Write rootfs partition
echo "Writing $r_img to $r_mtd"
cp $r_img $r_mtd

rm $r_img

if [ $custconf_upgrade = 1 ]; then
	# Erase rootfs partition 
	echo "Erasing $c_mtd..."
	flash_eraseall $c_mtd
	# Write rootfs partition
	echo "Writing $c_img to $c_mtd"
	cp $c_img $c_mtd
fi

sleep 2
cat $new_fw_ver | grep CST
if [ $? = 0 ]; then
	echo `cat $new_fw_ver` | sed 's/ *--.*$//g' > $env_sw_ver
else
	cat $new_fw_ver > $env_sw_ver
fi
# Write image version information 
nv setenv sw_version"$img_mtd_num" "`cat $env_sw_ver`"

# Clean up temporary files
rm -f $md5_cmp $md5_tmp $md5_rt_result $img_ver $new_fw_ver $cur_fw_ver $env_sw_ver $k_img $r_img $c_img $2

# Post processing (for future extension consideration)

reboot -f

echo "Successfully updated image $img_mtd_num!!"

