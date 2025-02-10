# Poltertools

<img src="logo.webp" alt="Poltertools Logo" width="200"/>

A set of tools for managing Ghost blog development, backups, and content migration.

## Features

- 🚀 Local Ghost development environment with Docker
- 📦 Theme packaging for deployment
- 💾 Full site backup (posts, images, themes)
- 🔄 Restore backups to local or remote Ghost instances
- 🔧 Easy theme development with live reload
- 🛡️ Simple deployment with Traefik and optional Cloudflare SSL/TLS

## Installation

1. Clone this repository
2. Copy configuration files:
   ```bash
   cp poltertools.config.example poltertools.config
   cp .env.deploy.example .env.deploy
   ```
3. Update the configuration values in both files

## Configuration

### Development Configuration (`poltertools.config`)
```bash
# Ghost Configuration
GHOST_API_KEY="your_ghost_content_api_key_here"  # Content API key for remote
GHOST_ADMIN_KEY="your_ghost_admin_api_key_here"  # Admin API key for remote
GHOST_URL="https://your-blog-url.com"
GHOST_LOCAL_URL="http://localhost:2368"
GHOST_LOCAL_API_KEY="your_local_content_api_key_here"
GHOST_LOCAL_ADMIN_KEY="your_local_admin_api_key_here"
GHOST_THEMES_DIR="./content/themes"

# Backup Configuration
BACKUP_DIR="ghost_backups"
```

### Deployment Configuration (`.env.deploy`)
```bash
# Deployment Settings
DEPLOY_HOST=your-server-ip
DEPLOY_USER=root  # Usually 'root' for fresh servers

# Ghost Settings
GHOST_URL=http://your-server-ip  # Change to your domain when ready

# Database Settings
DB_NAME=ghost
DB_USER=ghost
DB_PASSWORD=your_secure_password
DB_ROOT_PASSWORD=your_secure_root_password

# Email Settings (required for password reset and notifications)
MAIL_FROM=your-blog@your-domain.com
MAIL_TRANSPORT=SMTP
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USER=your-email@gmail.com
MAIL_PASSWORD=your-app-specific-password
```

To get your API keys:
1. Content API keys: Ghost Admin → Settings → Integrations → Add custom integration
2. Admin API keys: Ghost Admin → Settings → Integrations → Add custom integration
   - Admin API keys are required for restore operations
   - Format: `{id}:{secret}`

## Deployment

The script supports deploying Ghost to a remote server using Docker and Traefik, with optional Cloudflare SSL/TLS:

```bash
# Deploy Ghost to remote host
./poltertools.sh deploy
```

### Prerequisites

Remote host requirements:
1. SSH access with key-based authentication
2. User with sudo privileges
3. At least 5GB of free disk space
4. Port 80 available
5. Ubuntu/Debian-based system

Note: The deployment script will automatically:
- Install Docker if not present
- Configure Docker permissions
- Install required dependencies
- Setup necessary directories

### Deployment Process

The deployment script will:
1. Check and install prerequisites
2. Setup Docker network
3. Configure Traefik for routing
4. Setup MySQL with persistent storage
5. Deploy Ghost with clean configuration

After deployment:
1. Visit `http://your-server-ip/ghost` to set up your admin account
2. Configure your site settings
3. Install your custom theme (see Theme Development section)

### SSL/TLS Options

#### Option 1: Testing (Default)
The default deployment uses Traefik without SSL, suitable for initial testing:
- Access via `http://your-server-ip`
- No SSL certificate required
- Quick to set up and test

#### Option 2: Production with Cloudflare (Recommended)
For production deployments, use Cloudflare for SSL/TLS:

1. Add your domain to Cloudflare
2. Update your domain's nameservers to use Cloudflare
3. In Cloudflare dashboard:
   - SSL/TLS → Overview → Select "Flexible"
   - DNS → Add A record pointing to your server IP
   - Enable proxy status (orange cloud)
4. Update `.env.deploy`:
   ```bash
   GHOST_URL=https://your-domain.com
   MAIL_FROM=ghost@your-domain.com
   ```
5. Redeploy:
   ```bash
   ./poltertools.sh deploy
   ```

Benefits of Cloudflare:
- Free SSL/TLS certificates
- DDoS protection
- CDN caching
- Analytics
- Zero configuration on server

## Development

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

### Directory Structure

```
.
├── content/
│   └── themes/          # Your Ghost themes
├── ghost_backups/       # Backup archives
├── deploy/              # Deployment scripts
├── poltertools.sh       # Main script
├── poltertools.config   # Development configuration
└── .env.deploy         # Deployment configuration
```

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

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request