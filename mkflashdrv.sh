#!/bin/bash

# This script was written to copy a large video file to several flash drives

# Define variables
FLASH_DRIVE="/dev/sdc"
MOUNT_POINT="/mnt/usbdrive"
LABEL="BETSIE"
SOURCE_FILE="/home/donnie/Desktop/Betsie/Celebration of Betsie.mp4"

# Check if the flash drive exists
if [ ! -b "$FLASH_DRIVE" ]; then
    echo "Error: Flash drive $FLASH_DRIVE not found!"
    exit 1
fi

# Step 1: Silently delete all partitions
echo "Deleting all partitions on $FLASH_DRIVE..."
sudo parted -s $FLASH_DRIVE mklabel msdos || { echo "Failed to create partition table!"; exit 1; }

# Step 2: Create a new 3GB FAT32 partition starting at sector 2048
echo "Creating FAT32 partition on $FLASH_DRIVE..."
sudo parted -s $FLASH_DRIVE mkpart primary fat32 2048s 3GB || { echo "Failed to create partition!"; exit 1; }

# Wait for the system to recognize the new partition
sleep 2

# Step 3: Format the partition as FAT32 and label it "BETSIE"
PARTITION="${FLASH_DRIVE}1"
echo "Formatting $PARTITION as FAT32 and labeling it '$LABEL'..."
sudo mkfs.vfat -F 32 -n $LABEL $PARTITION || { echo "Failed to format partition!"; exit 1; }

# Step 4: Mount the partition
echo "Mounting the partition..."
sudo mkdir -p $MOUNT_POINT
sudo mount $PARTITION $MOUNT_POINT || { echo "Failed to mount partition!"; exit 1; }

# Step 5: Copy the file to the flash drive
echo "Copying file to $PARTITION..."
sudo cp "$SOURCE_FILE" "$MOUNT_POINT" || { echo "Failed to copy file!"; exit 1; }
thunar $MOUNT_POINT

# Step 6: Unmount and clean up
echo "Syncing and unmounting..."
sync
sudo umount $MOUNT_POINT

echo "Flash drive setup complete!"
