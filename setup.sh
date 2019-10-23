#!/usr/bin/env bash
pushd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null
RPI_SETUP_DIR="$( pwd )"

# Disable the built-in audio output so there is only one audio
# device in the system
sudo sed -i -e 's/dtparam=audio=on/#dtparam=audio=on/' /boot/config.txt

# Enable the i2s device tree
sudo sed -i -e 's/#dtparam=i2s=on/dtparam=i2s=on/' /boot/config.txt

echo "Installing Raspberry Pi kernel headers"
sudo apt-get install -y raspberrypi-kernel-headers

if [ $# -eq 1 ] && [ $1 = "codama" ] ; then
    echo "Installing libncurses5"
    sudo apt-get install -y libncurses5
fi

# Build loader and insert it into the kernel
if [ $# -ge 1 ] && [ $1 = "xvf3510" ] ; then
    pushd $RPI_SETUP_DIR/loader/i2s_master > /dev/null
    make i2s_master
else
    if [ "`uname -m`" = "armv6l" ] ; then
        sed -i 's/3f203000\.i2s/20203000\.i2s/' loader/i2s_slave/loader.c
    else
        sed -i 's/20203000\.i2s/3f203000\.i2s/' loader/i2s_slave/loader.c
    fi
    pushd $RPI_SETUP_DIR/loader/i2s_slave > /dev/null
    make i2s_slave
fi
popd > /dev/null


# Move existing files to back up
if [ -e ~/.asoundrc ] ; then
    chmod a+w ~/.asoundrc
    cp ~/.asoundrc ~/.asoundrc.bak
fi
if [ -e /usr/share/alsa/pulse-alsa.conf ] ; then
    sudo mv /usr/share/alsa/pulse-alsa.conf  /usr/share/alsa/pulse-alsa.conf.bak
    sudo mv ~/.config/lxpanel/LXDE-pi/panels/panel ~/.config/lxpanel/LXDE-pi/panels/panel.bak
fi
if [ -e ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-mixer.xml ] ; then
  cp ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-mixer.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-mixer.xml.bak
fi

# Check args for asoundrc selection. Default to VF Stereo.
if [ $# -eq 1 ] && [ $1 = "codama" ] ; then
    cp $RPI_SETUP_DIR/resources/asoundrc_vf_codama ~/.asoundrc
    sudo cp $RPI_SETUP_DIR/resources/asoundrc_vf_codama /root/.asoundrc
elif [ $# -eq 1 ] && [ $1 = "vocalfusion" ] ; then
    cp $RPI_SETUP_DIR/resources/asoundrc_vf ~/.asoundrc
elif [ $# -ge 1 ] && [ $1 = "xvf3510" ] ; then
    cp $RPI_SETUP_DIR/resources/asoundrc_vf_xvf3510 ~/.asoundrc
else
    cp $RPI_SETUP_DIR/resources/asoundrc_vf_stereo ~/.asoundrc
fi

cp $RPI_SETUP_DIR/resources/panel ~/.config/lxpanel/LXDE-pi/panels/panel
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml/
cp $RPI_SETUP_DIR/resources/xfce4-mixer.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-mixer.xml
chmod 700 ~/.config/xfce4/xfconf/xfce-perchannel-xml

# Make the asoundrc file read-only otherwise lxpanel rewrites it
# as it doesn't support anything but a hardware type device
chmod a-w ~/.asoundrc
if [ $# -eq 1 ] && [ $1 = "codama" ] ; then
    sudo chmod a-w /root/.asoundrc
fi


# Apply changes
sudo /etc/init.d/alsa-utils restart


# Create the script to run after each reboot and make the soundcard available
i2s_driver_script=$RPI_SETUP_DIR/resources/load_i2s_driver.sh
rm -f $i2s_driver_script
if [ $# -eq 1 ] && [ $1 = "codama" ] ; then
    sudo cp $RPI_SETUP_DIR/loader/i2s_slave/loader.ko /lib/modules/`uname -r`/kernel/sound/drivers/
    if ! grep -q "loader" /etc/modules-load.d/modules.conf; then
        sudo sed -i -e '$ a loader' /etc/modules-load.d/modules.conf
    fi
else
echo "cd $RPI_SETUP_DIR"                          >> $i2s_driver_script
if [ $# -ge 1 ] && [ $1 = "xvf3510" ] ; then
	echo "sudo insmod loader/i2s_master/loader.ko"               >> $i2s_driver_script
else
	echo "sudo insmod loader/i2s_slave/loader.ko"               >> $i2s_driver_script
fi
fi


if [ $# -ge 1 ] && [ $1 = "xvf3510" ] ; then
    pushd $RPI_SETUP_DIR/resources/clk_dac_setup/ > /dev/null
    make
    popd > /dev/null
    i2s_clk_dac_script=$RPI_SETUP_DIR/resources/init_i2s_clks.sh
    rm -f $i2s_clk_dac_script
    echo "sudo raspi-config nonint do_i2c 1"          >> $i2s_clk_dac_script
    echo "sudo raspi-config nonint do_i2c 0"          >> $i2s_clk_dac_script
    echo "sudo $RPI_SETUP_DIR/resources/clk_dac_setup/setup_mclk"  >> $i2s_clk_dac_script
    echo "sudo $RPI_SETUP_DIR/resources/clk_dac_setup/setup_bclk"  >> $i2s_clk_dac_script
    echo "python $RPI_SETUP_DIR/resources/clk_dac_setup/setup_dac.py"   >> $i2s_clk_dac_script
    echo "python $RPI_SETUP_DIR/resources/clk_dac_setup/reset_xvf3510.py"   >> $i2s_clk_dac_script
fi

if [ $# -ge 1 ] && [ $1 = "xvf3510" ] ; then
    sudo apt-get install -y audacity
    audacity_script=$RPI_SETUP_DIR/resources/run_audacity.sh
    rm -f $audacity_script
    echo "#!/usr/bin/env bash" >> $audacity_script
    echo "/usr/bin/audacity &" >> $audacity_script
    echo "sleep 5" >> $audacity_script
    echo "sudo $RPI_SETUP_DIR/resources/clk_dac_setup/setup_bclk >> /dev/null" >> $audacity_script
    sudo chmod +x $audacity_script
    sudo mv $audacity_script /usr/local/bin/audacity
fi

# Configure the I2C - disable the default built-in driver
sudo sed -i -e 's/#\?dtparam=i2c_arm=on/dtparam=i2c_arm=off/' /boot/config.txt
if ! grep -q "i2c-bcm2708" /etc/modules-load.d/modules.conf; then
  sudo sh -c 'echo i2c-bcm2708 >> /etc/modules-load.d/modules.conf'
fi
if ! grep -q "i2c-dev" /etc/modules-load.d/modules.conf; then
  sudo sh -c 'echo i2c-dev >> /etc/modules-load.d/modules.conf'
fi
if ! grep -q "options i2c-bcm2708 combined=1" /etc/modprobe.d/i2c.conf; then
  sudo sh -c 'echo "options i2c-bcm2708 combined=1" >> /etc/modprobe.d/i2c.conf'
fi


# Build a new I2C driver
if [ $# -eq 1 ] && [ $1 != "codama" ] ; then
    pushd $RPI_SETUP_DIR/i2c-gpio-param > /dev/null
    make || exit $?
    popd > /dev/null
else
    if [ "`uname -r | cut -d. -f1-2`" != "4.19" ] ; then
        pushd $RPI_SETUP_DIR/i2c-gpio-param > /dev/null
        make || exit $?
        popd > /dev/null
    fi
fi

# Create script to insert module into the kernel
i2c_driver_script=$RPI_SETUP_DIR/resources/load_i2c_gpio_driver.sh
rm -f $i2c_driver_script
if [ $# -eq 1 ] && [ $1 = "codama" ] ; then
    if [ "`uname -r | cut -d. -f1-2`" = "4.19" ] ; then
        sudo depmod -ae
        if ! grep -q "dtoverlay=i2c-gpio,bus=3,i2c_gpio_sda=2,i2c_gpio_scl=3,i2c_gpio_delay_us=5,timeout-ms=100" /boot/config.txt; then
            sudo sed -i -e '$ a dtoverlay=i2c-gpio,bus=3,i2c_gpio_sda=2,i2c_gpio_scl=3,i2c_gpio_delay_us=5,timeout-ms=100' /boot/config.txt
        fi
    else
        sudo cp $RPI_SETUP_DIR/i2c-gpio-param/i2c-gpio-param.ko /lib/modules/`uname -r`/kernel/drivers/i2c/
        sudo depmod -ae
        if ! grep -q "i2c-gpio-param" /etc/modules-load.d/modules.conf; then
            sudo sed -i -e '$ a i2c-gpio-param' /etc/modules-load.d/modules.conf
        fi
        if ! grep -q "options i2c-gpio-param busid=1 sda=2 scl=3 udelay=5 timeout=100 sda_od=0 scl_od=0 scl_oo=0" /etc/modprobe.d/i2c.conf; then
            sudo sed -i -e '$ a options i2c-gpio-param busid=1 sda=2 scl=3 udelay=5 timeout=100 sda_od=0 scl_od=0 scl_oo=0' /etc/modprobe.d/i2c.conf
        fi
    fi
    sudo sed -i -e '$i \# Run Alsa at startup so that alsamixer configures' /etc/rc.local
    sudo sed -i -e '$i \arecord -d 1 > /dev/null 2>&1' /etc/rc.local
    sudo sed -i -e '$i \aplay dummy > /dev/null 2>&1' /etc/rc.local
else
    echo "cd $RPI_SETUP_DIR/i2c-gpio-param"                                            >> $i2c_driver_script
    echo "# Load the i2c bit banged driver"                                            >> $i2c_driver_script
    echo "sudo insmod i2c-gpio-param.ko"                                               >> $i2c_driver_script
    echo "# Instantiate a driver at bus id=1 on same pins as hw i2c with 1sec timeout" >> $i2c_driver_script
    echo "sudo sh -c 'echo "1 2 3 5 100 0 0 0" > /sys/class/i2c-gpio/add_bus'"         >> $i2c_driver_script
    echo "# Remove the default i2c-gpio instance"                                      >> $i2c_driver_script
    echo "sudo sh -c 'echo 7 > /sys/class/i2c-gpio/remove_bus'"                        >> $i2c_driver_script

    echo "# Run Alsa at startup so that alsamixer configures"                          >> $i2c_driver_script
    echo "arecord -d 1 > /dev/null 2>&1"                                               >> $i2c_driver_script
    echo "aplay dummy > /dev/null 2>&1"                                                >> $i2c_driver_script
fi


# Setup the crontab to restart I2S/I2C at reboot
if [ $# -eq 1 ] && [ $1 = "codama" ] ; then
  echo "non generate crontab"
else
  rm -f $RPI_SETUP_DIR/resources/crontab
  echo "@reboot sh $i2s_driver_script"  >> $RPI_SETUP_DIR/resources/crontab
  echo "@reboot sh $i2c_driver_script"  >> $RPI_SETUP_DIR/resources/crontab
  if [ $# -ge 1 ] && [ $1 = "xvf3510" ] ; then
      echo "@reboot sh $i2s_clk_dac_script" >> $RPI_SETUP_DIR/resources/crontab
  fi
  crontab $RPI_SETUP_DIR/resources/crontab
fi

echo "To enable I2S, this Raspberry Pi must be rebooted."

popd > /dev/null
