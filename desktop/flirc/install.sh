#!/bin/bash
install_dir="/usr/local/bin/"
current_dir="$(pwd)"
wget 'http://apt.flirc.tv/arch/x86_64/flirc.latest.x86_64.tar.gz'
gzip -d flirc.latest.x86_64.tar.gz
tar -xf flirc.latest.x86_64.tar.gz
dpkg -s libhidapi-hidraw0 > /dev/null 2>&1
if [ $? = 0 ]; then
dpkg -s libqt5xmlpatterns5 > /dev/null 2>&1
elif [ $? = 0 ]; then
    cp $current_dir/Flirc*/Flirc $install_dir/ # copies binary.
    cp $current_dir/Flirc*/flirc_util $install_dir/ # copies binary.
    cp $current_dir/Flirc.png /usr/share/pixmaps/ # copies icon.
    cat > ~/.local/share/applications/Flirc.desktop << EOF # create desktop entry file.
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Terminal=false
Exec=/usr/local/bin/Flirc
Name=Flirc
Comment=Flirc Second Generation USB Receiver
Categories=Utility;
Icon=/usr/share/pixmaps/Flirc.png
EOF
    chmod u+x ~/.local/share/applications/Flirc.desktop # give execution permission to desktop entry file.
    cat > /etc/udev/rules.d/99-flirc.rules << EOF # create rules file.
# Flirc Devices

# Bootloader
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="20a0", ATTR{idProduct}=="0000", MODE="0666"
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="20a0", ATTR{idProduct}=="0002", MODE="0666"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="0005", MODE="0666"

# Flirc Application
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="20a0", ATTR{idProduct}=="0001", MODE="0666"
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="20a0", ATTR{idProduct}=="0004", MODE="0666"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="0006", MODE="0666"
EOF
else
    echo -e "Error: Missing Dependencies."
fi