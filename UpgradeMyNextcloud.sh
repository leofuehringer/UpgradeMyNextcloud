#!/bin/bash

# Create a log file with a timestamp
log_file="upgrade_mynextcloud_$(date +'%Y%m%d_%H%M%S').log"

# Function to write to the log file and to the console
log() {
    echo "$1" | tee -a "$log_file"
}

# Check if the script is run with sudo or as root
if [ "$EUID" -ne 0 ]; then
    log "Please run this script with sudo: sudo $0 <path>"
    exit 1
fi

# Check the number of arguments
if [ $# -ne 1 ]; then
    log "Usage: $0 <path>   e.g. ./UpgradeMyNextcloud.sh /var/www/aes"
    exit 1
fi

# Assign arguments
path=$1

# Check if the specified path exists
if [ ! -d "$path" ]; then
    log "Error: The specified path '$path' does not exist."
    exit 1
fi

# Check if the "nextcloud" folder exists in the specified path
if [ ! -d "$path/nextcloud" ]; then
    log "Error: The 'nextcloud' folder does not exist in the path '$path'."
    exit 1
fi

# Read the old version from the version.php file
old_version=$(grep "\$OC_VersionString" "$path/nextcloud/version.php" | awk -F"'" '{print $2}')

# Check if the old version was successfully read
if [ -z "$old_version" ]; then
    log "Error: Could not read the old version from the version.php file."
    exit 1
fi

log "Current version: $old_version"

# Define the major releases (may need to update - see https://nextcloud.com/changelog/)
new_versions=("28.0.21" "29.0.16" "30.0.13")

# Find the next major release
next_release=""
for version in "${new_versions[@]}"; do
    if [[ "$version" > "$old_version" ]]; then
        next_release="$version"
        break
    fi
done

# Check if a next release is available
if [ -z "$next_release" ]; then
    log "No new major releases are available."
    exit 0
fi

# List the major releases
log "Available major releases:"
for version in "${new_versions[@]}"; do
    log " - $version"
done

log "Note: If a release is missing, please add it on GitHub (https://github.com/leofuehringer/UpgradeMyNextcloud)."

# Suggest the next release for installation
log "The next major release for installation is: $next_release"
read -p "Do you want to proceed with the update to version $next_release? (y/n): " -n 1 -r
echo  # New line

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Update canceled."
    exit 0
fi

# URL for downloading the new version
url="https://download.nextcloud.com/server/releases/nextcloud-${next_release}.tar.bz2"

log "Disabling Moodle cron job for www-data..."
crontab -u www-data -l | sed '/cron\.php/s/^/#/' | crontab -u www-data -

log "Stopping Apache2..."
systemctl stop apache2

log "Changing to directory: $path"
cd "$path" || { log "Directory $path could not be found."; exit 1; }

log "Enabling maintenance mode..."
sudo -u www-data php8.2 "$path/nextcloud/occ" maintenance:mode --on

log "Backing up old Nextcloud version..."
mv nextcloud "nextcloud-${old_version}.bak"

log "Downloading new version of Nextcloud..."
wget "$url"

log "Extracting the new version..."
tar -xjf "nextcloud-${next_release}.tar.bz2"

log "Copying configuration and data..."
cp "nextcloud-${old_version}.bak/config/config.php" nextcloud/config/
mv "nextcloud-${old_version}.bak/data/" nextcloud/

# Copy missing app folders
target_directory="nextcloud/apps"
source_directory="nextcloud-${old_version}.bak/apps"

log "Copying missing app folders..."
for folder_name in "$source_directory"/*; do  # Loop through all folders in the source directory
    if [ -d "$folder_name" ]; then  # Check if it is a directory
        folder_name=$(basename "$folder_name")  # Extract the folder name
        target_path="$target_directory/$folder_name"  # Path to the target folder
        if [ ! -d "$target_path" ]; then  # Check if the target folder does not exist
            cp -r "$source_directory/$folder_name" "$target_directory"  # Copy the folder to the target directory
            log "Folder $folder_name has been copied."
        fi
    fi
done

log "Setting permissions for Nextcloud..."
chown -R www-data:www-data nextcloud
find nextcloud/ -type d -exec chmod 750 {} \;
find nextcloud/ -type f -exec chmod 640 {} \;

log "Running upgrade..."
sudo -u www-data php8.2 "$path/nextcloud/occ" upgrade

log "Disabling maintenance mode..."
sudo -u www-data php8.2 "$path/nextcloud/occ" maintenance:mode --off

log "Enabling Moodle cron job for www-data..."
crontab -u www-data -l | sed '/cron\.php/s/^#//' | crontab -u www-data -

log "Deleting the downloaded bz2 file..."
rm "nextcloud-${next_release}.tar.bz2"

log "Starting Apache2..."
systemctl start apache2

log "Nextcloud has been successfully updated from version $old_version to $next_release."

# End the tmux session
log "Ending the tmux session..."
exit 0
