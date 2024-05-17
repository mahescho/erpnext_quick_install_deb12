# Unattended Install Script for ERPNext
Unattended script for ERPNext installation (Supports Versions 13, 14 and 15).

This is a no-interactive script for installing ERPNext Versions 13, 14 and 15. You can set up either development or production with very minimal interaction.

# How To:
To use this script, follow these steps:

# Before Installation

Make sure you install the latest package versions by updating system packages if you are running this script on a fresh Debian machine. Login as Root and do:

```
apt update && sudo apt -y full-upgrade
```
and then reboot your machine 

Cereate a user, e.g: frappe and grannt sudo permittions to this user:

```
apt install sudo -y
addiser frappe
usermod -aG sudo frappe
```

Login as the new user or su to the new user:

```
su - frappe
```

and start the installation.

# Installation:

1. Clone the Repo:
```
git clone https://github.com/mahescho/erpnext_quick_install_deb12.git
```
2. navigate to the folder:
```
cd erpnext_quick_install_deb12
```
3. Make the script executable
```
sudo chmod +x erpnext_install.sh
```
4. Run the script:
```
./erpnext_install.sh
```
# Compatibility

Debian 12

# NOTE:

Visit https://github.com/gavindsouza/awesome-frappe to learn about other apps you can install.

If you encounter spawn error on socketio when running bench restart, run the following commands:

```
bench setup socketio
bench setup supervisor
bench setup redis
sudo supervisorctl reload
```
This will fix the spawn error and all services will restart successfully.
