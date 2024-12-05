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
      chmod 666 /var/lib/ghost/content/logs/http___localhost_2368_development.error.log && \
      # Ensure theme directory is readable
      chmod -R 755 /var/lib/ghost/content/themes
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

# Function to clean up Docker volumes
clean_docker_volumes() {
  echo "Cleaning up Ghost volumes..."
  docker_cmd=$(get_docker_compose_cmd)
  
  # Stop containers if they're running
  $docker_cmd down
  
  # Remove volumes
  echo "Removing Docker volumes..."
  docker volume rm ghost_content ghost_db 2>/dev/null || true
  echo "✨ Cleanup complete"
}

# Function to restart Ghost container
restart_ghost() {
  echo "Restarting Ghost..."
  docker_cmd=$(get_docker_compose_cmd)
  
  # Restart only the ghost service
  $docker_cmd restart ghost
  
  # Wait a few seconds for the container to initialize
  echo "Waiting for Ghost to restart..."
  sleep 5
  
  # Check if the container is running
  if $docker_cmd ps | grep -q "ghost"; then
    show_access_urls
  else
    echo "❌ Error: Ghost container failed to restart properly."
    echo "Check the logs with: $docker_cmd logs"
  fi
}

# Function to show help message
show_help() {
  echo "Poltertools - Ghost Theme Development Helper"
  echo ""
  echo "Usage: poltertools [command]"
  echo ""
  echo "Commands:"
  echo "  start     Start Ghost instance with your theme directory mounted"
  echo "  stop      Stop the Ghost instance and related containers"
  echo "  restart   Restart Ghost (needed after locale file changes)"
  echo "  clean     Remove all Docker volumes for a fresh start"
  echo "  package   Create a ZIP file of your theme for deployment"
  echo "  help      Show this help message"
  echo ""
  echo "Examples:"
  echo "  poltertools start              # Start Ghost with your theme"
  echo "  poltertools restart            # Restart after locale changes"
  echo "  poltertools clean && start     # Start fresh"
  echo ""
  echo "Environment Variables:"
  echo "  GHOST_THEMES_DIR   Path to your themes directory"
  echo "                     Default: ./content/themes"
  echo ""
  echo "Live Reload Behavior:"
  echo "  • Immediate changes (no restart needed):"
  echo "    - Template files (.hbs)"
  echo "    - CSS/SCSS files"
  echo "    - JavaScript files"
  echo "    - Images and assets"
  echo ""
  echo "  • Changes requiring restart:"
  echo "    - Locale files (.json)"
  echo "    - Theme configuration"
  echo "    - Ghost settings"
}

# Main script logic
case $1 in
  start)
    run_docker_compose
    ;;
  stop)
    stop_docker_compose
    ;;
  restart)
    restart_ghost
    ;;
  clean)
    clean_docker_volumes
    ;;
  package)
    package_theme
    ;;
  help)
    show_help
    ;;
  *)
    echo "Usage: poltertools [start|stop|restart|clean|package|help]"
    echo "Run 'poltertools help' for detailed information"
    ;;
esac
