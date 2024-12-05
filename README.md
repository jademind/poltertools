# Poltertools

![Poltertools Logo](./logo.webp)

`Poltertools` is a bash script to streamline the development and management of Ghost themes using Docker. It allows you to run a local Ghost instance and package themes into ZIP files for upload.

## Features

- **Run Local Ghost Instance**: Start a Ghost instance with Docker, linking your themes directory for live development.
- **Package Themes**: Create a ZIP file of your modified theme for deployment.
- **Environment Awareness**: Automatically uses the `GHOST_THEMES_DIR` environment variable, or falls back to a default directory if not set.
- **Live Reload**: Automatically detects changes in your theme files for immediate preview.
- **Database Persistence**: Uses MySQL for reliable data storage.

## Requirements

- Docker and Docker Compose installed on your system.
- Bash shell.

## Installation

1. Save the script as `poltertools` in a directory included in your `PATH` (e.g., `/usr/local/bin`):
   ```bash
   sudo mv poltertools /usr/local/bin/
   sudo chmod +x /usr/local/bin/poltertools
   ```

2. Ensure Docker and Docker Compose are installed and configured.

## Usage

`poltertools` provides the following commands:

### 1. Start Ghost Locally
Start a local Ghost instance with your themes directory linked:
```bash
poltertools start
```

### 2. Stop Ghost
Stop the running Ghost instance:
```bash
poltertools stop
```

### 3. Restart Ghost
Restart the Ghost instance (useful when changing locale files):
```bash
poltertools restart
```

### 4. Clean Environment
Remove all Docker volumes to start fresh:
```bash
poltertools clean
```

### 5. Package a Theme
Create a ZIP file of the current theme directory:
```bash
poltertools package
```

## Live Reload Behavior

The development environment is configured for optimal development experience with different reload behaviors:

### Immediate Changes (No Restart Required)
- Template files (`.hbs`)
- CSS/SCSS files
- JavaScript files
- Images and other assets

### Changes Requiring Restart
- Locale files (`.json`)
- Theme configuration files
- Ghost settings

To apply these changes, use:
```bash
poltertools restart
```

## Environment Variables

- **`GHOST_THEMES_DIR`**: Absolute path to your themes directory. Example:
  ```bash
  export GHOST_THEMES_DIR=/path/to/your/themes
  ```
- Default: If not set, the script defaults to `./content/themes`.

## Example Workflow

1. Set your themes directory (optional):
   ```bash
   export GHOST_THEMES_DIR=/absolute/path/to/themes
   ```

2. Start Ghost with Docker:
   ```bash
   poltertools start
   ```

3. Edit your theme files locally:
   - Template changes will be reflected immediately
   - For locale changes, run `poltertools restart`

4. Once ready, package the theme:
   ```bash
   poltertools package
   ```

5. To start fresh:
   ```bash
   poltertools clean
   poltertools start
   ```

## Access URLs

When Ghost is running, you can access:
- 📝 Blog: http://localhost:2368
- ⚙️ Admin Panel: http://localhost:2368/ghost

## Troubleshooting

- **Directory Not Found**: If the themes directory doesn't exist, the script will terminate with an error.
- **Permission Issues**: The script automatically handles permissions for the Ghost content directory.
- **Cache Issues**: If changes aren't reflecting:
  1. Try clearing your browser cache
  2. Use `poltertools restart` for locale changes
  3. Use `poltertools clean` to start fresh

## Notes

- The script uses MySQL instead of SQLite for better reliability
- All data is persisted in Docker volumes
- Development mode is enabled with caching disabled
- The theme directory is mounted read-only for safety

## License

This script is open-source and available under the MIT License.
