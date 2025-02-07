#!/bin/bash

# Configuration variables
CONFIG_FILE="whisperveil.config"
DEFAULT_MODEL="gpt-3.5-turbo"
DEFAULT_INTERVAL="1h"
DEFAULT_POST_COUNT=3
DEBUG=false

# Function to print debug info
debug() {
    if [ "$DEBUG" = true ]; then
        echo "=== Debug: $1 ==="
        shift
        echo "$@"
        echo "==========================="
    fi
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # First show the raw contents of the config file
        echo "=== Raw config file contents ==="
        cat "$CONFIG_FILE"
        echo "==============================="
        
        # Source the config
        source "$CONFIG_FILE"
        
        # Debug output without trying to parse anything
        echo "Loaded configuration:"
        echo "GHOST_API_KEY: ${GHOST_API_KEY:0:10}..."
        echo "GHOST_URL: $GHOST_URL"
        echo "LLM_TYPE: $LLM_TYPE"
        
        # Check if variables are actually empty, not just containing whitespace
        if [ -z "${GHOST_API_KEY// }" ] || [ -z "${GHOST_URL// }" ] || [ -z "${LLM_API_KEY// }" ]; then
            echo "Configuration file is incomplete. Running setup..."
            setup_config
        fi
    else
        echo "No config file found. Running setup..."
        setup_config
    fi
}

# Function to setup initial configuration
setup_config() {
    echo "WhisperVeil Setup"
    echo "----------------"
    
    echo "Get your Content API key from Ghost Admin -> Settings -> Integrations -> Add custom integration"
    echo "or use 'Ghost' integration and copy the Content API Key"
    read -p "Ghost Content API Key: " ghost_api_key
    read -p "Ghost URL (e.g., http://localhost:2368): " ghost_url
    read -p "LLM Type (openai/anthropic/local): " llm_type
    read -p "LLM API Key: " llm_api_key
    read -p "Post interval (e.g., 1h, 30m, 1d): " post_interval
    
    # Verify input is not empty
    if [ -z "${ghost_api_key// }" ] || [ -z "${ghost_url// }" ] || [ -z "${llm_api_key// }" ]; then
        echo "Error: All fields must be filled out"
        return 1
    fi
    
    # Create config file
    cat > "$CONFIG_FILE" <<EOL
GHOST_API_KEY="${ghost_api_key}"
GHOST_URL="${ghost_url}"
LLM_TYPE="${llm_type}"
LLM_API_KEY="${llm_api_key}"
POST_INTERVAL="${post_interval:-$DEFAULT_INTERVAL}"
LLM_MODEL="$DEFAULT_MODEL"
EOL

    chmod 600 "$CONFIG_FILE"
    echo "Configuration saved!"
    
    # Load the new configuration immediately
    source "$CONFIG_FILE"
    
    # Verify the configuration was loaded correctly
    if [ -z "${GHOST_API_KEY// }" ] || [ -z "${GHOST_URL// }" ] || [ -z "${LLM_API_KEY// }" ]; then
        echo "Error: Configuration not loaded properly"
        return 1
    fi
    
    return 0
}

# Function to fetch latest Ghost posts
fetch_latest_posts() {
    local limit=${1:-5}
    # Remove any trailing slash from the URL
    GHOST_URL=${GHOST_URL%/}
    local full_url="${GHOST_URL}/ghost/api/content/posts/?key=${GHOST_API_KEY}&limit=${limit}&include=authors,tags"
    
    echo "Fetching posts from Ghost..."
    echo "Using URL: $full_url"
    
    # Make the request and store only the response body
    local response=$(curl -s \
        -H "Accept-Version: v5.0" \
        "$full_url")
    
    # First check if we got a valid JSON response
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid JSON response from Ghost API"
        echo "Raw response:"
        echo "$response"
        return 1
    fi
    
    # Check if we have posts in the response
    if ! echo "$response" | jq -e '.posts[0]' >/dev/null 2>&1; then
        echo "Error: No posts found in response"
        echo "JSON response:"
        echo "$response" | jq '.'
        return 1
    fi
    
    # Get the first post
    local post=$(echo "$response" | jq '.posts[0]')
    
    echo "=== Latest Post Details ==="
    echo "Title: $(echo "$post" | jq -r '.title')"
    echo "URL: $(echo "$post" | jq -r '.url')"
    echo "Excerpt: $(echo "$post" | jq -r '.excerpt')"
    echo "Author: $(echo "$post" | jq -r '.primary_author.name // "Unknown"')"
    echo "Tags: $(echo "$post" | jq -r '.tags[].name' | tr '\n' ', ')"
    echo "=========================="
    
    echo "$post"
    return 0
}

# Function to generate social media posts using selected LLM
generate_social_posts() {
    local post_data="$1"
    local post_count=${2:-$DEFAULT_POST_COUNT}
    
    debug "Raw post data" "$(echo "$post_data" | jq '.')"
    
    # Extract data (handle null tags)
    local title=$(echo "$post_data" | jq -r '.title // empty')
    local excerpt=$(echo "$post_data" | jq -r '.excerpt // empty')
    local url=$(echo "$post_data" | jq -r '.url // empty')
    local author=$(echo "$post_data" | jq -r '.primary_author.name // "Unknown"')
    local tags=$(echo "$post_data" | jq -r 'if has("tags") and (.tags | length > 0) then (.tags[].name | select(.)) else "" end' | tr '\n' ',' | sed 's/,$//')
    
    # Create prompt
    local prompt="Generate $post_count engaging Twitter/X posts (max 280 characters each) to promote this blog post:
    Title: $title
    Author: $author
    Excerpt: $excerpt
    URL: $url
    Tags: $tags
    
    Make each post unique, engaging, and include relevant hashtags from the tags provided. 
    Format the response as a JSON array of posts. 
    Each post should be under 280 characters including the URL."

    # Generate posts
    local response=$(generate_with_openai "$prompt")
    
    # Parse the OpenAI response and extract just the posts
    if [ "$DEBUG" = true ]; then
        echo "$response"
    else
        # First get the message content, then parse the JSON array
        local content=$(echo "$response" | jq -r '.choices[0].message.content')
        echo "$content" | jq -r '.[] | .post' 2>/dev/null || echo "$content"
    fi
}

# Function to generate posts with OpenAI
generate_with_openai() {
    local prompt="$1"
    
    # Escape the prompt for JSON
    local escaped_prompt=$(echo "$prompt" | jq -R -s '.')
    
    # Create the JSON payload
    local data="{\"model\":\"$LLM_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":$escaped_prompt}],\"temperature\":0.7}"
    
    # Make the request
    local response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $LLM_API_KEY" \
        -d "$data")
    
    # Check for errors in the response
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "Error from OpenAI:"
        echo "$response" | jq -r '.error.message'
        return 1
    fi
    
    echo "$response"
    return 0
}

# Function to generate posts with Anthropic
generate_with_anthropic() {
    local prompt="$1"
    curl -s https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $LLM_API_KEY" \
        -d "{
            \"model\": \"claude-3-sonnet-20240229\",
            \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
            \"max_tokens\": 1024
        }" | jq -r '.content[0].text'
}

# Function to generate posts with local LLM
generate_with_local_llm() {
    local prompt="$1"
    # Implement local LLM integration here
    # This could be Ollama, LocalAI, etc.
    echo "Local LLM integration not implemented yet"
}

# Function to schedule posts
schedule_posts() {
    local posts="$1"
    local interval="$POST_INTERVAL"
    
    # Convert posts JSON to array
    readarray -t post_array < <(echo "$posts" | jq -r '.[]')
    
    # Schedule each post
    for post in "${post_array[@]}"; do
        echo "Scheduling post: $post"
        # Implement actual posting logic here
        # This could integrate with Twitter/X API
        echo "Would post at: $(date -d "+$interval")"
        interval="$interval + $POST_INTERVAL"
    done
}

# Function to display posts in a table format
display_posts_table() {
    local posts="$1"
    
    # Create a temporary file for the table data
    local tmp_file=$(mktemp)
    
    # Add header
    echo "TITLE|DATE|EXCERPT" > "$tmp_file"
    echo "----|-------|-------" >> "$tmp_file"
    
    # Process each post and add to table
    echo "$posts" | jq -r '.posts[] | [.title, (.published_at | split("T")[0]), (.excerpt | if length > 100 then .[:97] + "..." else . end)] | join("|")' >> "$tmp_file"
    
    # Display using column for nice formatting
    column -t -s '|' "$tmp_file"
    
    # Clean up
    rm "$tmp_file"
}

# Function to fetch Ghost posts
fetch_posts() {
    local limit=${1:-10}  # Default to 10 posts
    GHOST_URL=${GHOST_URL%/}
    local full_url="${GHOST_URL}/ghost/api/content/posts/?key=${GHOST_API_KEY}&limit=${limit}&fields=title,excerpt,published_at&include=authors,tags"
    
    echo "Fetching posts from Ghost..."
    
    # Make the request
    local response=$(curl -s \
        -H "Accept-Version: v5.0" \
        "$full_url")
    
    # Check if we got a valid JSON response
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid JSON response from Ghost API"
        return 1
    fi
    
    # Check if we have posts
    if ! echo "$response" | jq -e '.posts' >/dev/null 2>&1; then
        echo "Error: No posts found"
        return 1
    fi
    
    # Display posts in table format
    display_posts_table "$response"
    
    return 0
}

# Function to select a post from the list
select_post() {
    local response="$1"
    local posts_count=$(echo "$response" | jq '.posts | length')
    
    # Display posts
    for i in $(seq 0 $(($posts_count - 1))); do
        local title=$(echo "$response" | jq -r ".posts[$i].title")
        local date=$(echo "$response" | jq -r ".posts[$i].published_at | split(\"T\")[0]")
        printf "%d) [%s] %s\n" "$((i+1))" "$date" "$title"
    done
    
    # Get selection
    printf "\nSelect post (1-%d): " "$posts_count"
    read -r num
    
    # Validate and return selected post
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$posts_count" ]; then
        echo "$response" | jq ".posts[$(($num-1))]"
        return 0
    else
        return 1
    fi
}

# Function to show help
show_help() {
    cat << EOF
WhisperVeil - Social Media Content Generator for Ghost Publications

Usage: whisperveil.sh [command] [options]

Commands:
    setup               Configure WhisperVeil settings
    fetch [limit]       Fetch and display recent posts (default: 10)
    generate [--debug]  Generate social media posts for a selected blog post
    schedule           Generate and schedule social media posts
    help               Show this help message

Options:
    --debug            Show detailed debug information (with generate command)

Examples:
    # Setup WhisperVeil configuration
    whisperveil.sh setup

    # List last 5 posts
    whisperveil.sh fetch 5

    # Generate social posts with debug info
    whisperveil.sh generate --debug

    # Schedule automated posts
    whisperveil.sh schedule

For more information, visit: https://github.com/yourusername/poltertools
EOF
}

# Main function
main() {
    load_config
    
    case "$1" in
        "setup")
            setup_config
            ;;
        "fetch")
            # Get limit from second argument or use default
            local limit=${2:-10}
            fetch_posts "$limit"
            ;;
        "generate")
            # Check for debug flag
            if [ "$2" = "--debug" ]; then
                DEBUG=true
            fi
            
            echo "Fetching posts..."
            local response=$(curl -s -H "Accept-Version: v5.0" \
                "${GHOST_URL}/ghost/api/content/posts/?key=${GHOST_API_KEY}&limit=10")
            
            # Display posts for selection
            echo -e "\nAvailable posts:"
            echo "$response" | jq -r '.posts[] | "\(.title) [\(.published_at | split("T")[0])]"' | nl
            
            # Get user selection
            echo -n "Select post number: "
            read -r selection
            
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$(echo "$response" | jq '.posts | length')" ]; then
                local selected_post=$(echo "$response" | jq ".posts[$(($selection-1))]")
                echo -e "\nGenerating social media posts...\n"
                social_posts=$(generate_social_posts "$selected_post")
                echo "$social_posts"
            else
                echo "Invalid selection"
                exit 1
            fi
            ;;
        "schedule")
            echo "Fetching latest post..."
            local post_data=$(fetch_latest_posts 1)
            if [ $? -eq 0 ] && [ ! -z "$post_data" ]; then
                echo "Generating and scheduling posts..."
                social_posts=$(generate_social_posts "$post_data")
                schedule_posts "$social_posts"
            fi
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@" 