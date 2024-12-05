# Poltertools

![Poltertools Logo](./logo.webp)

`Poltertools` is a bash script to streamline the development and management of Ghost themes using Docker. It allows you to run a local Ghost instance and package themes into ZIP files for upload.

## Features

- **Run Local Ghost Instance**: Start a Ghost instance with Docker, linking your themes directory for live development.
- **Package Themes**: Create a ZIP file of your modified theme for deployment.
- **Environment Awareness**: Automatically uses the `GHOST_THEMES_DIR` environment variable, or falls back to a default directory if not set.

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

### 1. Run Ghost Locally
Start a local Ghost instance with your themes directory linked:
```bash
poltertools run
```

- **Environment Variable**: The script checks for the `GHOST_THEMES_DIR` environment variable. If it’s not set, the default directory (`./content/themes`) is used.
- Example:
  ```bash
  export GHOST_THEMES_DIR=/path/to/your/themes
  poltertools run
  ```
  If `GHOST_THEMES_DIR` is not set, the script will display:
  ```
  Warning: GHOST_THEMES_DIR environment variable is not set.
  The default directory './content/themes' will be used.
  ```

### 2. Package a Theme
Create a ZIP file of the current theme directory:
```bash
poltertools package
```

- **Output**: The ZIP file will be saved in the parent directory of your themes folder.
- **Naming**: The file is named `<theme-name>-<timestamp>.zip`.

### 3. Help
For usage instructions:
```bash
poltertools
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
   poltertools run
   ```

3. Edit your theme files locally. Changes will be reflected in the running Ghost instance.

4. Once ready, package the theme:
   ```bash
   poltertools package
   ```

5. Upload the generated ZIP file to your Ghost instance.

## Notes

- The script ensures the themes directory exists before proceeding.
- Ensure Docker Compose is properly configured with your `docker-compose.yml` file.

## Troubleshooting

- **Directory Not Found**: If the themes directory doesn’t exist, the script will terminate with an error.
- **Permissions**: Ensure you have write permissions for the directory where the script generates ZIP files.

## License

This script is open-source and available under the MIT License.
