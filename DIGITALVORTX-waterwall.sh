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
    menu "| 1 - INSTALL CORE \n| 2  - Config HalfDuplex Tunnel \n| 3  - Status Tunnel  \n| 4  - Start Tunnel  \n| 5  - Stop Tunnel  \n| 9 - Uninstall \n| 0  - Exit"
    
    read -p "Enter option number: " choice
    case $choice in
    1)
        install_core
        ;;  
    2)
        halfduplex_config
        ;;
    3)
        check_status
        ;;
    4)
        start_tunnel
        ;;
    5)
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
            
            local ports=""
            for ((port=start_port; port<=end_port; port++)); do
                if [ -z "$ports" ]; then
                    ports="$port"
                else
                    ports="$ports, $port"
                fi
            done
            echo "[$ports]"
        else
            # Single port in array format [80]
            echo "[$input]"
        fi
    # Check if it's a range with dash (e.g., 8447-8450)
    elif [[ "$input" == *-* ]]; then
        local start_port=${input%-*}
        local end_port=${input#*-}
        local ports=""
        for ((port=start_port; port<=end_port; port++)); do
            if [ -z "$ports" ]; then
                ports="$port"
            else
                ports="$ports, $port"
            fi
        done
        echo "[$ports]"
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
        "multiport-backend": "iptables"
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
    echo -e "\n${GREEN}✓ Iran server configuration created successfully!${NC}"
    echo -e "${GREEN}Configuration saved to: $WATERWALL_DIR/dev-ir.json${NC}\n"
    
    read -p "Press Enter to continue..."
    init
}

config_foreign_server() {
    echo -e "\n${YELLOW}=== Kharej/Foreign Server Configuration ===${NC}\n"
    
    # Get listener settings
    read -p "Enter listener address [0.0.0.0]: " listener_address
    listener_address=${listener_address:-0.0.0.0}
    
    echo -e "${YELLOW}Enter listener ports (single: 8443, multiple: 8443,8444,8445, range: 8443-8446, or array: [8443,8446] or [3000,2000]):${NC}"
    read -p "Listener ports: " listener_ports
    listener_ports=$(parse_ports "$listener_ports")
    
    # Get Iran server IP
    read -p "Enter IRAN Server IP: " iran_ip
    if [ -z "$iran_ip" ]; then
        echo -e "${RED}Error: IRAN Server IP is required${NC}"
        sleep 2
        config_foreign_server
        return
    fi
    
    echo -e "${YELLOW}Enter connector ports to IRAN Server (single: 8447, multiple: 8447,8448,8449, range: 8447-8450, or array: [8447,8450]):${NC}"
    read -p "Connector ports: " connector_ports
    connector_ports=$(parse_ports "$connector_ports")
    
    # Create config file in /waterwall directory
    sudo mkdir -p "$WATERWALL_DIR"
    cat <<EOL | sudo tee "$WATERWALL_DIR/dev-ir.json" > /dev/null
{
  "name": "foreign_server_config",
  "nodes": [
    {
      "name": "foreign_multi_port_listener",
      "type": "TcpListener",
      "settings": {
        "address": "$listener_address",
        "port": $listener_ports,
        "nodelay": true,
        "multiport-backend": "iptables"
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
        "address": "$iran_ip",
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
    echo -e "\n${GREEN}✓ Foreign server configuration created successfully!${NC}"
    echo -e "${GREEN}Configuration saved to: $WATERWALL_DIR/dev-ir.json${NC}\n"
    
    read -p "Press Enter to continue..."
    init
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
    cat <<EOL > core.json
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
    
    # Check if already running
    if screen -list | grep -q "WaterWall"; then
        echo -e "${YELLOW}WaterWall is already running!${NC}"
        sleep 2
        init
        return
    fi
    
    # Install screen if not available
    if ! command -v screen &> /dev/null; then
        echo "Screen is not installed. Installing..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y screen
        elif command -v yum &> /dev/null; then
            sudo yum install -y screen
        else
            echo -e "${RED}Error: Cannot install screen. Please install manually.${NC}"
            sleep 2
            init
            return
        fi
    fi
    
    # Start in screen from /waterwall directory
    cd "$WATERWALL_DIR" || {
        echo -e "${RED}Error: Cannot access $WATERWALL_DIR${NC}"
        sleep 2
        init
        return
    }
    
    screen -dmS WaterWall ./Waterwall
    cd "$cur_dir"
    
    echo -e "${GREEN}WaterWall tunnel started in screen session!${NC}"
    echo -e "${YELLOW}To view logs, use: screen -r WaterWall${NC}"
    sleep 2
    init
}

stop_tunnel() {
    if screen -list | grep -q "WaterWall"; then
        screen -X -S WaterWall quit
        echo -e "${GREEN}WaterWall tunnel stopped!${NC}"
    else
        echo -e "${YELLOW}WaterWall tunnel is not running.${NC}"
    fi
    sleep 2
    init
}

check_status() {
    clear
    echo -e "${YELLOW}=== WaterWall Status ===${NC}\n"
    echo -e "${BLUE}Installation Directory: $WATERWALL_DIR${NC}\n"
    
    if [ -f "$WATERWALL_DIR/core.json" ]; then
        echo -e "${GREEN}Core: Installed${NC}"
    else
        echo -e "${RED}Core: Not installed${NC}"
    fi
    
    if [ -f "$WATERWALL_DIR/dev-ir.json" ]; then
        echo -e "${GREEN}Tunnel Config: Exists${NC}"
        echo -e "\n${YELLOW}Configuration:${NC}"
        cat "$WATERWALL_DIR/dev-ir.json" | jq '.' 2>/dev/null || cat "$WATERWALL_DIR/dev-ir.json"
    else
        echo -e "${RED}Tunnel Config: Not found${NC}"
    fi
    
    echo ""
    if screen -list | grep -q "WaterWall"; then
        echo -e "${GREEN}Tunnel Status: Running${NC}"
        screen -list | grep WaterWall
    else
        echo -e "${RED}Tunnel Status: Stopped${NC}"
    fi
    
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
    
    # Stop tunnel
    if screen -list | grep -q "WaterWall"; then
        screen -X -S WaterWall quit
        echo -e "${GREEN}Tunnel stopped${NC}"
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

