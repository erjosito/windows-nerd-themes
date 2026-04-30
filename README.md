# Windows Nerd Themes 🎨

Customize your Windows setup with themed configurations for Windows Terminal, WSL, PowerShell, wallpaper, and screensaver — all driven by JSON theme files.

## Features

- **Theme-based configuration** — Define everything in a single JSON file
- **Modular components** — Enable/disable any component independently
- **Windows Terminal** — Custom backgrounds, Nerd Fonts, color schemes, per-profile theming
- **WSL (Ubuntu)** — oh-my-zsh with powerlevel10k, configurable plugins, tmux integration
- **PowerShell** — oh-my-posh, PSReadLine predictions, Terminal-Icons, completions
- **Desktop Wallpaper** — Automatic download and application
- **Screensaver** — Configure type and timeout

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/erjosito/windows-nerd-themes.git
cd windows-nerd-themes

# Apply the Star Wars theme (all components)
.\install.ps1 -Theme star-wars

# Apply only terminal and WSL
.\install.ps1 -Theme star-wars -Components terminal,wsl

# Skip wallpaper and screensaver
.\install.ps1 -Theme star-wars -Exclude wallpaper,screensaver

# Dry run (preview without changes)
.\install.ps1 -Theme star-wars -DryRun
```

## Theme Structure

Themes live in `themes/` as JSON files. Each theme defines:

```json
{
  "name": "Theme Name",
  "description": "A description of the theme",
  "components": {
    "wallpaper": { ... },
    "screensaver": { ... },
    "windows_terminal": { ... },
    "wsl": { ... },
    "powershell": { ... }
  }
}
```

### Component: Windows Terminal

Configure per-profile backgrounds, fonts, color schemes, and opacity:

| Profile | Background | Font | Color Scheme |
|---------|-----------|------|--------------|
| Ubuntu (WSL) | Death Star | MesloLGL Nerd Font Mono | Campbell |
| PowerShell | X-Wing | MesloLGL Nerd Font | VibrantTom |
| PowerShell Admin | Venator | MesloLGL Nerd Font | VibrantTom |
| CMD | Millennium Falcon | MesloLGL Nerd Font Mono | Campbell |

### Component: WSL

- **Shell**: zsh with oh-my-zsh
- **Theme**: powerlevel10k
- **Plugins**: git, zsh-autosuggestions, kubectl, tmux, aws, azure, history-substring-search
- **Tools**: tmux (autostart), kubectl, nvm
- **Custom plugins**: zsh-autosuggestions, zsh-syntax-highlighting

### Component: PowerShell

- **Prompt**: oh-my-posh with configurable theme
- **Modules**: PSReadLine (predictions), Az.Tools.Predictor, Terminal-Icons
- **Completions**: Azure CLI, kubectl
- **Prediction**: History + Plugin with ListView

## Creating a New Theme

1. Copy `themes/star-wars.json` to `themes/my-theme.json`
2. Edit the JSON to customize:
   - Background images (local paths or URLs)
   - Color schemes
   - Fonts
   - WSL plugins and tools
   - PowerShell modules and oh-my-posh theme
3. Place background images in `assets/wallpapers/` or provide URLs
4. Run: `.\install.ps1 -Theme my-theme`

## Nerd Fonts

The installer automatically downloads and installs required Nerd Fonts. Included fonts:

- **MesloLGL Nerd Font** — Clean, readable monospace
- **Mononoki Nerd Font** — Distinctive, programmer-friendly

Browse more at [nerdfonts.com](https://www.nerdfonts.com/).

## Background Images

Place background images in `assets/wallpapers/`. The installer copies them to Windows Terminal's roaming state. Images can also be provided via URL in the theme JSON — they'll be downloaded automatically.

## Requirements

- Windows 10/11
- [Windows Terminal](https://aka.ms/terminal)
- [PowerShell 7+](https://aka.ms/powershell)
- [WSL 2](https://docs.microsoft.com/windows/wsl/) with Ubuntu
- [winget](https://github.com/microsoft/winget-cli) (for installing oh-my-posh)

## Backups

The installer creates timestamped backups before modifying:
- Windows Terminal `settings.json`
- PowerShell profile

## License

MIT
