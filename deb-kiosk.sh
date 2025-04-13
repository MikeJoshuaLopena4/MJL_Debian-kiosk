#!/bin/bash

# Exit on error
set -e

echo "Updating package list..."
apt-get update

echo "Installing required software..."
apt-get install -y \
    unclutter \
    xorg \
    chromium \
    openbox \
    lightdm \
    locales

# Create 'kiosk' group
echo "Ensuring 'kiosk' group exists..."
groupadd -f kiosk

# Create kiosk user if it doesn't exist
echo "Creating 'kiosk' user..."
id -u kiosk &>/dev/null || useradd -m kiosk -g kiosk -s /bin/bash

# Create necessary directories
echo "Setting up directories..."
mkdir -p /home/kiosk/.config/openbox

# Set correct ownership
echo "Setting permissions for 'kiosk'..."
chown -R kiosk:kiosk /home/kiosk

# Configure Xorg
echo "Configuring Xorg..."
cat > /etc/X11/xorg.conf << EOF
Section "ServerFlags"
    Option "DontVTSwitch" "false"
EndSection
EOF

# Configure LightDM
echo "Configuring LightDM..."
if [ -e "/etc/lightdm/lightdm.conf" ]; then
    mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
fi
cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
xserver-command=X -nolisten tcp
autologin-user=kiosk
autologin-session=openbox
EOF

# Create autostart script for Openbox
echo "Creating autostart script..."
if [ -e "/home/kiosk/.config/openbox/autostart" ]; then
    mv /home/kiosk/.config/openbox/autostart /home/kiosk/.config/openbox/autostart.backup
fi
cat > /home/kiosk/.config/openbox/autostart << EOF
#!/bin/bash

export KIOSK_URL="https://www.google.com/"

#unclutter -idle 0.1 -grab -root &

while true; do
    xrandr --auto
    chromium \
        --noerrdialogs \
        --no-memcheck \
        --no-first-run \
        --start-maximized \
        --disable \
        --disable-translate \
        --disable-infobars \
        --disable-suggestions-service \
        --disable-save-password-bubble \
        --disable-session-crashed-bubble \
        --incognito \
        --kiosk "\$KIOSK_URL"
    sleep 5
done &
EOF

# Set execution permissions
chmod +x /home/kiosk/.config/openbox/autostart
ls /usr/sbin/groupadd
export PATH=$PATH:/usr/sbin
groupadd -f kiosk
chown kiosk:kiosk /home/kiosk/.config/openbox/autostart

# Allow kiosk user to access X server
echo "Granting X server access to 'kiosk'..."
xhost +SI:localuser:kiosk

echo "Installation complete! Reboot to apply changes."
