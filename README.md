# Poltertools

A set of tools for managing Ghost blog development, backups, and content migration.

## Features

- 🚀 Local Ghost development environment with Docker
- 📦 Theme packaging for deployment
- 💾 Full site backup (posts, images, themes)
- 🔄 Restore backups to local or remote Ghost instances
- 🔧 Easy theme development with live reload

## Installation

1. Clone this repository
2. Copy configuration files:
   ```bash
   cp poltertools.config.example poltertools.config
   cp poltertools.secrets.example poltertools.secrets
   ```
3. Update the configuration values in both files

## Configuration

The configuration is split into two files for security:

### `poltertools.config`
Contains non-sensitive configuration:
```bash
# Ghost Configuration
GHOST_URL="https://your-blog-url.com"            # Your remote Ghost blog URL
GHOST_LOCAL_URL="http://localhost:2368"          # Local Ghost instance URL
GHOST_THEMES_DIR="./content/themes"              # Path to your themes directory

# WhisperVeil Configuration
LLM_TYPE="openai"                                # Type of LLM to use
POST_INTERVAL="1h"                               # Interval between posts
LLM_MODEL="gpt-3.5-turbo"                       # LLM model to use
```

### `poltertools.secrets` (gitignored)
Contains sensitive API keys:
```bash
# Remote Ghost instance
GHOST_API_KEY="your_ghost_content_api_key"       # Content API key for remote
GHOST_ADMIN_KEY="your_ghost_admin_api_key"       # Admin API key for remote

# Local Ghost instance
GHOST_LOCAL_API_KEY="your_local_content_api_key"  # Content API key for local
GHOST_LOCAL_ADMIN_KEY="your_local_admin_api_key"  # Admin API key for local

# WhisperVeil
LLM_API_KEY="your_llm_api_key"                   # OpenAI/Anthropic API key
```

To get your API keys:
1. Content API keys: Ghost Admin → Settings → Integrations → Add custom integration
2. Admin API keys: Ghost Admin → Settings → Integrations → Add custom integration
   - Admin API keys are required for restore operations
   - Format: `{id}:{secret}`

## Usage

### Local Development

```bash
# Start Ghost with your theme mounted
./poltertools.sh start

# Stop Ghost
./poltertools.sh stop

# Restart Ghost (needed after locale changes)
./poltertools.sh restart

# Clean Docker volumes for fresh start
./poltertools.sh clean
```

### Theme Development

```bash
# Package theme for deployment
./poltertools.sh package
```

Live reload is enabled for:
- Template files (.hbs)
- CSS/SCSS files
- JavaScript files
- Images and assets

Restart required for:
- Locale files (.json)
- Theme configuration
- Ghost settings

### Backup & Restore

```bash
# Create full backup
./poltertools.sh backup

# List available backups
./poltertools.sh backups

# Restore backup locally
./poltertools.sh restore --file ghost_backup_20250207_093511.tar.gz

# Restore backup to remote site
./poltertools.sh restore --file ghost_backup_20250207_093511.tar.gz --remote

# Restore with options
./poltertools.sh restore --file backup.tar.gz --no-images --no-themes

# Clean existing posts before restore
./poltertools.sh restore --file backup.tar.gz --clean
```

Backup options:
- `--no-images`: Skip backing up images
- `--no-themes`: Skip backing up themes

Restore options:
- `--file <file>`: Specify backup file to restore
- `--remote`: Restore to remote Ghost instance (default: local)
- `--no-images`: Skip restoring images
- `--no-themes`: Skip restoring themes
- `--clean`: Delete all existing posts before restoring

## Development

The script uses Docker Compose to run Ghost locally. Your theme directory is mounted into the container for live development.

### Directory Structure

```
.
├── content/
│   └── themes/          # Your Ghost themes
├── ghost_backups/       # Backup archives
├── poltertools.sh       # Main script
├── poltertools.config   # Non-sensitive configuration
├── poltertools.secrets  # API keys and secrets (gitignored)
└── docker-compose.yml   # Docker configuration
```

### Security

- All sensitive data (API keys, secrets) should be stored in `poltertools.secrets`
- The `poltertools.secrets` file is gitignored to prevent accidental commits
- Never commit API keys or secrets to version control
- Always use the example files as templates

### Permissions

The script handles permissions automatically:
- Creates necessary directories
- Sets correct ownership (node:node)
- Sets appropriate permissions for Ghost operation

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
