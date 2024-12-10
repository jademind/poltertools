#!/bin/bash

# Function to check which docker compose command is available
get_docker_compose_cmd() {
  if command -v docker-compose &> /dev/null; then
    echo "docker-compose"
  else
    echo "docker compose"
  fi
}

# Function to generate required secrets
generate_secrets() {
  echo "Generating secrets..."
  SECRET_KEY_BASE=$(openssl rand -base64 48)
  # Generate random database password
  DB_PASSWORD=$(openssl rand -base64 24)
}

# Function to clone plausible repository
clone_repository() {
  local pl_version="$1"
  local pl_dir="$2"
  
  echo "Cloning Plausible Analytics repository..."
  git clone -b "$pl_version" --single-branch https://github.com/plausible/community-edition "$pl_dir"
}

# Function to create environment configuration
create_env_config() {
  local pl_dir="$1"
  local base_url="$2"
  local http_port="$3"
  local https_port="$4"
  local local_ip=$(get_local_ip)
  local hostname=$(echo "$base_url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
  
  echo "Configuring environment variables..."
  cat <<EOF > "$pl_dir/.env"
BASE_URL=$base_url
SECRET_KEY_BASE=$SECRET_KEY_BASE
HTTP_PORT=$http_port
HTTPS_PORT=$https_port
# Socket configuration for both local development and production
SOCKET_CHECK_ORIGIN=["http://localhost:$http_port", "http://$local_ip:$http_port", "$base_url", "https://$hostname"]
# Database configuration with secure password
DATABASE_URL=postgres://plausible:${DB_PASSWORD}@plausible_db:5432/plausible_db
POSTGRES_PASSWORD=${DB_PASSWORD}
# SMTP configuration (uncomment and configure for production)
# SMTP_HOST_ADDR=smtp.your-email-server.com
# SMTP_HOST_PORT=587
# SMTP_USER_NAME=your-username
# SMTP_PASSWORD=your-password
# SMTP_HOST_SSL_ENABLED=true
# SMTP_RETRIES=2
# MAILER_EMAIL=your-from-email@your-domain.com
# Additional security settings for production
# DISABLE_REGISTRATION=true
EOF

  # Create a sample production config that users can reference
  cat <<EOF > "$pl_dir/.env.production.sample"
BASE_URL=https://analytics.your-domain.com
SECRET_KEY_BASE=$SECRET_KEY_BASE
# Production socket configuration
SOCKET_CHECK_ORIGIN=["https://analytics.your-domain.com"]
# Database configuration
DATABASE_URL=postgres://postgres:postgres@plausible_db:5432/plausible_db
# SMTP configuration
SMTP_HOST_ADDR=smtp.your-email-server.com
SMTP_HOST_PORT=587
SMTP_USER_NAME=your-username
SMTP_PASSWORD=your-password
SMTP_HOST_SSL_ENABLED=true
SMTP_RETRIES=2
MAILER_EMAIL=your-from-email@your-domain.com
# Security settings
DISABLE_REGISTRATION=true
EOF
}

# Function to create docker compose override
create_compose_override() {
  local pl_dir="$1"
  local http_port="$2"
  local https_port="$3"
  
  echo "Creating Docker Compose override file..."
  cat <<EOF > "$pl_dir/compose.override.yml"
services:
  plausible:
    ports:
      - $http_port:80
      - $https_port:443
    depends_on:
      - plausible_db
      
  plausible_db:
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_USER=plausible
      - POSTGRES_DB=plausible_db
EOF
}

# Function to get local IP address
get_local_ip() {
  # Try to get IP address, fallback to localhost if not found
  local ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [ -z "$ip" ]; then
    ip="localhost"
  fi
  echo "$ip"
}

# Function to show access URLs
show_access_urls() {
  local base_url="$1"
  local http_port="$2"
  local https_port="$3"
  local local_ip=$(get_local_ip)
  
  echo ""
  echo "🎉 Plausible Analytics is running!"
  echo ""
  echo "Configured domain:"
  echo "📊 $base_url"
  echo ""
  echo "Local access URLs:"
  if [ "$http_port" = "80" ]; then
    echo "📊 http://$local_ip"
  else
    echo "📊 http://$local_ip:$http_port"
  fi
  if [ "$https_port" = "443" ]; then
    echo "🔒 https://$local_ip"
  else
    echo "🔒 https://$local_ip:$https_port"
  fi
  echo ""
  echo "Note: For HTTPS to work, you need to configure SSL certificates"
  echo ""
}

# Function to start plausible services
start_plausible() {
  local pl_dir="$1"
  local http_port="$2"
  local https_port="$3"
  local base_url="$4"
  
  echo "Starting Plausible services..."
  docker_cmd=$(get_docker_compose_cmd)
  cd "$pl_dir" && $docker_cmd up -d
  show_access_urls "$base_url" "$http_port" "$https_port"
}

# Function to stop plausible services
stop_plausible() {
  local pl_dir="$1"
  echo "Stopping Plausible services..."
  docker_cmd=$(get_docker_compose_cmd)
  cd "$pl_dir" && $docker_cmd down
  echo "✨ Plausible services stopped"
}

# Function to show help message
show_help() {
  echo "Plausible Analytics Setup Helper"
  echo ""
  echo "Usage: setup_plausible.sh [command] [options]"
  echo ""
  echo "Commands:"
  echo "  setup      Set up a new Plausible Analytics instance"
  echo "  start      Start an existing Plausible instance"
  echo "  stop       Stop the running Plausible instance"
  echo "  clean      Remove existing installation and volumes"
  echo "  help       Show this help message"
  echo ""
  echo "Setup Options:"
  echo "  --version     Plausible version to install (default: v2.1.4)"
  echo "  --dir         Installation directory (default: plausible-ce)"
  echo "  --base-url    Base URL for Plausible (default: https://plausible.example.com)"
  echo "  --http-port   HTTP port (default: 80)"
  echo "  --https-port  HTTPS port (default: 443)"
  echo ""
  echo "Examples:"
  echo "  setup_plausible.sh setup --base-url https://analytics.mysite.com"
  echo "  setup_plausible.sh start"
  echo "  setup_plausible.sh stop"
  echo ""
  echo "Note: The setup command is required for first-time installation."
}

# Function to clean up existing installation
cleanup_installation() {
  local pl_dir="$1"
  echo "Cleaning up any existing installation..."
  
  # Stop containers if running
  if [ -d "$pl_dir" ]; then
    docker_cmd=$(get_docker_compose_cmd)
    cd "$pl_dir" && $docker_cmd down -v 2>/dev/null || true
    cd - > /dev/null
  fi
  
  # Remove installation directory
  if [ -d "$pl_dir" ]; then
    echo "Removing existing directory: $pl_dir"
    rm -rf "$pl_dir"
  fi
  
  # Remove any existing volumes
  echo "Removing Docker volumes..."
  docker volume rm plausible_db_data plausible_event_data 2>/dev/null || true
  
  echo "✨ Cleanup complete"
}

# Main setup function
setup_plausible() {
  # Default values
  local PL_VERSION="v2.1.4"
  local PL_DIR="plausible-ce"
  local BASE_URL="https://plausible.example.com"
  local HTTP_PORT=80
  local HTTPS_PORT=443
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --version)
        PL_VERSION="$2"
        shift 2
        ;;
      --dir)
        PL_DIR="$2"
        shift 2
        ;;
      --base-url)
        BASE_URL="$2"
        shift 2
        ;;
      --http-port)
        HTTP_PORT="$2"
        shift 2
        ;;
      --https-port)
        HTTPS_PORT="$2"
        shift 2
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
  
  echo "Starting setup for Plausible Analytics Community Edition..."
  
  # Clean up any existing installation
  cleanup_installation "$PL_DIR"
  
  # Generate required secrets
  generate_secrets
  
  # Clone repository
  clone_repository "$PL_VERSION" "$PL_DIR"
  
  # Create configurations
  create_env_config "$PL_DIR" "$BASE_URL" "$HTTP_PORT" "$HTTPS_PORT"
  create_compose_override "$PL_DIR" "$HTTP_PORT" "$HTTPS_PORT"
  
  # Start services
  start_plausible "$PL_DIR" "$HTTP_PORT" "$HTTPS_PORT" "$BASE_URL"
  
  echo "✨ Setup complete!"
}

# Execute main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -e  # Exit on any error
  
  # Default values for start/stop commands
  PL_DIR="plausible-ce"
  BASE_URL="https://plausible.example.com"
  HTTP_PORT=80
  HTTPS_PORT=443
  
  # Load environment file if it exists
  if [ -f "$PL_DIR/.env" ]; then
    source "$PL_DIR/.env"
  fi
  
  # Process commands
  case $1 in
    setup)
      shift  # Remove 'setup' from the arguments
      setup_plausible "$@"
      ;;
    start)
      start_plausible "$PL_DIR" "$HTTP_PORT" "$HTTPS_PORT" "$BASE_URL"
      ;;
    stop)
      stop_plausible "$PL_DIR"
      ;;
    clean)
      cleanup_installation "$PL_DIR"
      ;;
    help)
      show_help
      ;;
    *)
      echo "Usage: setup_plausible.sh [setup|start|stop|clean|help] [options]"
      echo "Run 'setup_plausible.sh help' for detailed information"
      exit 1
      ;;
  esac
fi
