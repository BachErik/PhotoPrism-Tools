#!/bin/bash

# Install dependencies needed to run the installer
sudo apt update
sudo apt dist-upgrade

sudo apt-get install xterm -y
sudo apt-get install whiptail -y
sudo apt-get install wget -y
eval `resize`

# Some variables
# Determine terminal size
LINES=$(tput lines)
COLUMNS=$(tput cols)
MENU_HEIGHT=$((LINES - 8))
DIMS="$LINES $COLUMNS $MENU_HEIGHT"
SIZE="$LINES $COLUMNS"

TITLE="PhotoPrism installer by BachErik"
MariaDB=false
MariaDB_CONFIG_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
MariaDB_PORT=3306
MariaDB_NAME="photoprism"
MariaDB_USER="photoprism"
MariaDB_PASSWORD="photoprism"

# Ports
PhotoPrism_Port=2342


mainMenu(){
    OPTIONS=("install" "Starts the installer" "update" "Update PhotoPrism" "Help" "view helpful Informations" "About" "" "Quit" "Quit the installer aka close it!")

    CHOICE=$(whiptail --title "$TITLE" --menu "" $DIMS "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    case $CHOICE in
        install)
            install
            firewall
            echo "Successfully installed on your system"
            ;;
        update)
            update
            ;;
        Help)
            help
            ;;
        About)
            about
            ;;
        Quit)
            quit
            ;;
        *)
            quit
            ;;
    esac
}

install(){
    echo "Starting the install process"
    CHOICES=$(whiptail --title "$TITLE - Optional packages" --checklist \
    "Optional packages allow features such as better extraction of metadata and RAW image conversion. Which optional packages should be installed?" $DIMS \
    "1" "ffmpeg" ON \
    "2" "exiftool" ON \
    "3" "darktable" ON \
    "4" "libpng-dev" ON \
    "5" "libjpeg-dev" ON \
    "6" "libtiff-dev" ON \
    "7" "imagemagick" ON 3>&1 1>&2 2>&3)
    for choice in $CHOICES
    do
        case $choice in
        '"1"')
            sudo apt install ffmpeg -y
            ;;
        '"2"')
            sudo apt install exiftool -y
            ;;
        '"3"')
            sudo apt install darktable -y
            ;;
        '"4"')
            sudo apt install libpng-dev -y
            ;;
        '"5"')
            sudo apt install libjpeg-dev -y
            ;;
        '"6"')
            sudo apt install libtiff-dev -y
            ;;
        '"7"')
            sudo apt install imagemagick -y
            ;;
        esac
    done
    OPTIONS=("MariaDB" "(recommended)" "SQLite" "(PhotoPrism's default)")

    CHOICE=$(whiptail --title "$TITLE - Database" --menu "" $DIMS "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    case $CHOICE in
        MariaDB)
            MariaDB=true
            echo "MariaDB was choosed"
            mariaDB
            ;;
        SQLite)
            MariaDB=false
            echo "SQLite was choosed"
            ;;
        *)
            quit
            ;;
    esac

    wget https://dl.photoprism.app/pkg/linux/amd64.tar.gz
    sudo mkdir /opt/photoprism
    sudo tar xzf amd64.tar.gz -C /opt/photoprism/
    rm amd64.tar.gz

    PHOTOPRISM_VERSION=$(/opt/photoprism/bin/photoprism -v)
    whiptail --title "$TITLE - Success" --msgbox "PhotoPrism version: $PHOTOPRISM_VERSION" $SIZE

    sudo useradd --system photoprism
    sudo mkdir /var/lib/photoprism
    sudo chown -R photoprism:photoprism /var/lib/photoprism /opt/photoprism
    cd /var/lib/photoprism

    PHOTOPRISM_ADMIN_PASSWORD=$(whiptail --passwordbox "Enter the admin password for PhotoPrism" --title "$TITLE - Admin Password for PhotoPrism" $SIZE 3>&1 1>&2 2>&3)

    sudo echo "# Initial password for the admin user" > .env
    sudo echo "PHOTOPRISM_AUTH_MODE="password"" >> .env
    sudo echo "PHOTOPRISM_ADMIN_PASSWORD=$PHOTOPRISM_ADMIN_PASSWORD" >> .env
    sudo echo "" >> .env
    sudo echo "# PhotoPrism storage directories" >> .env
    sudo echo "PHOTOPRISM_STORAGE_PATH="/var/lib/photoprism"" >> .env
    sudo echo "PHOTOPRISM_ORIGINALS_PATH="/var/lib/photoprism/photos/Originals"" >> .env
    sudo echo "PHOTOPRISM_IMPORT_PATH="/var/lib/photoprism/photos/Import"" >> .env
    sudo echo "" >> .env
    if MariaDB == true; then
        sudo echo "# Uncomment below if using MariaDB/MySQL instead of SQLite (the default)" >> .env
        sudo echo "PHOTOPRISM_DATABASE_DRIVER="mysql"" >> .env
        sudo echo "PHOTOPRISM_DATABASE_SERVER="localhost:$MariaDB_PORT"" >> .env
        sudo echo "PHOTOPRISM_DATABASE_NAME="$MariaDB_NAME"" >> .env
        sudo echo "PHOTOPRISM_DATABASE_USER="$MariaDB_USER"" >> .env
        sudo echo "PHOTOPRISM_DATABASE_PASSWORD="$MariaDB_PASSWORD"" >> .env
    else
        sudo echo "# Uncomment below if using MariaDB/MySQL instead of SQLite (the default)" >> .env
        sudo echo "# PHOTOPRISM_DATABASE_DRIVER="mysql"" >> .env
        sudo echo "# PHOTOPRISM_DATABASE_SERVER="MYSQL_IP_HERE:PORT"" >> .env
        sudo echo "# PHOTOPRISM_DATABASE_NAME="DB_NAME"" >> .env
        sudo echo "# PHOTOPRISM_DATABASE_USER="USER_NAME"" >> .env
        sudo echo "# PHOTOPRISM_DATABASE_PASSWORD="PASSWORD"" >> .env
    fi

    sudo chown photoprism:photoprism .env
    sudo chmod 640 .env

    whiptail --title "$TITLE - Success" --msgbox "PhotoPrism was installed successfully" $SIZE
    whiptail --title "$TITLE - .env" --msgbox "Edit /var/lib/photoprism/.env if you want to change the settings, you can find the documentation here: https://docs.photoprism.app/getting-started/config-options/" $SIZE

    if whiptail --title "$TITLE - Enable systemctl" --yesno "Do you want to enable the service?" $SIZE; then
        sudo echo "Enabling service..."
        sudo echo "[Unit]" > /etc/systemd/system/photoprism.service
        sudo echo "Description=PhotoPrism service" >> /etc/systemd/system/photoprism.service
        sudo echo "After=network.target" >> /etc/systemd/system/photoprism.service
        sudo echo "" >> /etc/systemd/system/photoprism.service
        sudo echo "[Service]" >> /etc/systemd/system/photoprism.service
        sudo echo "Type=forking" >> /etc/systemd/system/photoprism.service
        sudo echo "User=photoprism" >> /etc/systemd/system/photoprism.service
        sudo echo "Group=photoprism" >> /etc/systemd/system/photoprism.service
        sudo echo "WorkingDirectory=/opt/photoprism" >> /etc/systemd/system/photoprism.service
        sudo echo "EnvironmentFile=/var/lib/photoprism/.env" >> /etc/systemd/system/photoprism.service
        sudo echo "ExecStart=/opt/photoprism/bin/photoprism up -d" >> /etc/systemd/system/photoprism.service
        sudo echo "ExecStop=/opt/photoprism/bin/photoprism down" >> /etc/systemd/system/photoprism.service
        sudo echo "" >> /etc/systemd/system/photoprism.service
        sudo echo "[Install]" >> /etc/systemd/system/photoprism.service
        sudo echo "WantedBy=multi-user.target" >> /etc/systemd/system/photoprism.service
        sudo sudo systemctl daemon-reload
        sudo sudo systemctl enable --now photoprism
    fi
    OPTIONS=("cron" "If you want to run your backgroundtasks with cron" "systemd" "If you want to run your backgroundtasks with systemd")

    CHOICE=$(whiptail --title "$TITLE" --menu "Do you want to run importing backgroundtasks?" $DIMS "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    case $CHOICE in
        cron)
            echo "Cron was choosed"
            sudo apt-get install cron -y
            sudo echo "0 * * * * photoprism export $(grep -v ^# /var/lib/photoprism/.env | xargs) && /opt/photoprism/bin/photoprism import >/dev/null 2>&1" > /etc/cron.d/photoprism
            ;;
        systemd)
            echo "Systemd was choosed"
            sudo echo "[Unit]" > /etc/systemd/system/photoprism-bg.service
            sudo echo "Description=PhotoPrism background tasks" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "After=network.target" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "[Service]" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "Type=oneshot" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "User=photoprism" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "Group=photoprism" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "WorkingDirectory=/opt/photoprism" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "EnvironmentFile=/var/lib/photoprism/.env" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "ExecStart=/opt/photoprism/bin/photoprism import" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "[Install]" >> /etc/systemd/system/photoprism-bg.service
            sudo echo "WantedBy=multi-user.target" >> /etc/systemd/system/photoprism-bg.service

            sudo echo "[Unit]" > /etc/systemd/system/photoprism-bg.timer
            sudo echo "Description=PhotoPrism background tasks" >> /etc/systemd/system/photoprism-bg.timer
            sudo echo "" >> /etc/systemd/system/photoprism-bg.timer
            sudo echo "[Timer]" >> /etc/systemd/system/photoprism-bg.timer
            sudo echo "OnCalendar=*:0:0" >> /etc/systemd/system/photoprism-bg.timer
            sudo echo "" >> /etc/systemd/system/photoprism-bg.timer
            sudo echo "[Install]" >> /etc/systemd/system/photoprism-bg.timer
            sudo echo "WantedBy=timers.target" >> /etc/systemd/system/photoprism-bg.timer

            sudo systemctl enable photoprism-bg.timer
            sudo systemctl start photoprism-bg.timer
            systemctl status photoprism-bg.service
            systemctl status photoprism-bg.timer
            systemctl list-timers photoprism-bg
            ;;
        no)
            echo "No backgroundtasks"
            ;;
        *)
            quit
            ;;
    esac
}

mariaDB(){
    sudo apt install -y mariadb-server
    mariadb-secure-installation

    USERNAME=$(whiptail --inputbox "What should be the username for your MariaDB" --title "$TITLE - Username for MariaDB" $SIZE 3>&1 1>&2 2>&3)
    PASSWORD=$(whiptail --passwordbox "What should be the password for your MariaDB" --title "$TITLE - Password for MariaDB" $SIZE 3>&1 1>&2 2>&3)
    DATABASE_NAME=$(whiptail --inputbox "What should be the database name for your MariaDB" --title "$TITLE - Database name for MariaDB" $SIZE 3>&1 1>&2 2>&3)

    echo "Creating database..."
    sudo mysql -u root -e "CREATE DATABASE $DATABASE_NAME;"
    sudo mysql -u root -e "CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '$PASSWORD';"
    sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$USERNAME'@'localhost' WITH GRANT OPTION;"
    sudo mysql -u root -e "FLUSH PRIVILEGES;"

    MariaDB_NAME=$DATABASE_NAME
    MariaDB_USER=$USERNAME
    MariaDB_PASSWORD=$PASSWORD
    MariaDB=true

    if whiptail --title "$TITLE - enable remote access for MariaDB" --yesno "Would you like to set up remote access to your MariaDB?" $SIZE; then
        echo "Enabling remote access for MariaDB..."
        if [ ! -f "$CONFIG_FILE" ]; then
            MariaDB_CONFIG_FILE=$(whiptail --inputbox "Where is your MariaDB config file?" --title "$TITLE - MariaDB config file" $SIZE 3>&1 1>&2 2>&3)
        fi
        cp $CONFIG_FILE "$CONFIG_FILE.bak"

        PORT=$(whiptail --inputbox "What should be the port for your MariaDB" --title "$TITLE - Port for MariaDB" $SIZE 3>&1 1>&2 2>&3)
        sed -i "/^port\s*=/c\port = $PORT" $CONFIG_FILE
        sed -i 's/^bind-address\s*= 127.0.0.1/bind-address = 0.0.0.0/' $MariaDB_CONFIG_FILE
        PORTS_TO_ALLOW+=($PORT)  # Add the MariaDB port to the list
        MariaDB_PORT=$PORT

        if ! grep -q "^port = $NEW_PORT" $CONFIG_FILE; then
            whiptail --title "$TITLE - Error" --msgbox "Port could not be changed in the configuration file. Check the file manually." $SIZE
        fi
    fi
    sudo systemctl restart mariadb
    sudo systemctl enable mariadb
}


firewall(){
    OPTIONS=("UFW" "Only the UFW firewall can be configured and installed automatically by the script." "other firewall" "If you want to use a different firewall.")

    CHOICE=$(whiptail --title "$TITLE - Firewall" --menu "Firewalls are essential for server security. There are various ways to configure the firewall." $DIMS "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    case $CHOICE in
        UFW)
            
            whiptail --title "$TITLE - disable all other Firewalls used" --msgbox "Make sure that you do not have another firewall running or that it will activate automatically." $SIZE
            

            OPTIONS=("new install" "Only the UFW firewall can be configured and installed automatically by the script." "already installed" "You already have UFW installed and possibly already configured, no problem just select this option")

            CHOICE=$(whiptail --title "$TITLE - Firewall" --menu "Firewalls are essential for server security. There are various ways to configure the firewall." $DIMS "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

            case $CHOICE in
                "new install")
                    sudo apt install -y ufw
                    SSH_PORT=$(whiptail --inputbox "What is your SSH port" --title "$TITLE - SSH port" $SIZE 3>&1 1>&2 2>&3)
                    sudo ufw allow $SSH_PORT/tcp
                    echo "UFW was installed with SSH port $SSH_PORT/tcp"
                    sudo ufw default deny incoming
                    sudo ufw default allow outgoing
                    ;;
                "already installed")
                    if whiptail --yesno "Have you already allowed the SSH port?" --title "$TITLE - Firewall" $SIZE; then
                        echo "UFW was already installed with SSH port $SSH_PORT/tcp"
                    else
                        SSH_PORT=$(whiptail --inputbox "What is your SSH port" --title "$TITLE - SSH port" $SIZE 3>&1 1>&2 2>&3)
                        sudo ufw allow $SSH_PORT/tcp
                        echo "UFW was installed with SSH port $SSH_PORT/tcp"
                    fi
                    ;;
                *)
                    quit
                    ;;
            esac

            sudo ufw allow $MariaDB_PORT/tcp
            sudo ufw allow $PhotoPrism_Port/tcp

            sudo ufw enable
            ;;
        "other firewall")
            # Show all Ports that have to be opened
            whiptail --title "$TITLE - Manual Firewall Configuration" --msgbox "Please ensure the following ports are open on your firewall to ensure proper operation:\n\nTCP Ports: $MARIA_DB_PORT, $PhotoPrism_Port both tcp\n\nThis may involve editing your firewall configuration files or using a firewall management tool. Refer to your firewall's documentation for instructions on opening ports." $SIZE
            ;;
        *)
            quit
            ;;
    esac
}

update(){
    sudo systemctl stop photoprism
    sudo cp /opt/photoprism/ /opt/photoprism.bak/
    sudo rm -rf /opt/photoprism/*
    wget https://dl.photoprism.app/pkg/linux/amd64.tar.gz
    sudo tar xzf amd64.tar.gz -C /opt/photoprism/
    sudo chown -R photoprism:photoprism /opt/photoprism
    rm amd64.tar.gz
    sudo systemctl start photoprism
    echo successfully updated
}

help(){
    whiptail --title "$TITLE - Help" --msgbox "Not implemented yet." $SIZE
    mainMenu
}

about(){
    whiptail --title "$TITLE - About" --msgbox "I wrote this little installer script for PhotoPrism because I was bored and because I want to install PhotoPrism but am too lazy to do everything myself. Now I have a script that does everything for me. It wasn't any better to make a script for it than to install it by hand, but now I did it." $SIZE
    mainMenu
}

quit(){
    # If you cannot understand this, read Bash_Shell_Scripting/Conditional_Expressions again.
    if whiptail --title "$TITLE - Quit" --yesno "You shure you want to quit" $SIZE; then
        echo "User selected Yes, exit status was $?."
    else
        echo "User selected No, exit status was $?."
        mainMenu
    fi
}


# run main
mainMenu
