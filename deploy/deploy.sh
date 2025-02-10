#!/bin/bash

# Load deployment environment
if [ ! -f ".env.deploy" ]; then
    echo "Error: .env.deploy file not found"
    echo "Please copy .env.deploy.example to .env.deploy and update the values"
    exit 1
fi

source .env.deploy

# Validate required variables
if [ -z "$DEPLOY_USER" ]; then
    echo "Error: DEPLOY_USER is not set in .env.deploy"
    exit 1
fi

if [ -z "$DEPLOY_HOST" ]; then
    echo "Error: DEPLOY_HOST is not set in .env.deploy"
    exit 1
fi

# Construct SSH connection string
SSH_CONNECTION="${DEPLOY_USER}@${DEPLOY_HOST}"

# Function to check remote prerequisites
check_prerequisites() {
    echo "Checking prerequisites on remote host..."
    
    # Check SSH connection
    if ! ssh -q $SSH_CONNECTION exit; then
        echo "❌ Error: Cannot connect to remote host"
        echo "Prerequisites:"
        echo "1. SSH access to the remote host"
        echo "2. SSH key-based authentication configured"
        echo "3. User ($DEPLOY_USER) exists on remote host"
        exit 1
    fi
    echo "✓ SSH connection successful"
    
    # Check if user has sudo access
    if ! ssh $SSH_CONNECTION "sudo -n true" 2>/dev/null; then
        echo "❌ Error: User $DEPLOY_USER needs password-less sudo access"
        echo "Run this on the remote host:"
        echo "    echo '$DEPLOY_USER ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/$DEPLOY_USER"
        exit 1
    fi
    echo "✓ Sudo access verified"
    
    # Check if Docker is installed, if not install it
    if ! ssh $SSH_CONNECTION "command -v docker >/dev/null 2>&1"; then
        echo "🔄 Docker not found, installing..."
        ssh $SSH_CONNECTION '
            # Update package list
            sudo apt-get update
            
            # Install dependencies
            sudo apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release
                
            # Add Docker GPG key
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Add Docker repository
            echo \
              "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              
            # Install Docker
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            
            # Add current user to docker group
            sudo usermod -aG docker $USER
            
            # Start and enable Docker service
            sudo systemctl start docker
            sudo systemctl enable docker
        '
        echo "✓ Docker installed successfully"
    else
        echo "✓ Docker is installed"
    fi
    
    # Check if Docker daemon is running
    if ! ssh $SSH_CONNECTION "sudo systemctl is-active --quiet docker"; then
        echo "🔄 Starting Docker daemon..."
        ssh $SSH_CONNECTION "sudo systemctl start docker"
    fi
    echo "✓ Docker daemon is running"
    
    # Check if user is in docker group
    if ! ssh $SSH_CONNECTION "groups" | grep -q docker; then
        echo "🔄 Adding user to docker group..."
        ssh $SSH_CONNECTION "sudo usermod -aG docker $USER"
        echo "✓ User added to docker group"
        echo "Note: You may need to reconnect to the server for group changes to take effect"
    else
        echo "✓ User has Docker permissions"
    fi
    
    # Check available disk space (need at least 5GB)
    AVAILABLE_SPACE=$(ssh $SSH_CONNECTION "df -BG / | awk 'NR==2 {print \$4}' | tr -d 'G'")
    if [ "$AVAILABLE_SPACE" -lt 5 ]; then
        echo "❌ Error: Insufficient disk space. Need at least 5GB, have ${AVAILABLE_SPACE}GB"
        exit 1
    fi
    echo "✓ Sufficient disk space available"
    
    # Check if required ports are available
    if ! ssh $SSH_CONNECTION "command -v netstat >/dev/null 2>&1"; then
        echo "🔄 Installing net-tools for port checking..."
        ssh $SSH_CONNECTION "sudo apt-get update && sudo apt-get install -y net-tools"
    fi
    
    if ! ssh $SSH_CONNECTION "! netstat -ln | grep -E ':80|:443' >/dev/null 2>&1"; then
        echo "❌ Error: Ports 80 or 443 are already in use"
        echo "Free up these ports before deploying"
        exit 1
    fi
    echo "✓ Required ports (80, 443) are available"
    
    echo "✨ All prerequisites met!"
}

# Check prerequisites before proceeding
check_prerequisites

# Function to check if a container exists and is running
container_is_running() {
    local container_name="$1"
    ssh $SSH_CONNECTION "docker ps -q -f name=^/${container_name}$" | grep -q .
}

# Function to check if a container exists (running or not)
container_exists() {
    local container_name="$1"
    ssh $SSH_CONNECTION "docker ps -a -q -f name=^/${container_name}$" | grep -q .
}

# Function to check if a network exists
network_exists() {
    local network_name="$1"
    ssh $SSH_CONNECTION "docker network ls -q -f name=^${network_name}$" | grep -q .
}

# Function to check if a directory exists
remote_dir_exists() {
    local dir_path="$1"
    ssh $SSH_CONNECTION "[ -d \"$dir_path\" ]"
}

# Function to check if a file exists
remote_file_exists() {
    local file_path="$1"
    ssh $SSH_CONNECTION "[ -f \"$file_path\" ]"
}

# Create Docker network if it doesn't exist
echo "Checking Docker network..."
if ! network_exists "web"; then
    echo "Creating Docker network 'web'..."
    ssh $SSH_CONNECTION "docker network create web"
else
    echo "Docker network 'web' already exists"
fi

# Setup Traefik
echo "Setting up Traefik..."
if ! container_is_running "traefik"; then
    echo "Starting Traefik..."
    if container_exists "traefik"; then
        echo "Removing existing Traefik container..."
        ssh $SSH_CONNECTION "docker rm -f traefik"
    fi
    
    ssh $SSH_CONNECTION "
        docker run -d \
            --name traefik \
            --network web \
            --restart unless-stopped \
            -p 80:80 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            traefik:v2.10 \
            --api.insecure=false \
            --providers.docker=true \
            --providers.docker.exposedbydefault=false \
            --entrypoints.web.address=:80 \
            --log.level=INFO
    "
else
    echo "Traefik is already running"
fi

# Setup MySQL
echo "Setting up MySQL..."
if ! container_is_running "mysql-ghost"; then
    echo "Starting MySQL..."
    if container_exists "mysql-ghost"; then
        echo "Removing existing MySQL container..."
        ssh $SSH_CONNECTION "docker rm -f mysql-ghost"
    fi
    
    # Ensure MySQL data directory exists
    if ! remote_dir_exists "/var/lib/mysql"; then
        echo "Creating MySQL data directory..."
        ssh $SSH_CONNECTION "sudo mkdir -p /var/lib/mysql"
    fi
    
    ssh $SSH_CONNECTION "
        docker run -d \
            --name mysql-ghost \
            --network web \
            --restart unless-stopped \
            -v /var/lib/mysql:/var/lib/mysql \
            -e MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD \
            -e MYSQL_DATABASE=$DB_NAME \
            -e MYSQL_USER=$DB_USER \
            -e MYSQL_PASSWORD=$DB_PASSWORD \
            mysql:8.0
    "
    
    echo "Waiting for MySQL to initialize..."
    sleep 15
else
    echo "MySQL is already running"
fi

# Deploy Ghost
echo "Deploying Ghost..."
if container_is_running "ghost"; then
    # Check if we need to update the container
    echo "Ghost container already exists, checking for updates..."
    
    # Get current container config
    CURRENT_URL=$(ssh $SSH_CONNECTION "docker inspect ghost | grep -A1 'url=' | tail -n1" | tr -d ' ",' | cut -d= -f2)
    CURRENT_DB_USER=$(ssh $SSH_CONNECTION "docker inspect ghost | grep -A1 'database__connection__user=' | tail -n1" | tr -d ' ",' | cut -d= -f2)
    
    # Compare essential settings
    if [ "$CURRENT_URL" != "$GHOST_URL" ] || \
       [ "$CURRENT_DB_USER" != "$DB_USER" ]; then
        echo "Configuration changes detected, updating Ghost container..."
        ssh $SSH_CONNECTION "docker rm -f ghost"
    else
        echo "Ghost container is up-to-date"
        exit 0
    fi
fi

# Extract hostname without protocol
GHOST_HOSTNAME=$(echo "$GHOST_URL" | sed 's|^[^/]*//||')

# Deploy Ghost with clean configuration
ssh $SSH_CONNECTION "
    docker run -d \
        --name ghost \
        --network web \
        --restart unless-stopped \
        -e url=$GHOST_URL \
        -e server__port=2368 \
        -e server__host='0.0.0.0' \
        -e mail__from=$MAIL_FROM \
        -e database__client=mysql \
        -e database__connection__host=mysql-ghost \
        -e database__connection__user=$DB_USER \
        -e database__connection__password=$DB_PASSWORD \
        -e database__connection__database=$DB_NAME \
        -e mail__transport=$MAIL_TRANSPORT \
        -e mail__options__host=$MAIL_HOST \
        -e mail__options__port=$MAIL_PORT \
        -e mail__options__auth__user=$MAIL_USER \
        -e mail__options__auth__pass=$MAIL_PASSWORD \
        -l 'traefik.enable=true' \
        -l 'traefik.http.routers.ghost.rule=Host(\`'$GHOST_HOSTNAME'\`)' \
        -l 'traefik.http.services.ghost.loadbalancer.server.port=2368' \
        ghost:5-alpine
"

# Wait for Ghost to start
sleep 5

# Check container logs
echo "Checking Ghost container logs..."
ssh $SSH_CONNECTION "docker logs ghost"

echo "✨ Deployment complete!"
echo "Your Ghost blog is now available at: $GHOST_URL"
echo ""
echo "Next steps:"
echo "1. Visit $GHOST_URL/ghost to set up your admin account"
echo "2. To install a custom theme:"
echo "   a. Use 'poltertools package' to create a theme package"
echo "   b. Go to Ghost Admin -> Settings -> Design"
echo "   c. Click 'Change theme' and upload your theme package"
echo ""
echo "For more information about theme development and customization,"
echo "visit: https://ghost.org/docs/themes/" 