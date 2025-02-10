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

## Getting Started: Complete Setup Guide

This guide will walk you through setting up your own Ghost blog from scratch using Poltertools.

### 1. Initial Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/poltertools.git
cd poltertools

# Create configuration files
cp poltertools.config.example poltertools.config
cp .env.deploy.example .env.deploy
```
Be sure to update the configuration files with your own values.

### 2. Local Development Environment (Recommended)
This helps you develop and test your theme locally before deploying.

```bash
# Create a theme directory
mkdir -p content/themes/my-theme

# Start the local Ghost instance
./poltertools.sh start

# Access your local Ghost:
# Admin Panel: http://localhost:2368/ghost
# Blog: http://localhost:2368
```
You can chose any path for your theme directory, it will be mounted into the Ghost container. You also dont have to use the `my-theme` directory, it is just an example, any existing folder will do.

Initial local setup tasks:
1. Go to http://localhost:2368/ghost
2. Create your admin account
3. Configure basic settings
4. Start developing your theme in `content/themes/my-theme`

### 3. Production Deployment
#### 3.1 Server Prerequisites
- A fresh Ubuntu/Debian server (DigitalOcean, Linode, etc.)
- Domain name (optional for testing, required for production)
- SSH access to your server

#### 3.2 Configure Deployment
Edit `.env.deploy`:
```bash
# Deployment Settings
DEPLOY_HOST=your-server-ip
DEPLOY_USER=root

# Ghost Settings
GHOST_URL=http://your-server-ip  # Change to https://your-domain.com later

# Database Settings (change these!)
DB_NAME=ghost
DB_USER=ghost
DB_PASSWORD=choose_secure_password
DB_ROOT_PASSWORD=choose_secure_root_password

# Email Settings (required for user signup/password reset)
MAIL_FROM=your-blog@your-domain.com
MAIL_TRANSPORT=SMTP
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USER=your-email@gmail.com
MAIL_PASSWORD=your-app-specific-password
```

#### 3.3 Deploy Ghost
```bash
# Deploy to your server
./poltertools.sh deploy
```

The script will automatically:
- Install Docker and dependencies
- Configure the network
- Set up MySQL
- Deploy Ghost
- Configure Traefik for routing

#### 3.4 Initial Configuration
1. Visit `http://your-server-ip/ghost`
2. Create your admin account
3. Configure your site settings

### 4. Theme Development and Deployment
#### 4.1 Develop Your Theme
```bash
# Your theme files go in:
content/themes/my-theme/

# Common theme files:
├── assets/          # Images, CSS, JS
├── default.hbs      # Main template
├── index.hbs        # Homepage template
├── post.hbs         # Single post template
├── package.json     # Theme info
└── partials/        # Reusable components
```

#### 4.2 Package and Deploy Theme
```bash
# Create theme package
./poltertools.sh package

# This creates a ZIP file of your theme
```

Upload to production:
1. Go to your production Ghost admin
2. Settings → Design
3. Upload the theme ZIP file

### 5. Production Setup
#### 5.1 Basic Setup (Testing)
- Access via `http://your-server-ip`
- Use for initial testing

#### 5.2 Production Setup (with Domain)
1. Add your domain to Cloudflare
2. Update DNS:
   - Point A record to your server IP
   - Enable proxy (orange cloud)
3. Configure SSL/TLS in Cloudflare:
   - SSL/TLS → Overview → Select "Flexible"

4. Update `.env.deploy`:
```bash
GHOST_URL=https://your-domain.com
MAIL_FROM=ghost@your-domain.com
```

5. Redeploy:
```bash
./poltertools.sh deploy
```

### 6. Maintenance Operations
#### Backups
```bash
# Create backup
./poltertools.sh backup

# List backups
./poltertools.sh backups

# Restore backup
./poltertools.sh restore --file backup.tar.gz
```

#### Theme Updates
```bash
# After making theme changes:
./poltertools.sh package
# Upload new ZIP via Ghost Admin
```

#### Server Maintenance
```bash
# Restart Ghost
ssh root@your-server-ip "docker restart ghost"

# View logs
ssh root@your-server-ip "docker logs ghost"
```

### 7. Next Steps
1. Configure your site settings in Ghost Admin
2. Set up email newsletter integration
3. Add custom integrations if needed
4. Set up regular backups
5. Monitor your server's performance

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
GHOST_THEMES_DIR="./content/themes"  # Path to your themes directory (default: ./content/themes)

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
# Start Ghost with your theme mounted (from GHOST_THEMES_DIR)
./poltertools.sh start

# Stop Ghost
./poltertools.sh stop

# Restart Ghost (needed after locale changes)
./poltertools.sh restart

# Clean Docker volumes for fresh start
./poltertools.sh clean
```

### Theme Development

Your themes should be placed in the directory specified by `GHOST_THEMES_DIR` in your `poltertools.config`. If not specified, it defaults to `./content/themes`.

```bash
# Example theme structure in your themes directory:
content/themes/my-theme/
├── assets/          # Images, CSS, JS
├── default.hbs      # Main template
├── index.hbs        # Homepage template
├── post.hbs         # Single post template
├── package.json     # Theme info
└── partials/        # Reusable components
```

### Directory Structure

```
.
├── content/
│   └── themes/          # Default themes directory (configurable in poltertools.config)
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

## Command Reference

```bash
Commands:
  start     Start Ghost instance with your theme directory mounted
  stop      Stop the Ghost instance and related containers
  restart   Restart Ghost (needed after locale file changes)
  clean     Remove all Docker volumes for a fresh start
  package   Create a ZIP file of your theme for deployment
  backup    Create a full backup of your Ghost site
  backups   List available backups
  restore   Restore a backup to local or remote Ghost instance
  deploy    Deploy Ghost to a remote server
  help      Show this help message

Configuration Files:
  poltertools.config   Local development configuration
  .env.deploy         Deployment configuration

Live Reload Behavior:
  • Immediate changes (no restart needed):
    - Template files (.hbs)
    - CSS/SCSS files
    - JavaScript files
    - Images and assets

  • Changes requiring restart:
    - Locale files (.json)
    - Theme configuration
    - Ghost settings
```