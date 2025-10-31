#!/bin/bash

# Add color for text
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
plain='\033[0m'
NC='\033[0m' # No Color

cur_dir=$(pwd)
WATERWALL_DIR="/waterwall"
SERVICE_NAME="waterwall"

install_jq() {
    if ! command -v jq &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}jq is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y jq
        else
            echo -e "${RED}Error: Unsupported package manager. Please install jq manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}

loader() {
    install_jq

    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country' 2>/dev/null || echo "Unknown")
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp' 2>/dev/null || echo "Unknown")

    WATER_CORE=$(check_core_status)
    WATER_TUNNEL=$(check_tunnel_status)

    init
}

menu() {
    clear
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SERVER_COUNTRY=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country' 2>/dev/null || echo "Unknown")
    SERVER_ISP=$(curl -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp' 2>/dev/null || echo "Unknown")

    WATER_CORE=$(check_core_status)
    WATER_TUNNEL=$(check_tunnel_status)

    echo "+-----------------------------------------------------------------------------------------------------------------------+"
    echo "| __          __        _               __          __        _  _   _______                             _              |" 
    echo "| \ \        / /       | |              \ \        / /       | || | |__   __|                           | |             |" 
    echo "|  \ \  /\  / /   __ _ | |_   ___  _ __  \ \  /\  / /   __ _ | || |    | |    _   _  _ __   _ __    ___ | |             |" 
    echo "|   \ \/  \/ /   / _  || __| / _ \| '__|  \ \/  \/ /   / _  || || |    | |   | | | || '_ \ |  _ \  / _ \| |             |" 
    echo "|    \  /\  /   | (_| || |_ |  __/| |      \  /\  /   | (_| || || |    | |   | |_| || | | || | | ||  __/| |             |" 
    echo "|     \/  \/     \__,_| \__| \___||_|       \/  \/     \__,_||_||_|    |_|    \__,_||_| |_||_| |_| \___||_|             |" 
    echo "+-----------------------------------------------------------------------------------------------------------------------+"
    echo -e "|Telegram Channel : ${GREEN}@DIGITALVORTX ${NC}                          HalfDuplex Tunnel Configuration          "
    echo "+-----------------------------------------------------------------------------------------------------------------------+"
    echo -e "|${GREEN}Server Country    |${NC} $SERVER_COUNTRY"
    echo -e "|${GREEN}Server IP         |${NC} $SERVER_IP"
    echo -e "|${GREEN}Server ISP        |${NC} $SERVER_ISP"
    echo -e "|${GREEN}WaterWall CORE    |${NC} $WATER_CORE"
    echo -e "|${GREEN}WaterWall Tunnel  |${NC} $WATER_TUNNEL"
    echo "+-----------------------------------------------------------------------------------------------------------------------+"
    echo -e "|${YELLOW}Please choose an option:${NC}"
    echo "+-----------------------------------------------------------------------------------------------------------------------+"
    echo -e "$1"
    echo "+-----------------------------------------------------------------------------------------------------------------------+"
    echo -e "\033[0m"
}

init() {
    menu "| 1 - INSTALL CORE \n| 2  - Config HalfDuplex Tunnel \n| 3  - Manage Multiple Configs (Foreign Server) \n| 4  - Status Tunnel  \n| 5  - Start Tunnel  \n| 6  - Stop Tunnel  \n| 9 - Uninstall \n| 0  - Exit"
    
    read -p "Enter option number: " choice
    case $choice in
    1)
        install_core
        ;;  
    2)
        halfduplex_config
        ;;
    3)
        manage_multiple_configs
        ;;
    4)
        check_status
        ;;
    5)
        start_tunnel
        ;;
    6)
        stop_tunnel
        ;;
    9)
        unistall
        ;;
    0)
        echo -e "${GREEN}Exiting program...${NC}"
        exit 0
        ;;
    *)
        echo "Not valid"
        sleep 2
        init
        ;;
    esac
}

# Function to parse port input (supports single port, comma-separated, array format, or range)
# For ranges, outputs as [start, end] instead of listing all ports
parse_ports() {
    local input="$1"
    
    # Remove spaces
    input=$(echo "$input" | tr -d ' ')
    
    # Check if it's an array format like [8447, 8450] or [3000, 2000]
    if [[ "$input" =~ ^\[.*\]$ ]]; then
        # Remove brackets
        input="${input#\[}"
        input="${input%\]}"
        
        # Check if it has comma (range in array format)
        if [[ "$input" == *,* ]]; then
            local start_port=$(echo "$input" | cut -d',' -f1)
            local end_port=$(echo "$input" | cut -d',' -f2 | tr -d ' ')
            
            # Swap if start > end (supporting [3000, 2000] format)
            if [ "$start_port" -gt "$end_port" ]; then
                local temp=$start_port
                start_port=$end_port
                end_port=$temp
            fi
            
            # Return as range format [start, end]
            echo "[$start_port, $end_port]"
        else
            # Single port in array format [80]
            echo "[$input]"
        fi
    # Check if it's a range with dash (e.g., 8447-8450)
    elif [[ "$input" == *-* ]]; then
        local start_port=${input%-*}
        local end_port=${input#*-}
        
        # Swap if start > end
        if [ "$start_port" -gt "$end_port" ]; then
            local temp=$start_port
            start_port=$end_port
            end_port=$temp
        fi
        
        # Return as range format [start, end]
        echo "[$start_port, $end_port]"
    # Check if it's comma-separated (e.g., 8447,8448,8449)
    elif [[ "$input" == *,* ]]; then
        echo "[$input]"
    # Single port (e.g., 80)
    else
        echo "$input"
    fi
}

halfduplex_config() {
    clear
    echo "+--------------------------------------------------------------------------------------------------------------+"
    echo "|                                                                                                              |" 
    echo "| __          __        _               __          __        _  _   _______                             _     |" 
    echo "| \ \        / /       | |              \ \        / /       | || | |__   __|                           | |    |" 
    echo "|  \ \  /\  / /   __ _ | |_   ___  _ __  \ \  /\  / /   __ _ | || |    | |    _   _  _ __   _ __    ___ | |    |" 
    echo "|   \ \/  \/ /   / _  || __| / _ \| '__|  \ \/  \/ /   / _  || || |    | |   | | | || '_ \ |  _ \  / _ \| |    |" 
    echo "|    \  /\  /   | (_| || |_ |  __/| |      \  /\  /   | (_| || || |    | |   | |_| || | | || | | ||  __/| |    |" 
    echo "|     \/  \/     \__,_| \__| \___||_|       \/  \/     \__,_||_||_|    |_|    \__,_||_| |_||_| |_| \___||_|    |" 
    echo "|                                                                                                              |" 
    echo "+--------------------------------------------------------------------------------------------------------------+"
    echo -e "|${GREEN}Server Country    |${NC} $SERVER_COUNTRY"
    echo -e "|${GREEN}Server IP         |${NC} $SERVER_IP"
    echo -e "|${GREEN}Server ISP        |${NC} $SERVER_ISP"
    echo -e "|${GREEN}WaterWall CORE    |${NC} $WATER_CORE"
    echo -e "|${GREEN}WaterWall Tunnel  |${NC} $WATER_TUNNEL"
    echo "+--------------------------------------------------------------------------------------------------------------+"
    echo -e "${GREEN}Please choose server type:${NC}"
    echo "+---------------------------------------------------------------+"
    echo -e "${BLUE}| 1  - IRAN Server (HalfDuplex Client)"
    echo -e "${BLUE}| 2  - Kharej/Foreign Server (HalfDuplex Server)"
    echo -e "${BLUE}| 0  - Back to Main Menu"
    echo "+---------------------------------------------------------------+"
    echo -e "\033[0m"

    read -p "Enter option number: " setup

    case $setup in
    1)
        config_iran_server
        ;;
    2)
        config_foreign_server
        ;;
    0)
        init
        ;;
    *)
        echo "Invalid option"
        sleep 2
        halfduplex_config
        ;;
    esac
}

config_iran_server() {
    echo -e "\n${YELLOW}=== IRAN Server Configuration ===${NC}\n"
    
    # Get listener settings
    read -p "Enter listener address [0.0.0.0]: " listener_address
    listener_address=${listener_address:-0.0.0.0}
    
    echo -e "${YELLOW}Enter listener ports (single: 80, multiple: 8447,8448,8449, range: 8447-8450, or array: [8447,8450] or [3000,2000]):${NC}"
    read -p "Listener ports: " listener_ports
    listener_ports=$(parse_ports "$listener_ports")
    
    # Get foreign server IP
    read -p "Enter Foreign/Kharej Server IP: " foreign_ip
    if [ -z "$foreign_ip" ]; then
        echo -e "${RED}Error: Foreign Server IP is required${NC}"
        sleep 2
        config_iran_server
        return
    fi
    
    echo -e "${YELLOW}Enter connector ports to Foreign Server (single: 8443, multiple: 8443,8444,8445, range: 8443-8446, or array: [8443,8446]):${NC}"
    read -p "Connector ports: " connector_ports
    connector_ports=$(parse_ports "$connector_ports")
    
    # Create config file in /waterwall directory
    sudo mkdir -p "$WATERWALL_DIR"
    cat <<EOL | sudo tee "$WATERWALL_DIR/dev-ir.json" > /dev/null
{
  "name": "iran_server_config",
  "nodes": [
    {
      "name": "iran_multi_port_listener",
      "type": "TcpListener",
      "settings": {
        "address": "$listener_address",
        "port": $listener_ports,
        "nodelay": true,
        "multiport-backend": "socket"
      },
      "next": "halfduplex_client"
    },
    {
      "name": "halfduplex_client",
      "type": "HalfDuplexClient",
      "settings": {},
      "next": "foreign_connector"
    },
    {
      "name": "foreign_connector",
      "type": "TcpConnector",
      "settings": {
        "address": "$foreign_ip",
        "port": $connector_ports,
        "nodelay": true,
        "fastopen": false,
        "domain-strategy": "ipv4"
      },
      "next": null
    }
  ]
}
EOL

    sudo chmod 644 "$WATERWALL_DIR/dev-ir.json"
    
    # Update core.json
    if [ -f "$WATERWALL_DIR/core.json" ]; then
        update_core_json
    fi
    
    echo -e "\n${GREEN}✓ Iran server configuration created successfully!${NC}"
    echo -e "${GREEN}Configuration saved to: $WATERWALL_DIR/dev-ir.json${NC}\n"
    
    read -p "Press Enter to continue..."
    init
}

config_foreign_server() {
    echo -e "\n${YELLOW}=== Kharej/Foreign Server Configuration ===${NC}\n"
    
    # Get config name
    read -p "Enter config name [foreign-server-1]: " config_name
    config_name=${config_name:-foreign-server-1}
    
    # Get listener settings
    read -p "Enter listener address [0.0.0.0]: " listener_address
    listener_address=${listener_address:-0.0.0.0}
    
    echo -e "${YELLOW}Enter listener ports (single: 8443, multiple: 8443,8444,8445, range: 8443-8446, or array: [8443,8446] or [3000,2000]):${NC}"
    read -p "Listener ports: " listener_ports
    listener_ports=$(parse_ports "$listener_ports")
    
    # Only ask for connector ports (IP is always 127.0.0.1)
    echo -e "${YELLOW}Enter connector ports to localhost (single: 8447, multiple: 8447,8448,8449, range: 8447-8450, or array: [8447,8450]):${NC}"
    echo -e "${BLUE}Note: Connector will connect to 127.0.0.1${NC}"
    read -p "Connector ports: " connector_ports
    connector_ports=$(parse_ports "$connector_ports")
    
    # Create config file in /waterwall directory
    sudo mkdir -p "$WATERWALL_DIR"
    config_file="$WATERWALL_DIR/${config_name}.json"
    
    cat <<EOL | sudo tee "$config_file" > /dev/null
{
  "name": "${config_name}",
  "nodes": [
    {
      "name": "foreign_multi_port_listener",
      "type": "TcpListener",
      "settings": {
        "address": "$listener_address",
        "port": $listener_ports,
        "nodelay": true,
        "multiport-backend": "socket"
      },
      "next": "halfduplex_server"
    },
    {
      "name": "halfduplex_server",
      "type": "HalfDuplexServer",
      "settings": {},
      "next": "iran_connector"
    },
    {
      "name": "iran_connector",
      "type": "TcpConnector",
      "settings": {
        "address": "127.0.0.1",
        "port": $connector_ports,
        "nodelay": true,
        "fastopen": false,
        "domain-strategy": "ipv4"
      },
      "next": null
    }
  ]
}
EOL

    sudo chmod 644 "$config_file"
    
    # Update core.json to include this config
    update_core_json
    
    echo -e "\n${GREEN}✓ Foreign server configuration created successfully!${NC}"
    echo -e "${GREEN}Configuration saved to: $config_file${NC}"
    echo -e "${GREEN}Config added to core.json${NC}\n"
    
    read -p "Press Enter to continue..."
    init
}

# Function to update core.json with all config files
update_core_json() {
    if [ ! -f "$WATERWALL_DIR/core.json" ]; then
        echo -e "${YELLOW}core.json not found. Creating...${NC}"
        create_core_json
        return
    fi
    
    # Get all JSON config files in /waterwall
    config_files=()
    while IFS= read -r file; do
        filename=$(basename "$file")
        config_files+=("$filename")
    done < <(sudo find "$WATERWALL_DIR" -maxdepth 1 -name "*.json" -not -name "core.json" 2>/dev/null)
    
    # If no configs found, use default
    if [ ${#config_files[@]} -eq 0 ]; then
        config_files=("dev-ir.json")
    fi
    
    # Create updated core.json
    cat <<EOL | sudo tee "$WATERWALL_DIR/core.json" > /dev/null
{
    "log": {
        "path": "log/",
        "core": {
            "loglevel": "DEBUG",
            "file": "core.log",
            "console": true
        },
        "network": {
            "loglevel": "DEBUG",
            "file": "network.log",
            "console": true
        },
        "dns": {
            "loglevel": "SILENT",
            "file": "dns.log",
            "console": false
        }
    },
    "dns": {},
    "misc": {
        "workers": 0,
        "ram-profile": "server",
        "libs-path": "libs/"
    },
    "configs": [
$(printf '        "%s"' "${config_files[0]}")
$(for ((i=1; i<${#config_files[@]}; i++)); do
    printf ',\n        "%s"' "${config_files[$i]}"
done)
    ]
}
EOL

    sudo chmod 644 "$WATERWALL_DIR/core.json"
}

# Function to create initial core.json
create_core_json() {
    cat <<EOL | sudo tee "$WATERWALL_DIR/core.json" > /dev/null
{
    "log": {
        "path": "log/",
        "core": {
            "loglevel": "DEBUG",
            "file": "core.log",
            "console": true
        },
        "network": {
            "loglevel": "DEBUG",
            "file": "network.log",
            "console": true
        },
        "dns": {
            "loglevel": "SILENT",
            "file": "dns.log",
            "console": false
        }
    },
    "dns": {},
    "misc": {
        "workers": 0,
        "ram-profile": "server",
        "libs-path": "libs/"
    },
    "configs": [
        "dev-ir.json"
    ]
}
EOL

    sudo chmod 644 "$WATERWALL_DIR/core.json"
}

# Function to manage multiple configs
manage_multiple_configs() {
    clear
    echo -e "${YELLOW}=== Manage Multiple Configs (Foreign Server) ===${NC}\n"
    
    # List existing configs
    config_files=()
    while IFS= read -r file; do
        filename=$(basename "$file" .json)
        config_files+=("$filename")
    done < <(sudo find "$WATERWALL_DIR" -maxdepth 1 -name "*.json" -not -name "core.json" 2>/dev/null)
    
    if [ ${#config_files[@]} -eq 0 ]; then
        echo -e "${RED}No config files found!${NC}"
        read -p "Press Enter to continue..."
        init
        return
    fi
    
    echo -e "${GREEN}Existing configs:${NC}"
    for ((i=0; i<${#config_files[@]}; i++)); do
        echo -e "  $((i+1)). ${config_files[$i]}.json"
    done
    
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1 - Create new config"
    echo "  2 - Delete config"
    echo "  3 - View config"
    echo "  0 - Back to main menu"
    
    read -p "Enter option: " option
    
    case $option in
    1)
        config_foreign_server
        ;;
    2)
        echo ""
        read -p "Enter config number to delete: " num
        if [ "$num" -ge 1 ] && [ "$num" -le ${#config_files[@]} ]; then
            idx=$((num-1))
            config_name="${config_files[$idx]}"
            sudo rm -f "$WATERWALL_DIR/${config_name}.json"
            update_core_json
            echo -e "${GREEN}Config ${config_name}.json deleted!${NC}"
        else
            echo -e "${RED}Invalid number!${NC}"
        fi
        sleep 2
        manage_multiple_configs
        ;;
    3)
        echo ""
        read -p "Enter config number to view: " num
        if [ "$num" -ge 1 ] && [ "$num" -le ${#config_files[@]} ]; then
            idx=$((num-1))
            config_name="${config_files[$idx]}"
            echo -e "\n${YELLOW}Content of ${config_name}.json:${NC}"
            sudo cat "$WATERWALL_DIR/${config_name}.json" | jq '.' 2>/dev/null || sudo cat "$WATERWALL_DIR/${config_name}.json"
        else
            echo -e "${RED}Invalid number!${NC}"
        fi
        read -p "Press Enter to continue..."
        manage_multiple_configs
        ;;
    0)
        init
        ;;
    *)
        echo "Invalid option"
        sleep 2
        manage_multiple_configs
        ;;
    esac
}

install_core() {
    echo -e "${YELLOW}Installing WaterWall Core...${NC}"
    
    # Check if directory exists, create if not
    if [ ! -d "$WATERWALL_DIR" ]; then
        echo -e "${YELLOW}Creating directory: $WATERWALL_DIR${NC}"
        sudo mkdir -p "$WATERWALL_DIR"
    fi
    
    # Change to waterwall directory
    cd "$WATERWALL_DIR" || {
        echo -e "${RED}Error: Cannot access $WATERWALL_DIR${NC}"
        read -p "Press Enter to continue..."
        init
        return
    }
    
    # Detect architecture
    ARCH=$(uname -m)
    echo -e "${BLUE}Detected architecture: $ARCH${NC}"
    
    # Determine download URL based on architecture
    if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
        DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.40/Waterwall-linux-gcc-x64.zip"
        ARCH_TYPE="x64"
        echo -e "${GREEN}Selected: AMD64/x86_64 version${NC}"
    elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        DOWNLOAD_URL="https://github.com/radkesvat/WaterWall/releases/download/v1.40/Waterwall-linux-gcc-arm64.zip"
        ARCH_TYPE="arm64"
        echo -e "${GREEN}Selected: ARM64 version${NC}"
    else
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        echo -e "${YELLOW}Supported architectures: x86_64, amd64, aarch64, arm64${NC}"
        read -p "Press Enter to continue..."
        cd "$cur_dir"
        init
        return
    fi
    
    # Check for wget or curl
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: wget or curl is required${NC}"
        echo -e "${YELLOW}Installing wget...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y wget
        elif command -v yum &> /dev/null; then
            sudo yum install -y wget
        else
            echo -e "${RED}Cannot install wget. Please install manually.${NC}"
            cd "$cur_dir"
            read -p "Press Enter to continue..."
            init
            return
        fi
    fi
    
    # Download WaterWall
    echo -e "${YELLOW}Downloading WaterWall v1.40 ($ARCH_TYPE)...${NC}"
    if command -v wget &> /dev/null; then
        wget -O Waterwall.zip "$DOWNLOAD_URL" 2>&1 | grep -E "(Downloading|saved|error)" || true
    else
        curl -L -o Waterwall.zip "$DOWNLOAD_URL" --progress-bar
    fi
    
    # Check if download was successful
    if [ ! -f "Waterwall.zip" ]; then
        echo -e "${RED}Error: Download failed${NC}"
        cd "$cur_dir"
        read -p "Press Enter to continue..."
        init
        return
    fi
    
    # Check if unzip is installed
    if ! command -v unzip &> /dev/null; then
        echo -e "${YELLOW}Installing unzip...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y unzip
        elif command -v yum &> /dev/null; then
            sudo yum install -y unzip
        else
            echo -e "${RED}Cannot install unzip. Please install manually.${NC}"
            cd "$cur_dir"
            read -p "Press Enter to continue..."
            init
            return
        fi
    fi
    
    # Extract files
    echo -e "${YELLOW}Extracting WaterWall...${NC}"
    unzip -o Waterwall.zip
    
    # Remove zip file
    rm -f Waterwall.zip
    
    # Give execute permissions to all files
    echo -e "${YELLOW}Setting permissions...${NC}"
    sudo chmod +x *
    sudo chmod +x Waterwall 2>/dev/null || true
    
    # Set ownership if needed (optional)
    if [ -n "$SUDO_USER" ]; then
        sudo chown -R "$SUDO_USER:$SUDO_USER" "$WATERWALL_DIR" 2>/dev/null || true
    fi
    
    # Create core.json
    create_core_json

    # Create log and libs directories
    mkdir -p log libs
    
    # Set permissions for directories
    sudo chmod -R 755 "$WATERWALL_DIR"
    
    echo -e "${GREEN}✓ WaterWall Core installed successfully in $WATERWALL_DIR!${NC}"
    echo -e "${GREEN}✓ All files have execute permissions${NC}"
    
    # Return to original directory
    cd "$cur_dir"
    
    echo $'\e[32mReturning to menu in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1
    init
}

# Create systemd service file
create_systemd_service() {
    if [ ! -f "$WATERWALL_DIR/Waterwall" ]; then
        return 1
    fi
    
    # Create systemd service file
    cat <<EOL | sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null
[Unit]
Description=WaterWall HalfDuplex Tunnel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WATERWALL_DIR
ExecStart=$WATERWALL_DIR/Waterwall
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=waterwall

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd daemon
    sudo systemctl daemon-reload
    return 0
}

start_tunnel() {
    if [ ! -f "$WATERWALL_DIR/dev-ir.json" ]; then
        echo -e "${RED}Error: dev-ir.json not found. Please configure tunnel first.${NC}"
        sleep 2
        init
        return
    fi
    
    if [ ! -f "$WATERWALL_DIR/Waterwall" ]; then
        echo -e "${RED}Error: Waterwall binary not found. Please install core first.${NC}"
        sleep 2
        init
        return
    fi
    
    # Check if service already exists, if not create it
    if [ ! -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        echo -e "${YELLOW}Creating systemd service...${NC}"
        create_systemd_service
    fi
    
    # Check if already running
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo -e "${YELLOW}WaterWall service is already running!${NC}"
        sleep 2
        init
        return
    fi
    
    # Start service
    echo -e "${YELLOW}Starting WaterWall service...${NC}"
    sudo systemctl start ${SERVICE_NAME}
    
    # Enable service to start on boot
    sudo systemctl enable ${SERVICE_NAME} > /dev/null 2>&1
    
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo -e "${GREEN}✓ WaterWall service started successfully!${NC}"
        echo -e "${YELLOW}Service name: ${SERVICE_NAME}${NC}"
        echo -e "${YELLOW}To check status: systemctl status ${SERVICE_NAME}${NC}"
        echo -e "${YELLOW}To view logs: journalctl -u ${SERVICE_NAME} -f${NC}"
    else
        echo -e "${RED}Error: Failed to start WaterWall service${NC}"
        echo -e "${YELLOW}Check logs with: journalctl -u ${SERVICE_NAME} -n 50${NC}"
    fi
    
    sleep 2
    init
}

stop_tunnel() {
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo -e "${YELLOW}Stopping WaterWall service...${NC}"
        sudo systemctl stop ${SERVICE_NAME}
        echo -e "${GREEN}✓ WaterWall service stopped!${NC}"
    else
        echo -e "${YELLOW}WaterWall service is not running.${NC}"
    fi
    sleep 2
    init
}

check_status() {
    clear
    echo -e "${YELLOW}=== WaterWall Status ===${NC}\n"
    echo -e "${BLUE}Installation Directory: $WATERWALL_DIR${NC}"
    echo -e "${BLUE}Service Name: ${SERVICE_NAME}${NC}\n"
    
    if [ -f "$WATERWALL_DIR/core.json" ]; then
        echo -e "${GREEN}Core: Installed${NC}"
    else
        echo -e "${RED}Core: Not installed${NC}"
    fi
    
    # List all config files
    config_files=()
    while IFS= read -r file; do
        filename=$(basename "$file")
        config_files+=("$filename")
    done < <(sudo find "$WATERWALL_DIR" -maxdepth 1 -name "*.json" -not -name "core.json" 2>/dev/null)
    
    if [ ${#config_files[@]} -gt 0 ]; then
        echo -e "${GREEN}Tunnel Configs: Found ${#config_files[@]} config(s)${NC}"
        for config in "${config_files[@]}"; do
            echo -e "\n${YELLOW}Config: $config${NC}"
            sudo cat "$WATERWALL_DIR/$config" | jq '.' 2>/dev/null | head -n 20 || sudo head -n 20 "$WATERWALL_DIR/$config"
        done
    else
        echo -e "${RED}Tunnel Config: Not found${NC}"
    fi
    
    # Show core.json configs section
    if [ -f "$WATERWALL_DIR/core.json" ]; then
        echo -e "\n${YELLOW}Configs in core.json:${NC}"
        sudo cat "$WATERWALL_DIR/core.json" | jq '.configs' 2>/dev/null || echo "Could not parse core.json"
    fi
    
    echo ""
    echo -e "${YELLOW}Service Status:${NC}"
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo -e "${GREEN}Status: Running${NC}"
        systemctl status ${SERVICE_NAME} --no-pager -l | head -n 10
    elif systemctl is-enabled --quiet ${SERVICE_NAME} 2>/dev/null; then
        echo -e "${RED}Status: Stopped${NC}"
        systemctl status ${SERVICE_NAME} --no-pager -l | head -n 10 2>/dev/null || echo "Service exists but is not running"
    else
        echo -e "${YELLOW}Status: Service not created${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo -e "  systemctl status ${SERVICE_NAME}"
    echo -e "  systemctl start ${SERVICE_NAME}"
    echo -e "  systemctl stop ${SERVICE_NAME}"
    echo -e "  journalctl -u ${SERVICE_NAME} -f"
    echo ""
    read -p "Press Enter to continue..."
    init
}

check_core_status() {
    local file_path="$WATERWALL_DIR/core.json"
    local status

    if [ -f "$file_path" ]; then
        status="${GREEN}Installed${NC}"
    else
        status="${RED}Not installed${NC}"
    fi

    echo "$status"
}

check_tunnel_status() {
    local file_path="$WATERWALL_DIR/dev-ir.json"
    local status

    if [ -f "$file_path" ]; then
        status="${GREEN}Enabled${NC}"
    else
        status="${RED}Disabled${NC}"
    fi

    echo "$status"
}

unistall() {
    echo -e "${RED}This will remove all WaterWall files and stop running tunnels.${NC}"
    echo -e "${RED}Directory to be removed: $WATERWALL_DIR${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        sleep 1
        init
        return
    fi
    
    echo $'\e[32mUninstalling WaterWall in 3 seconds... \e[0m' && sleep 1 && echo $'\e[32m2... \e[0m' && sleep 1 && echo $'\e[32m1... \e[0m' && sleep 1
    
    # Stop and disable service
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        echo -e "${YELLOW}Stopping service...${NC}"
        sudo systemctl stop ${SERVICE_NAME}
    fi
    
    if systemctl is-enabled --quiet ${SERVICE_NAME} 2>/dev/null; then
        echo -e "${YELLOW}Disabling service...${NC}"
        sudo systemctl disable ${SERVICE_NAME}
    fi
    
    # Remove service file
    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
        echo -e "${YELLOW}Removing service file...${NC}"
        sudo rm -f /etc/systemd/system/${SERVICE_NAME}.service
        sudo systemctl daemon-reload
        echo -e "${GREEN}Service removed${NC}"
    fi
    
    # Remove entire /waterwall directory
    if [ -d "$WATERWALL_DIR" ]; then
        sudo rm -rf "$WATERWALL_DIR"
        echo -e "${GREEN}Removed $WATERWALL_DIR directory${NC}"
    fi
    
    clear
    echo -e "${GREEN}WaterWall Uninstalled!${NC}"
    sleep 2
    loader
}

# Start the script
loader

