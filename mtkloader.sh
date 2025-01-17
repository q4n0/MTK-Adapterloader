#!/bin/bash

# Define variables
REPO_URL="https://github.com/morrownr/7612u.git"
REPO_DIR="7612u"
INTERFACE="wlan0"  # Replace with your actual wireless interface name
PHY_PATH=$(ls /sys/kernel/debug/ieee80211/phy*/mt76 -d 2>/dev/null)
PERMANENT_POWER=false

# Function to check and unblock RF-kill
check_rfkill() {
  if rfkill list | grep -q "$INTERFACE.*blocked"; then
    echo "The $INTERFACE interface is blocked by RF-kill. Attempting to unblock."
    sudo rfkill unblock all
    if [ $? -eq 0 ]; then
      echo "RF-kill unblock successful."
    else
      echo "Failed to unblock RF-kill."
      exit 1
    fi
  else
    echo "$INTERFACE is not blocked by RF-kill."
  fi
}

# Function to update and install necessary packages
install_dependencies() {
  echo "Updating package lists..."
  sudo apt update
  echo "Installing necessary packages..."
  sudo apt install -y dkms build-essential git
}

# Function to clone the repository and install the driver
install_driver() {
  if [ -d "$REPO_DIR" ]; then
    echo "Directory $REPO_DIR already exists. Pulling the latest changes."
    cd "$REPO_DIR" || exit
    git pull
  else
    echo "Cloning repository from $REPO_URL..."
    git clone "$REPO_URL"
    cd "$REPO_DIR" || exit
  fi

  # Create the installation script inline
  echo "#!/bin/bash

  SCRIPT_NAME=\"led_ctrl_7612u.sh\"
  SCRIPT_VERSION=\"20221021\"

  # check to ensure sudo was used
  if [[ \$EUID -ne 0 ]]
  then
    echo \"You must run this script with superuser (root) privileges.\"
    echo \"Try: \\\"sudo ./\${SCRIPT_NAME}\\\"\"
    exit 1
  fi

  make
  sudo make install

  exit 0
  " > led_ctrl_7612u.sh

  chmod +x ./led_ctrl_7612u.sh

  # Run the installation script
  echo "Running driver installation script..."
  sudo ./led_ctrl_7612u.sh

  # Check the installation status
  if [ $? -eq 0 ]; then
    echo "Driver installed successfully."
  else
    echo "Driver installation failed."
    exit 1
  fi
}

# Function to enable the adapter
enable_adapter() {
  check_rfkill
  echo "Enabling the adapter $INTERFACE..."
  sudo ifconfig $INTERFACE up
  if [ $? -eq 0 ]; then
    echo "Adapter $INTERFACE enabled."
  else
    echo "Failed to enable adapter $INTERFACE."
    exit 1
  fi
}

# Function to disable the adapter
disable_adapter() {
  check_rfkill
  echo "Disabling the adapter $INTERFACE..."
  sudo ifconfig $INTERFACE down
  if [ $? -eq 0 ]; then
    echo "Adapter $INTERFACE disabled."
  else
    echo "Failed to disable adapter $INTERFACE."
    exit 1
  fi
}

# Function to set LED control register
set_led_register() {
  if [ -z "$PHY_PATH" ]; then
    echo "Error: PHY path not found."
    exit 1
  fi
  echo 0x770 | sudo tee "${PHY_PATH}/regidx"
}

# Function to turn on the LED
led_on() {
  set_led_register
  echo 0x800000 | sudo tee "${PHY_PATH}/regval"
  if [ $? -eq 0 ]; then
    echo "LED for $INTERFACE turned on."
  else
    echo "Failed to turn on LED for $INTERFACE."
    exit 1
  fi
}

# Function to turn off the LED
led_off() {
  set_led_register
  echo 0x820000 | sudo tee "${PHY_PATH}/regval"
  if [ $? -eq 0 ]; then
    echo "LED for $INTERFACE turned off."
  else
    echo "Failed to turn off LED for $INTERFACE."
    exit 1
  fi
}

# Function to blink the LED
led_blink() {
  set_led_register
  echo 0x840000 | sudo tee "${PHY_PATH}/regval"
  if [ $? -eq 0 ]; then
    echo "LED for $INTERFACE set to blink."
  else
    echo "Failed to set LED for $INTERFACE to blink."
    exit 1
  fi
}

# Function to set permanent power
set_permanent_power() {
  read -rp "Do you want the USB adapter to be permanently powered on? (y/n): " perm_power_choice
  case "$perm_power_choice" in
    y|Y)
      PERMANENT_POWER=true
      echo "Permanent power enabled for the USB adapter."
      ;;
    n|N)
      PERMANENT_POWER=false
      echo "Permanent power disabled for the USB adapter."
      ;;
    *)
      echo "Invalid choice. Assuming no."
      PERMANENT_POWER=false
      ;;
  esac
}

# Function to display menu and handle user input
display_menu() {
  echo "Please choose an option:"
  echo "1. Install driver"
  echo "2. Enable adapter"
  echo "3. Disable adapter"
  echo "4. Turn on LED"
  echo "5. Turn off LED"
  echo "6. Blink LED"
  echo "7. Set permanent power"
  echo "8. Exit"

  read -rp "Enter your choice [1-8]: " choice
  case "$choice" in
    1)
      install_dependencies
      install_driver
      ;;
    2)
      if [ "$PERMANENT_POWER" = true ]; then
        echo "Adapter $INTERFACE is set to be permanently powered on."
      else
        enable_adapter
      fi
      ;;
    3)
      if [ "$PERMANENT_POWER" = true ]; then
        echo "Adapter $INTERFACE is set to be permanently powered on. Disabling not required."
      else
        disable_adapter
      fi
      ;;
    4)
      led_on
      ;;
    5)
      led_off
      ;;
    6)
      led_blink
      ;;
    7)
      set_permanent_power
      ;;
    8)
      echo "Exiting."
      exit 0
      ;;
    *)
      echo "Invalid option."
      ;;
  esac
}

# Main script execution
if [ -z "$1" ]; then
  display_menu
else
  case "$1" in
    install)
      install_dependencies
      install_driver
      ;;
    enable)
      if [ "$PERMANENT_POWER" = true ]; then
        echo "Adapter $INTERFACE is set to be permanently powered on."
      else
        enable_adapter
      fi
      ;;
    disable)
      if [ "$PERMANENT_POWER" = true ]; then
        echo "Adapter $INTERFACE is set to be permanently powered on. Disabling not required."
      else
        disable_adapter
      fi
      ;;
    led-on)
      led_on
      ;;
    led-off)
      led_off
      ;;
    led-blink)
      led_blink
      ;;
    set-permanent-power)
      set_permanent_power
      ;;
    *)
      echo "Usage: $0 {install|enable|disable|led-on|led-off|led-blink|set-permanent-power}"
      ;;
  esac
fi
