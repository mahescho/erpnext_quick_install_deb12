#!/usr/bin/env bash

# # Setting error handler
# handle_error() {
#     local line=$1
#     local exit_code=$?
#     echo "An error occurred on line $line with exit status $exit_code"
#     exit $exit_code
# }

# trap 'handle_error $LINENO' ERR
# set -e

# Retrieve server IP
server_ip=$(hostname -I | awk '{print $1}')

# Setting up colors for echo commands
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Checking Supported OS and distribution
SUPPORTED_DISTRIBUTIONS=("Debian")
SUPPORTED_VERSIONS=("12")

check_os() {
    local os_name=$(lsb_release -is)
    local os_version=$(lsb_release -rs)
    local os_supported=false
    local version_supported=false

    for i in "${SUPPORTED_DISTRIBUTIONS[@]}"; do
        if [[ "$i" = "$os_name" ]]; then
            os_supported=true
            break
        fi
    done

    for i in "${SUPPORTED_VERSIONS[@]}"; do
        if [[ "$i" = "$os_version" ]]; then
            version_supported=true
            break
        fi
    done

    if [[ "$os_supported" = false ]] || [[ "$version_supported" = false ]]; then
        echo -e "${RED}This script is not compatible with your operating system or its version.${NC}"
        exit 1
    fi
}

check_os


# Detect the platform (similar to $OSTYPE)
OS="`uname`"
case $OS in
  'Linux')
    OS='Linux'
    if [ -f /etc/redhat-release ] ; then
      DISTRO='CentOS'
    elif [ -f /etc/debian_version ] ; then
      if [ "$(lsb_release -si)" == "Ubuntu" ]; then
        DISTRO='Ubuntu'
      else
        DISTRO='Debian'
      fi
    fi
    ;;
  *) ;;
esac


ask_twice() {
    local prompt="$1"
    local secret="$2"
    local val1 val2

    while true; do
        if [ "$secret" = "true" ]; then

            read -rsp "$prompt: " val1

            echo >&2
        else
            read -rp "$prompt: " val1
            echo >&2
        fi
        
        if [ "$secret" = "true" ]; then
            read -rsp "Confirm password: " val2
            echo >&2
        else
            read -rp "Confirm password: " val2
            echo >&2
        fi

        if [ "$val1" = "$val2" ]; then
            printf "${GREEN}Password confirmed${NC}" >&2
            echo "$val1"
            break
        else
            printf "${RED}Inputs do not match. Please try again${NC}\n" >&2
            echo -e "\n"
        fi
    done
}
echo -e "${LIGHT_BLUE}Welcome to the ERPNext Installer...${NC}"
echo -e "\n"
sleep 3

# Prompt user for version selection with a preliminary message
echo -e "${YELLOW}Please enter the number of the corresponding ERPNext version you wish to install:${NC}"

versions=("Version 13" "Version 14" "Version 15")
select version_choice in "${versions[@]}"; do
    case $REPLY in
        1) bench_version="version-13"; break;;
        2) bench_version="version-14"; break;;
        3) bench_version="version-15"; break;;
        *) echo -e "${RED}Invalid option. Please select a valid version.${NC}";;
    esac
done

#
# ask for parameters
#

# Confirm the version choice with the user
echo -e "${GREEN}You have selected $version_choice for installation.${NC}"
echo -e "${LIGHT_BLUE}Do you wish to continue? (yes/no)${NC}"
read -p "Response: " continue_install
continue_install=$(echo "$continue_install" | tr '[:upper:]' '[:lower:]')

while [[ "$continue_install" != "yes" && "$continue_install" != "y" && "$continue_install" != "no" && "$continue_install" != "n" ]]; do
    echo -e "${RED}Invalid response. Please answer with 'yes' or 'no'.${NC}"
    echo -e "${LIGHT_BLUE}Do you wish to continue with the installation of $version_choice? (yes/no)${NC}"
    read -p "Response: " continue_install
    continue_install=$(echo "$continue_install" | tr '[:upper:]' '[:lower:]')
done

if [[ "$continue_install" == "no" || "$continue_install" == "n" ]]; then
    # If user chooses 'no', loop back to version selection
    continue
else
    echo -e "${GREEN}Proceeding with the installation of $version_choice.${NC}"

fi
sleep 1

# Prompt user for site name
read -p "Enter the site name (If you wish to install SSL later, please enter a FQDN, default: $(hostname -f)): " sn
if [ -z "$sn" ]; then
    site_name=$(hostname -f)
else
    site_name=$sn
fi
sleep 1
adminpasswrd=$(ask_twice "Enter the ERPnext Administrator password you want to" "true")
echo -e "\n"

echo -e "${LIGHT_BLUE}Would you like to do a production install? (yes/no)${NC}"
read -p "Response: " continue_prod
continue_prod=$(echo "$continue_prod" | tr '[:upper:]' '[:lower:]')

#Next let's set some important parameters.
#We will need your required SQL root passwords
echo -e "We will need your required SQL root password"
sleep 1
sqlpasswrd=$(ask_twice "What is your required SQL root password" "true")
sleep 1
echo -e "\n"

#
# Run the installation
#

# Check OS and version compatibility for all versions
check_os
#First Let's take you home
cd $(sudo -u $USER echo $HOME)

#Now let's make sure your instance has the most updated packages
echo -e "${YELLOW}Updating system packages...${NC}"
sleep 2
sudo apt update
sudo apt full-upgrade -y
echo -e "${GREEN}System packages updated.${NC}"
sleep 2

#Now let's install a couple of requirements: git, curl and pip
echo -e "${YELLOW}Installing preliminary package requirements${NC}"
sleep 3

sudo apt install sudo curl git python3-dev python3-setuptools python3-pip python3-distutils \
 python3-venv software-properties-common mariadb-server mariadb-client redis-server xvfb \
 libfontconfig wkhtmltopdf default-libmysqlclient-dev npm supervisor \
 fontconfig xvfb libfontconfig xfonts-base xfonts-75dpi libxrender1 -y

# Use a hidden marker file to determine if this section of the script has run before.
MARKER_FILE=~/.mysql_configured.marker

if [ ! -f "$MARKER_FILE" ]; then
    #Now we'll go through the required settings of the mysql_secure_installation...
    echo -e ${YELLOW}"Now we'll go ahead to apply MariaDB security settings...${NC}"
    sleep 2

    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
    sudo mysql -u root -p"$sqlpasswrd" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
    sudo mysql -u root -p"$sqlpasswrd" -e "DELETE FROM mysql.user WHERE User='';"
    sudo mysql -u root -p"$sqlpasswrd" -e "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    sudo mysql -u root -p"$sqlpasswrd" -e "FLUSH PRIVILEGES;"

    echo -e "${YELLOW}...And add some settings to /etc/mysql/my.cnf:${NC}"
    sleep 2

    sudo bash -c 'cat << EOF >> /etc/mysql/my.cnf
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOF'

    sudo service mysql restart

    # Create the hidden marker file to indicate this section of the script has run.
    touch "$MARKER_FILE"
    echo -e "${GREEN}MariaDB settings done!${NC}"
    echo -e "\n"
    sleep 1
fi


#Install NVM, Node, npm and yarn
echo -e ${YELLOW}"Now to install NVM, Node, npm and yarn${NC}"
sleep 2
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash

# Add environment variables to .profile
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.profile
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.profile
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> ~/.profile

# Source .profile to load the new environment variables in the current session
source ~/.profile

# Conditional Node.js installation based on the version of ERPNext selected
if [[ "$bench_version" == "version-15" ]]; then
    nvm install 18
    node_version="18"
else
    nvm install 16
    node_version="16"
fi

sudo npm install -g yarn
echo -e "${GREEN}Package installation complete!${NC}"
sleep 2


#Install bench
echo -e "${YELLOW}Now let's install bench${NC}"
sleep 2
sudo rm -rf /usr/lib/python3.11/EXTERNALLY-MANAGED
sudo pip3 install frappe-bench

#Initiate bench in frappe-bench folder, but get a supervisor can't restart bench error...
echo -e "${YELLOW}Initialising bench in frappe-bench folder.${NC}" 
echo -e "${LIGHT_BLUE}If you get a restart failed, don't worry, we will resolve that later.${NC}"
bench init frappe-bench --version $bench_version --verbose --install-app erpnext --version $bench_version
echo -e "${GREEN}Bench installation complete!${NC}"
sleep 1

echo -e "${YELLOW}Now setting up your site. This might take a few minutes. Please wait...${NC}"
sleep 1
# Change directory to frappe-bench
cd frappe-bench && \

sudo chmod -R o+rx /home/$(echo $USER)

bench new-site $site_name --db-root-password $sqlpasswrd --admin-password $adminpasswrd --install-app erpnext

case "$continue_prod" in
    "yes" | "y")

    echo -e "${YELLOW}Installing packages and dependencies for Production...${NC}"
    sleep 2
    # Setup supervisor and nginx config
    yes | sudo bench setup production $USER && \
    echo -e "${YELLOW}Applying necessary permissions to supervisor...${NC}"
    sleep 1
    # Change ownership of supervisord.conf
    # Path to the supervisord.conf file
    FILE="/etc/supervisor/supervisord.conf"
    # Construct the search pattern with the current $USER environment variable
    SEARCH_PATTERN="chown=$USER:$USER"

    # Check if the pattern exists in the file
    if grep -q "$SEARCH_PATTERN" "$FILE"; then
        echo -e "${YELLOW}User ownership already exists for supervisord. Updating it...${NC}"
        # Replace the existing line with the new user ownership line
        sudo sed -i "/chown=.*/c $SEARCH_PATTERN" "$FILE"
    else
        echo -e "${YELLOW}User ownership does not exist for supervisor. Adding it...${NC}"
        # Insert the new user ownership line at a specific line number
        sudo sed -i "5a $SEARCH_PATTERN" "$FILE"
    fi

    # Restart supervisor
    sudo service supervisor restart && \

    # Setup production again to reflect the new site
    yes | sudo bench setup production $USER && \

    echo -e "${YELLOW}Enabling Scheduler...${NC}"
    sleep 1
    # Enable and resume the scheduler for the site
    bench --site $site_name scheduler enable && \
    bench --site $site_name scheduler resume && \
    if [[ "$bench_version" == "version-15" ]]; then
        echo -e "${YELLOW}Setting up Socketio, Redis and Supervisor...${NC}"
        sleep 1
        bench setup socketio
        yes | bench setup supervisor
        bench setup redis
        sudo supervisorctl reload
    fi
    echo -e "${YELLOW}Restarting bench to apply all changes and optimizing environment pernissions.${NC}"
    sleep 1


    #Now to make sure the environment is fully setup
    sudo chmod 755 /home/$(echo $USER)
    sleep 3
    printf "${GREEN}Production setup complete! "
    printf '\xF0\x9F\x8E\x86'
    printf "${NC}\n"
    sleep 3

    echo -e "${GREEN}--------------------------------------------------------------------------------"
    echo -e "Congratulations! You have successfully installed ERPNext $version_choice."
    echo -e "You can start using your new ERPNext installation by visiting https://$site_name"
    echo -e "(if you have enabled SSL and used a Fully Qualified Domain Name"
    echo -e "during installation) or http://$server_ip to begin."
    echo -e "Install additional apps as required. Visit https://docs.erpnext.com for Documentation."
    echo -e "Enjoy using ERPNext!"
    echo -e "--------------------------------------------------------------------------------${NC}"
        ;;
    *)

    echo -e "${YELLOW}Getting your site ready for development...${NC}"
    sleep 2
    source ~/.profile
    if [[ "$bench_version" == "version-15" ]]; then
        nvm alias default 18
    else
        nvm alias default 16
    fi
    bench use $site_name
    bench build
    echo -e "${GREEN}Done!"
    sleep 5

    echo -e "${GREEN}-----------------------------------------------------------------------------------------------"
    echo -e "Congratulations! You have successfully installed Frappe and ERPNext $version_choice Development Enviromment."
    echo -e "Start your instance by running bench start to start your server and visiting http://$server_ip:8000"
    echo -e "Install additional apps as required. Visit https://frappeframework.com for Developer Documentation."
    echo -e "Enjoy development with Frappe!"
    echo -e "-----------------------------------------------------------------------------------------------${NC}"
    ;;
esac
