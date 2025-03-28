#!/bin/bash

# Exit script on error
set -e

# Define variables
DB_NAME="wordpress_db"
DB_USER="wordpress_user"
DB_PASS="abcd123"
MYSQL_ROOT_PASS="abcd123"
WP_DIR="/var/www/html/wordpress"
APACHE_CONF="/etc/httpd/conf.d/wordpress.conf"

# Stop and clean up previous installations
echo "Cleaning up old installations..."
sudo systemctl stop httpd mariadb 2>/dev/null || true
sudo rm -rf $WP_DIR
sudo rm -f $APACHE_CONF
sudo dnf remove -y mariadb* httpd php* 2>/dev/null || true
sudo rm -rf /var/lib/mysql /etc/my.cnf

# Update system
echo "Updating system packages..."
sudo dnf update -y

# Install Apache, MariaDB, PHP, and required extensions
echo "Installing Apache, MariaDB, and PHP..."
sudo dnf install -y httpd mariadb105-server php8.3 php8.3-mysqlnd php8.3-xml php8.3-mbstring php8.3-common unzip wget

# Start and enable services
echo "Starting and enabling services..."
sudo systemctl enable --now httpd mariadb

# Secure MariaDB installation
echo "Securing MariaDB..."
sudo mysqladmin -u root password "$MYSQL_ROOT_PASS"
echo -e "$MYSQL_ROOT_PASS\nn\ny\ny\ny\ny" | sudo mysql_secure_installation

# Restart MariaDB after securing
sudo systemctl restart mariadb

# Create WordPress Database & User
echo "Creating MySQL Database and User..."
sudo mysql -u root -p"$MYSQL_ROOT_PASS" <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Download and setup WordPress
echo "Downloading and configuring WordPress..."
wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip
sudo unzip /tmp/wordpress.zip -d /var/www/html/
sudo chown -R apache:apache $WP_DIR
sudo chmod -R 755 $WP_DIR

# Configure wp-config.php
echo "Configuring WordPress..."
sudo cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sudo sed -i "s/database_name_here/$DB_NAME/" $WP_DIR/wp-config.php
sudo sed -i "s/username_here/$DB_USER/" $WP_DIR/wp-config.php
sudo sed -i "s/password_here/$DB_PASS/" $WP_DIR/wp-config.php

# Configure Apache Virtual Host
echo "Configuring Apache Virtual Host..."
sudo bash -c "cat > $APACHE_CONF <<EOF
<VirtualHost *:80>
    ServerAdmin admin@example.com
    DocumentRoot $WP_DIR
    <Directory $WP_DIR>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/httpd/wordpress_error.log
    CustomLog /var/log/httpd/wordpress_access.log combined
</VirtualHost>
EOF"

# Restart Apache to apply changes
sudo systemctl restart httpd

# Output MySQL Connection String
echo "WordPress installation completed successfully!"
echo "--------------------------------------"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASS"
echo "MySQL Root Password: $MYSQL_ROOT_PASS"
echo "Access WordPress at: http://$(hostname -I | awk '{print $1}')/"
echo "--------------------------------------"
echo "MySQL Connection String:"
echo "mysql -u $DB_USER -p'$DB_PASS' -h localhost $DB_NAME"
echo "--------------------------------------"
