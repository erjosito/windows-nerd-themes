<#
.SYNOPSIS
    Configure WSL with oh-my-zsh, plugins, and tools.
#>
param(
    [Parameter(Mandatory)]
    [PSCustomObject]$Config,

    [switch]$DryRun
)

$distro = $Config.distro
if (-not $distro) { $distro = "Ubuntu" }

# Check if WSL distro exists
$wslList = wsl --list --quiet 2>$null
if ($wslList -notcontains $distro) {
    Write-Warning "WSL distro '$distro' not found. Available distros:"
    wsl --list --verbose
    return
}

# Generate the configuration script to run inside WSL
$wslScript = @"
#!/bin/bash
set -e

echo "  Configuring WSL ($distro)..."

# Install zsh if not present
if ! command -v zsh &>/dev/null; then
    echo "    Installing zsh..."
    sudo apt-get update -qq && sudo apt-get install -y -qq zsh
fi

# Install oh-my-zsh if not present
if [ ! -d "\$HOME/.oh-my-zsh" ]; then
    echo "    Installing oh-my-zsh..."
    sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install powerlevel10k theme
THEME_DIR="\$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [ ! -d "\$THEME_DIR" ]; then
    echo "    Installing powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "\$THEME_DIR"
fi

# Install custom plugins
"@

# Add custom plugin installations
if ($Config.oh_my_zsh.custom_plugins) {
    foreach ($plugin in $Config.oh_my_zsh.custom_plugins) {
        $wslScript += @"

PLUGIN_DIR="`$HOME/.oh-my-zsh/custom/plugins/$($plugin.name)"
if [ ! -d "`$PLUGIN_DIR" ]; then
    echo "    Installing plugin: $($plugin.name)..."
    git clone --depth=1 $($plugin.repo) "`$PLUGIN_DIR"
fi
"@
    }
}

# Install tools
if ($Config.tools.tmux.enabled) {
    $wslScript += @"

# Install tmux
if ! command -v tmux &>/dev/null; then
    echo "    Installing tmux..."
    sudo apt-get install -y -qq tmux
fi
"@
}

if ($Config.tools.kubectl.enabled) {
    $wslScript += @"

# Install kubectl
if ! command -v kubectl &>/dev/null; then
    echo "    Installing kubectl..."
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq kubectl
fi
"@
}

if ($Config.tools.nvm.enabled) {
    $wslScript += @"

# Install nvm
if [ ! -d "\$HOME/.nvm" ]; then
    echo "    Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
"@
}

# Build .zshrc content
$plugins = ($Config.oh_my_zsh.plugins -join " ")
$pathAdditions = ($Config.path_additions -join ":")

$zshrcContent = @"
# Enable Powerlevel10k instant prompt
if [[ -r "`${XDG_CACHE_HOME:-`$HOME/.cache}/p10k-instant-prompt-`${(%):-%n}.zsh" ]]; then
  source "`${XDG_CACHE_HOME:-`$HOME/.cache}/p10k-instant-prompt-`${(%):-%n}.zsh"
fi

# Path
export PATH="${pathAdditions}:`$PATH"

# oh-my-zsh configuration
export ZSH="`$HOME/.oh-my-zsh"
ZSH_THEME="$($Config.oh_my_zsh.theme)"

# Plugins
plugins=($plugins)

"@

# Add oh-my-zsh settings
if ($Config.oh_my_zsh.settings) {
    foreach ($setting in $Config.oh_my_zsh.settings.PSObject.Properties) {
        $zshrcContent += "$($setting.Name)=`"$($setting.Value)`"`n"
    }
}

$zshrcContent += @"

source `$ZSH/oh-my-zsh.sh

"@

# Add aliases
if ($Config.aliases) {
    $zshrcContent += "# Aliases`n"
    foreach ($alias in $Config.aliases.PSObject.Properties) {
        $zshrcContent += "alias $($alias.Name)=$($alias.Value)`n"
    }
}

$zshrcContent += @"

# Powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# NVM
export NVM_DIR="`$HOME/.nvm"
[ -s "`$NVM_DIR/nvm.sh" ] && \. "`$NVM_DIR/nvm.sh"
[ -s "`$NVM_DIR/bash_completion" ] && \. "`$NVM_DIR/bash_completion"

cd
"@

$wslScript += @"

# Write .zshrc
echo "    Writing .zshrc..."
cat > "\$HOME/.zshrc" << 'ZSHRC_EOF'
$zshrcContent
ZSHRC_EOF

# Set zsh as default shell
if [ "\$SHELL" != "/usr/bin/zsh" ] && [ "\$SHELL" != "/bin/zsh" ]; then
    echo "    Setting zsh as default shell..."
    sudo chsh -s \$(which zsh) \$(whoami)
fi

echo "  ✓ WSL configured successfully"
"@

if ($DryRun) {
    Write-Host "    [DRY RUN] Would run configuration script in WSL ($distro)" -ForegroundColor Yellow
    Write-Host "    Theme: $($Config.oh_my_zsh.theme)" -ForegroundColor Gray
    Write-Host "    Plugins: $plugins" -ForegroundColor Gray
    Write-Host "    Tools: tmux=$($Config.tools.tmux.enabled), kubectl=$($Config.tools.kubectl.enabled)" -ForegroundColor Gray
} else {
    # Write script to temp and execute in WSL
    $tempScript = "$env:TEMP\wsl_configure.sh"
    $wslScript | Set-Content $tempScript -Encoding UTF8 -NoNewline

    # Convert Windows path to WSL path and execute
    $wslTempPath = wsl wslpath -u ($tempScript -replace '\\', '/')
    wsl -d $distro bash -c "chmod +x '$wslTempPath' && '$wslTempPath'"

    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}

Write-Host "  ✓ WSL ($distro) configured" -ForegroundColor Green
