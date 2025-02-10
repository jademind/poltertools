#!/bin/bash

# Configuration variables
CONFIG_FILE="poltertools.config"
DATE_FORMAT=$(date +%Y%m%d_%H%M%S)
DEBUG=false

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found"
        echo "Please copy poltertools.config.example to poltertools.config and update the values"
        exit 1
    fi
    source "$CONFIG_FILE"
}

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
  
  # List all directories in the themes directory
  echo "Available themes:"
  themes=()
  index=1
  
  # Store themes in an array and display them with numbers
  while IFS= read -r dir; do
    # Skip hidden directories (starting with .)
    if [ -d "$dir" ] && [[ ! "$(basename "$dir")" =~ ^\. ]]; then
      themes+=("$dir")
      echo "$index) $(basename "$dir")"
      ((index++))
    fi
  done < <(find "$GHOST_THEMES_DIR" -maxdepth 1 -mindepth 1 -type d)
  
  # Check if any themes were found
  if [ ${#themes[@]} -eq 0 ]; then
    echo "❌ No themes found in $GHOST_THEMES_DIR"
    exit 1
  fi
  
  # Prompt user to select a theme
  echo ""
  read -p "Select a theme number (1-${#themes[@]}): " selection
  
  # Validate selection
  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#themes[@]} ]; then
    echo "❌ Invalid selection"
    exit 1
  fi
  
  # Get the selected theme path and name
  selected_theme="${themes[$((selection-1))]}"
  theme_name=$(basename "$selected_theme")
  timestamp=$(date +%Y%m%d-%H%M%S)
  zip_file="${theme_name}-${timestamp}.zip"
  ignore_file=".package-ignore"
  
  echo "Packaging theme: $theme_name"
  
  # Store the original directory
  original_dir=$(pwd)
  
  if cd "$selected_theme"; then
    # Create a temporary exclusion pattern file for zip
    temp_exclude=$(mktemp)
    
    # Read .package-ignore and format each line for zip's exclude pattern
    while IFS= read -r pattern || [ -n "$pattern" ]; do
      # Skip empty lines and comments
      [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
      # Add proper wildcards for directory patterns
      if [[ "$pattern" == *"/" ]]; then
        echo "$pattern*" >> "$temp_exclude"
      else
        # Handle both file and directory patterns
        echo "$pattern" >> "$temp_exclude"
        echo "*/$pattern" >> "$temp_exclude"  # Match pattern in subdirectories
      fi
    done < "$original_dir/$ignore_file"
    
    # Debug output
    echo "Using the following exclusion patterns:"
    cat "$temp_exclude"
    
    # Create zip file with exclusions
    if zip -r "$original_dir/$zip_file" . -x@"$temp_exclude"; then
      echo "✨ Theme packaged successfully as: $zip_file"
    else
      echo "❌ Error creating zip file"
      cd "$original_dir"
      rm "$temp_exclude"
      exit 1
    fi
    
    # Clean up temporary file
    cd "$original_dir"
    rm "$temp_exclude"
  else
    echo "Failed to access directory: $selected_theme"
    exit 1
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

# Backup Functions
backup_posts() {
    local backup_path="$1"
    local page=1
    local has_more=true
    
    echo "Backing up posts..."
    
    while [ "$has_more" = true ]; do
        local response=$(curl -s \
            -H "Accept-Version: v5.0" \
            "${GHOST_URL}/ghost/api/content/posts/?key=${GHOST_API_KEY}&limit=100&page=$page&include=authors,tags")
        
        # Check if we got valid JSON
        if ! echo "$response" | jq . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response"
            return 1
        fi
        
        # Save this page of posts
        echo "$response" | jq . > "$backup_path/posts/page_${page}.json"
        
        # Check if there are more pages
        local total=$(echo "$response" | jq -r '.meta.pagination.total')
        local current_count=$((page * 100))
        
        if [ "$current_count" -ge "$total" ]; then
            has_more=false
        fi
        
        ((page++))
    done
    
    echo "✓ Posts backed up"
}

backup_images() {
    local backup_path="$1"
    local posts_dir="$backup_path/posts"
    local images_dir="$backup_path/images"
    
    echo "Backing up images..."
    
    # Create a list of all image URLs from posts
    for post_file in "$posts_dir"/*.json; do
        # Extract image URLs from post content and feature images
        local urls=$(jq -r '.posts[] | [.feature_image, (.html | scan("src=\"([^\"]+)\"") | .[])] | .[]' "$post_file" | grep -v "^null$")
        
        while read -r url; do
            if [ -n "$url" ]; then
                # Extract filename from URL
                local filename=$(basename "$url")
                # Download image if it doesn't exist
                if [ ! -f "$images_dir/$filename" ]; then
                    curl -s "$url" -o "$images_dir/$filename"
                fi
            fi
        done <<< "$urls"
    done
    
    echo "✓ Images backed up"
}

backup_themes() {
    local backup_path="$1"
    local themes_dir="$backup_path/themes"
    
    echo "Backing up themes..."
    
    # If using Docker, copy from the volume
    if docker volume ls | grep -q "ghost_content"; then
        docker run --rm \
            -v ghost_content:/content \
            -v "$(pwd)/$backup_path/themes:/backup" \
            alpine \
            sh -c "cp -r /content/themes/* /backup/"
    else
        # Try local theme directory
        cp -r "${GHOST_THEMES_DIR:-./content/themes}"/* "$themes_dir/"
    fi
    
    echo "✓ Themes backed up"
}

create_backup_dirs() {
    local backup_path="$BACKUP_DIR/$DATE_FORMAT"
    mkdir -p "$backup_path"/{posts,images,files,themes}
    echo "$backup_path"
}

create_archive() {
    local backup_path="$1"
    local archive_name="ghost_backup_$DATE_FORMAT.tar.gz"
    
    echo "Creating compressed archive..."
    tar -czf "$BACKUP_DIR/$archive_name" -C "$BACKUP_DIR" "$(basename "$backup_path")"
    
    echo "✓ Backup archive created: $BACKUP_DIR/$archive_name"
    
    # Cleanup uncompressed files
    rm -rf "$backup_path"
}

perform_backup() {
    local skip_images=false
    local skip_themes=false
    
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --no-images) skip_images=true ;;
            --no-themes) skip_themes=true ;;
            *) echo "Unknown parameter: $1"; return 1 ;;
        esac
        shift
    done
    
    local backup_path=$(create_backup_dirs)
    backup_posts "$backup_path"
    
    if [ "$skip_images" = false ]; then
        backup_images "$backup_path"
    fi
    
    if [ "$skip_themes" = false ]; then
        backup_themes "$backup_path"
    fi
    
    create_archive "$backup_path"
}

list_backups() {
    echo "Available backups:"
    if [ -d "$BACKUP_DIR" ]; then
        # Get the list of backups sorted by date (newest first)
        for backup in $(ls -t "$BACKUP_DIR"/ghost_backup_*.tar.gz 2>/dev/null); do
            echo "$(basename "$backup") ($(du -h "$backup" | cut -f1))"
        done || echo "No backups found in $BACKUP_DIR"
    else
        echo "Backup directory $BACKUP_DIR does not exist"
    fi
}

# Helper function for base64 URL encoding
base64_url_encode() {
    declare input=${1:-$(</dev/stdin)}
    printf '%s' "${input}" | base64 | tr -d '=' | tr '+' '-' | tr '/' '_'
}

# Function to generate JWT token
generate_jwt_token() {
    local key_id="$1"
    local key_secret="$2"
    
    # Get the current Unix timestamp and ensure it's an integer
    local now=$(printf "%.0f" "$(date +%s)")
    local five_mins=$((now + 300))
    
    # Create JWT header with kid
    local header="{\"alg\":\"HS256\",\"typ\":\"JWT\",\"kid\":\"$key_id\"}"
    local header_base64=$(printf '%s' "$header" | base64 | tr -d '=' | tr '+' '-' | tr '/' '_')
    
    # Create JWT payload (version 5 for v5.x)
    local payload="{\"iat\":$now,\"exp\":$five_mins,\"aud\":\"/v5/admin/\"}"
    local payload_base64=$(printf '%s' "$payload" | base64 | tr -d '=' | tr '+' '-' | tr '/' '_')
    
    # Combine header and payload
    local header_payload="${header_base64}.${payload_base64}"
    
    # Create signature using the hex secret
    local signature=$(printf '%s' "$header_payload" | openssl dgst -binary -sha256 -mac HMAC -macopt hexkey:"$key_secret" | base64 | tr -d '=' | tr '+' '-' | tr '/' '_')
    
    # Return the complete token
    echo "${header_payload}.${signature}"
}

# Restore Functions
restore_posts() {
    local backup_dir="$1"
    local posts_dir="$backup_dir/posts"
    local target="$2"
    local api_key="$GHOST_ADMIN_KEY"
    
    # Use local API key if restoring locally
    if [ "$target" = "$GHOST_LOCAL_URL" ]; then
        if [ -z "$GHOST_LOCAL_ADMIN_KEY" ]; then
            echo "Error: GHOST_LOCAL_ADMIN_KEY is not set in your config"
            echo "Get this from Ghost Admin -> Settings -> Integrations"
            return 1
        fi
        api_key="$GHOST_LOCAL_ADMIN_KEY"
    fi
    
    echo "Restoring posts..."
    echo "Using Admin API key: $api_key"
    echo "Target URL: $target"
    
    # Extract ID and Secret from API key
    local key_id=$(echo "$api_key" | cut -d':' -f1)
    local key_secret=$(echo "$api_key" | cut -d':' -f2)
    
    # For each post file in the backup
    for post_file in "$posts_dir"/*.json; do
        if [ ! -f "$post_file" ]; then
            echo "No posts found in backup"
            return 1
        fi
        
        echo "Processing file: $post_file"
        # Extract posts from the backup file
        while IFS= read -r post; do
            # Skip empty lines
            [ -z "$post" ] && continue
            
            echo "Restoring post..."
            
            # Generate a fresh JWT token for each request
            local jwt_token=$(generate_jwt_token "$key_id" "$key_secret")
            
            # Remove id and uuid fields to create new post
            local cleaned_post=$(echo "$post" | jq 'del(.id, .uuid)')
            
            # Create post via Ghost Admin API
            local response=$(curl -s -w "\n%{http_code}" \
                -H "Authorization: Ghost ${jwt_token}" \
                -H "Content-Type: application/json" \
                -H "Accept-Version: v5.101" \
                -d "{\"posts\": [$cleaned_post]}" \
                "$target/ghost/api/admin/posts/?source=html")
            
            # Get status code (last line)
            local status_code=$(echo "$response" | tail -n1)
            # Get response body (all but last line)
            local body=$(echo "$response" | sed \$d)
            
            if [ "$status_code" -eq 201 ] || [ "$status_code" -eq 200 ]; then
                echo "✓ Post restored successfully"
            else
                echo "⚠️  Failed to restore post:"
                echo "Status code: $status_code"
                echo "Response: $body"
            fi
            
            # Small delay to avoid overwhelming the API
            sleep 1
            
        done < <(jq -c '.posts[]' "$post_file")
    done
    
    echo "✓ Posts restore completed"
}

restore_images() {
    local backup_dir="$1"
    local images_dir="$backup_dir/images"
    local target="$2"
    local api_key="$GHOST_ADMIN_KEY"
    
    # Use local API key if restoring locally
    if [ "$target" = "$GHOST_LOCAL_URL" ]; then
        if [ -z "$GHOST_LOCAL_ADMIN_KEY" ]; then
            echo "Error: GHOST_LOCAL_ADMIN_KEY is not set in your config"
            echo "Get this from Ghost Admin -> Settings -> Integrations"
            return 1
        fi
        api_key="$GHOST_LOCAL_ADMIN_KEY"
    fi
    
    # Extract ID and Secret from API key
    local key_id=$(echo "$api_key" | cut -d':' -f1)
    local key_secret=$(echo "$api_key" | cut -d':' -f2)
    
    echo "Restoring images..."
    
    # For each image in the backup
    for image in "$images_dir"/*; do
        if [ -f "$image" ]; then
            echo "Uploading image: $(basename "$image")"
            
            # Generate a fresh JWT token for each request
            local jwt_token=$(generate_jwt_token "$key_id" "$key_secret")
            
            # Upload image via Ghost Admin API
            local response=$(curl -s -w "\n%{http_code}" \
                -H "Authorization: Ghost ${jwt_token}" \
                -H "Accept-Version: v5.101" \
                -F "file=@$image;filename=$(basename "$image")" \
                -F "purpose=image" \
                "$target/ghost/api/admin/images/upload/")
            
            # Get status code (last line)
            local status_code=$(echo "$response" | tail -n1)
            # Get response body (all but last line)
            local body=$(echo "$response" | sed \$d)
            
            if [ "$status_code" -eq 201 ] || [ "$status_code" -eq 200 ]; then
                echo "✓ Image uploaded successfully"
            else
                echo "⚠️  Failed to upload image:"
                echo "Status code: $status_code"
                echo "Response: $body"
            fi
            
            # Small delay to avoid overwhelming the API
            sleep 1
        fi
    done
    
    echo "✓ Images restored"
}

restore_themes() {
    local backup_dir="$1"
    local themes_dir="$backup_dir/themes"
    local target="$2"
    local api_key="$GHOST_ADMIN_KEY"
    
    # Use local API key if restoring locally
    if [ "$target" = "$GHOST_LOCAL_URL" ]; then
        if [ -z "$GHOST_LOCAL_ADMIN_KEY" ]; then
            echo "Error: GHOST_LOCAL_ADMIN_KEY is not set in your config"
            echo "Get this from Ghost Admin -> Settings -> Integrations"
            return 1
        fi
        api_key="$GHOST_LOCAL_ADMIN_KEY"
    fi
    
    # Extract ID and Secret from API key
    local key_id=$(echo "$api_key" | cut -d':' -f1)
    local key_secret=$(echo "$api_key" | cut -d':' -f2)
    
    echo "Restoring themes..."
    
    # For each theme directory in the backup
    for theme_dir in "$themes_dir"/*; do
        if [ -d "$theme_dir" ]; then
            local theme_name=$(basename "$theme_dir")
            local temp_zip="/tmp/${theme_name}.zip"
            
            # Create zip of theme
            (cd "$theme_dir" && zip -r "$temp_zip" .)
            
            # Generate a fresh JWT token for each request
            local jwt_token=$(generate_jwt_token "$key_id" "$key_secret")
            
            # Upload theme via API
            curl -X POST \
                -H "Authorization: Ghost ${jwt_token}" \
                -H "Accept-Version: v5.101" \
                -F "file=@$temp_zip" \
                "$target/ghost/api/admin/themes/"
            
            rm "$temp_zip"
        fi
    done
    
    echo "✓ Themes restored"
}

# Function to clean all existing posts
clean_posts() {
    local target="$1"
    local api_key="$GHOST_ADMIN_KEY"
    
    # Use local API key if cleaning locally
    if [ "$target" = "$GHOST_LOCAL_URL" ]; then
        if [ -z "$GHOST_LOCAL_ADMIN_KEY" ]; then
            echo "Error: GHOST_LOCAL_ADMIN_KEY is not set in your config"
            echo "Get this from Ghost Admin -> Settings -> Integrations"
            return 1
        fi
        api_key="$GHOST_LOCAL_ADMIN_KEY"
    fi
    
    # Extract ID and Secret from API key
    local key_id=$(echo "$api_key" | cut -d':' -f1)
    local key_secret=$(echo "$api_key" | cut -d':' -f2)
    
    echo "Cleaning existing posts..."
    
    # Get all posts first
    local jwt_token=$(generate_jwt_token "$key_id" "$key_secret")
    local response=$(curl -s \
        -H "Authorization: Ghost ${jwt_token}" \
        -H "Accept-Version: v5.101" \
        "$target/ghost/api/admin/posts/?limit=all&formats=mobiledoc,lexical,html")
    
    # Extract post IDs
    local post_ids=($(echo "$response" | jq -r '.posts[].id'))
    
    if [ ${#post_ids[@]} -eq 0 ]; then
        echo "No existing posts found"
        return 0
    fi
    
    echo "Found ${#post_ids[@]} posts to delete"
    
    # Delete each post
    for post_id in "${post_ids[@]}"; do
        echo "Deleting post $post_id..."
        
        # Generate fresh token for each request
        jwt_token=$(generate_jwt_token "$key_id" "$key_secret")
        
        local delete_response=$(curl -s -w "\n%{http_code}" \
            -X DELETE \
            -H "Authorization: Ghost ${jwt_token}" \
            -H "Accept-Version: v5.101" \
            "$target/ghost/api/admin/posts/$post_id/")
        
        # Get status code (last line)
        local status_code=$(echo "$delete_response" | tail -n1)
        # Get response body (all but last line)
        local body=$(echo "$delete_response" | sed \$d)
        
        if [ "$status_code" -eq 204 ] || [ "$status_code" -eq 200 ]; then
            echo "✓ Post deleted successfully"
        else
            echo "⚠️  Failed to delete post:"
            echo "Status code: $status_code"
            echo "Response: $body"
        fi
        
        # Small delay to avoid overwhelming the API
        sleep 1
    done
    
    echo "✓ All posts cleaned"
}

perform_restore() {
    local target="$GHOST_LOCAL_URL"
    local skip_images=false
    local skip_themes=false
    local backup_file=""
    local clean_existing=false
    
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --remote) target="$GHOST_URL" ;;
            --no-images) skip_images=true ;;
            --no-themes) skip_themes=true ;;
            --clean) clean_existing=true ;;
            --file) 
                shift
                backup_file="$1" 
                ;;
            *) echo "Unknown parameter: $1"; return 1 ;;
        esac
        shift
    done
    
    # Check if backup file is provided
    if [ -z "$backup_file" ]; then
        echo "Error: No backup file specified"
        echo "Usage: poltertools restore --file <backup_file> [--remote] [--no-images] [--no-themes] [--clean]"
        return 1
    fi
    
    # Check if backup file exists
    if [ ! -f "$backup_file" ]; then
        echo "Error: Backup file not found: $backup_file"
        return 1
    fi
    
    # Check if we have the required API key
    if [ "$target" = "$GHOST_LOCAL_URL" ]; then
        if [ -z "$GHOST_LOCAL_ADMIN_KEY" ]; then
            echo "Error: GHOST_LOCAL_ADMIN_KEY is not set in your config"
            echo "Get this from Ghost Admin -> Settings -> Integrations"
            return 1
        fi
    else
        if [ -z "$GHOST_ADMIN_KEY" ]; then
            echo "Error: GHOST_ADMIN_KEY is not set in your config"
            return 1
        fi
    fi
    
    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    echo "Extracting backup to temporary directory..."
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Find the backup directory (should be the only directory)
    local backup_dir=$(find "$temp_dir" -maxdepth 1 -mindepth 1 -type d)
    
    echo "Restoring to: $target"
    
    # Clean existing posts if requested
    if [ "$clean_existing" = true ]; then
        clean_posts "$target"
    fi
    
    # Perform restore operations
    restore_posts "$backup_dir" "$target"
    
    if [ "$skip_images" = false ]; then
        restore_images "$backup_dir" "$target"
    fi
    
    if [ "$skip_themes" = false ]; then
        restore_themes "$backup_dir" "$target"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    echo "✓ Restore completed successfully"
}

# Function to show help message
show_help() {
  echo "Poltertools - Ghost Development & Management Tools"
  echo ""
  echo "Usage: poltertools [command] [options]"
  echo ""
  echo "Commands:"
  echo "  start     Start Ghost instance with your theme directory mounted"
  echo "  stop      Stop the Ghost instance and related containers"
  echo "  restart   Restart Ghost (needed after locale file changes)"
  echo "  clean     Remove all Docker volumes for a fresh start"
  echo "  package   Create a ZIP file of your theme for deployment"
  echo "  backup    Create a full backup of your Ghost site"
  echo "  backups   List available backups"
  echo "  restore   Restore a backup to local or remote Ghost instance"
  echo "  help      Show this help message"
  echo ""
  echo "Backup Options:"
  echo "  --no-images    Skip backing up images"
  echo "  --no-themes    Skip backing up themes"
  echo ""
  echo "Restore Options:"
  echo "  --file <file>  Specify backup file to restore"
  echo "  --remote       Restore to remote Ghost instance (default: local)"
  echo "  --no-images    Skip restoring images"
  echo "  --no-themes    Skip restoring themes"
  echo ""
  echo "Examples:"
  echo "  poltertools start                    # Start Ghost with your theme"
  echo "  poltertools backup                   # Create a full backup"
  echo "  poltertools backup --no-images       # Backup without images"
  echo "  poltertools restore --file backup.tar.gz      # Restore to local"
  echo "  poltertools restore --file backup.tar.gz --remote  # Restore to remote"
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

# Function to setup remote host
setup_remote() {
    if [ -z "$1" ]; then
        echo "Error: No host specified"
        echo "Usage: poltertools.sh setup-remote user@host"
        return 1
    fi

    local remote_host="$1"
    
    echo "Setting up remote host: $remote_host"
    
    # Install Docker
    ssh "$remote_host" '
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
        
        # Create directories for Traefik
        sudo mkdir -p /etc/traefik
        sudo touch /etc/traefik/acme.json
        sudo chmod 600 /etc/traefik/acme.json
    '
    
    echo "✓ Remote host setup complete"
}

# Function to deploy Ghost
deploy() {
    # Check if .env.deploy exists
    if [ ! -f ".env.deploy" ]; then
        echo "Error: .env.deploy file not found"
        echo "Please copy .env.deploy.example to .env.deploy and update the values"
        return 1
    fi
    
    # Make deploy script executable
    chmod +x deploy/deploy.sh
    
    # Run deployment
    ./deploy/deploy.sh
}

# Function to show deployment help
show_deployment_help() {
    echo "Deployment Commands:"
    echo "  setup-remote [user@host]  Setup Docker and dependencies on remote host"
    echo "  deploy                    Deploy Ghost to remote host"
    echo ""
    echo "Before deploying:"
    echo "1. Copy .env.deploy.example to .env.deploy and update values"
    echo "2. Ensure remote host is properly setup using setup-remote"
    echo ""
    echo "Example workflow:"
    echo "  poltertools.sh setup-remote user@example.com"
    echo "  poltertools.sh deploy"
}

# Main script logic
case "$1" in
    "start")
        run_docker_compose
        ;;
    "stop")
        stop_docker_compose
        ;;
    "restart")
        restart_ghost
        ;;
    "clean")
        clean_docker_volumes
        ;;
    "package")
        package_theme
        ;;
    "backup")
        shift
        load_config
        perform_backup "$@"
        ;;
    "backups")
        load_config
        list_backups
        ;;
    "restore")
        shift
        load_config
        perform_restore "$@"
        ;;
    "setup-remote")
        shift
        setup_remote "$@"
        ;;
    "deploy")
        deploy
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        show_deployment_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'poltertools help' for usage information"
        exit 1
        ;;
esac
