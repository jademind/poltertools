#!/bin/bash

# Function to check if GHOST_THEMES_DIR is set, and use a default if not
check_env_variable() {
  if [ -z "$GHOST_THEMES_DIR" ]; then
    echo "Warning: GHOST_THEMES_DIR environment variable is not set."
    echo "The default directory './content/themes' will be used."
    GHOST_THEMES_DIR="./content/themes"
  fi

  if [ ! -d "$GHOST_THEMES_DIR" ]; then
    echo "Error: The directory '$GHOST_THEMES_DIR' does not exist."
    exit 1
  fi
}

# Function to check which docker compose command is available
get_docker_compose_cmd() {
  if command -v docker-compose &> /dev/null; then
    echo "docker-compose"
  else
    echo "docker compose"
  fi
}

# Function to display access URLs
show_access_urls() {
  echo ""
  echo "🎉 Ghost is running!"
  echo "📝 Access your blog at: http://localhost:2368"
  echo "⚙️  Access Ghost Admin at: http://localhost:2368/ghost"
  echo ""
}

# Function to get current user's UID and GID
get_user_ids() {
  export USER_ID=$(id -u)
  export GROUP_ID=$(id -g)
}

# Function to fix theme directory permissions
fix_permissions() {
  local themes_dir="$1"
  echo "Setting correct permissions for Ghost directories..."
  
  # Create a temporary container to fix permissions
  docker_cmd=$(get_docker_compose_cmd)
  
  # First create the volume if it doesn't exist
  $docker_cmd up -d ghost
  $docker_cmd stop ghost
  
  # Fix permissions and create necessary directories
  $docker_cmd run --rm \
    -v ghost_content:/var/lib/ghost/content \
    -v "$(cd "$(dirname "$themes_dir")"; pwd)/$(basename "$themes_dir")":/var/lib/ghost/content/themes \
    --user root \
    ghost:latest \
    sh -c '
      mkdir -p /var/lib/ghost/content/logs && \
      mkdir -p /var/lib/ghost/content/data && \
      mkdir -p /var/lib/ghost/content/images && \
      mkdir -p /var/lib/ghost/content/files && \
      mkdir -p /var/lib/ghost/content/themes && \
      chown -R node:node /var/lib/ghost/content && \
      chmod -R u+rwX,g+rwX,o+rX /var/lib/ghost/content && \
      find /var/lib/ghost/content -type d -exec chmod u+rwx,g+rwx {} \; && \
      find /var/lib/ghost/content/logs -type d -exec chmod 777 {} \; && \
      touch /var/lib/ghost/content/logs/http___localhost_2368_development.error.log && \
      chmod 666 /var/lib/ghost/content/logs/http___localhost_2368_development.error.log
    '
}

# Function to start Docker Compose
run_docker_compose() {
  check_env_variable
  echo "Starting Ghost"
  docker_cmd=$(get_docker_compose_cmd)
  
  # Fix permissions before starting
  fix_permissions "$GHOST_THEMES_DIR"
  
  # Set user IDs
  get_user_ids
  $docker_cmd up -d
  
  # Wait a few seconds for the container to initialize
  echo "Waiting for Ghost to start..."
  sleep 5
  
  # Check if the container is actually running
  if $docker_cmd ps | grep -q "ghost"; then
    show_access_urls
  else
    echo "❌ Error: Ghost container failed to start properly."
    echo "Check the logs with: $docker_cmd logs"
  fi
}

# Function to stop Docker Compose
stop_docker_compose() {
  echo "Stopping Ghost"
  docker_cmd=$(get_docker_compose_cmd)
  unset GHOST_USER_IDS
  $docker_cmd down
}

# Function to package the theme into a ZIP file
package_theme() {
  check_env_variable
  theme_name=$(basename "$GHOST_THEMES_DIR")
  timestamp=$(date +%Y%m%d-%H%M%S)
  zip_file="${theme_name}-${timestamp}.zip"

  echo "Packaging theme: $theme_name"
  if cd "$GHOST_THEMES_DIR"; then
    zip -r "../$zip_file" .
    echo "Theme packaged as: $zip_file"
  else
    echo "Failed to access directory: $GHOST_THEMES_DIR"
  fi
}

# Main script logic
case $1 in
  start)
    run_docker_compose
    ;;
  stop)
    stop_docker_compose
    ;;
  package)
    package_theme
    ;;
  *)
    echo "Usage: poltertools [start|stop|package]"
    ;;
esac
