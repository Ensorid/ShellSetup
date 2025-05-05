#!/bin/sh

# --------- Info ---------
APP_NAME="Ensorid Setup"
VERSION="1.0.0"
OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d= -f2- | tr -d '"')
REAL_USER=${SUDO_USER:-$USER}

# --------- OS Detection ---------
if [ "$OS_NAME" = "Ubuntu" ]; then
    echo "OS: $OS_NAME ✅"
else
    echo "❌ $OS_NAME is not supported yet."
    exit 1
fi

# --------- Desktop Detection ---------
if [ "$XDG_CURRENT_DESKTOP" = "ubuntu:GNOME" ]; then
    echo "Desktop: $XDG_CURRENT_DESKTOP ✅"
else
    echo "❌ $XDG_CURRENT_DESKTOP is not supported yet."
    exit 1
fi

echo "User: $REAL_USER"

# --------- Helpers ---------
run_silent() {
    echo -n "$1..."
    eval "$2" > /dev/null 2>&1
    echo " ✅"
}

# --------- Functions ---------
print_header() {
    echo "=============================="
    echo "🚀 $APP_NAME v$VERSION"
    echo "=============================="
}

check_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "❌ This script must not be run as root." >&2
        exit 1
    fi
}

ask_password(){
    echo "🔐 This script needs sudo privileges. Please enter your password."
    sudo -v || exit 1

    while true; do sudo -n true; sleep 60; done 2>/dev/null &
    SUDO_PID=$!
    trap "kill $SUDO_PID" EXIT
}


install_packages() {
    run_silent "🔄 Updating package list" "sudo apt-get update -y"
    run_silent "⬆️ Upgrading" "sudo apt-get full-upgrade -y"
    PACKAGES="curl git build-essential libfuse2 gcc make libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev\
        gnome-software gnome-sushi flatpak gnome-software-plugin-flatpak virt-manager vlc zsh neovim"

    TOTAL=$(echo "$PACKAGES" | wc -w)
    COUNT=1

    for pkg in $PACKAGES; do
        tput cr
        tput el

        printf "📦 Installing (%d/%d): %s" "$COUNT" "$TOTAL" "$pkg"

        if dpkg -s "$pkg" > /dev/null 2>&1; then
            :
        else
            sudo apt-get install -y "$pkg" > /dev/null 2>&1
        fi

        COUNT=$((COUNT + 1))
    done

    tput cr
    tput el
    printf "✅ All %d packages installed.\n" "$TOTAL"
}

remove_packages() {
    run_silent "🧹 Removing useless APT packages" "sudo apt-get remove -y firefox gnome-characters gnome-logs gnome-system-monitor sysprof"
    run_silent "🧹 Removing useless SNAP packages" "sudo snap remove firefox snap-store || true"
}

setup_dev() {
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    run_silent "💻 Installing VSCode" "sudo apt update -y && sudo apt-get install -y code"
}

install_flatpak() {
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    run_silent "📦 Installing flatpak applications" "sudo flatpak install -y --noninteractive flathub app.zen_browser.zen io.missioncenter.MissionCenter org.signal.Signal || true"
}

setup_desktop(){
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
    gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
    gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface accent-color 'blue'
    gsettings set org.gnome.desktop.interface icon-theme 'Yaru-blue-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-blue-dark'
    gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'app.zen_browser.zen.desktop', 'org.signal.Signal.desktop', 'org.gnome.Software.desktop', 'code.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Settings.desktop']"

}

setup_shell() {
    run_silent "🐚 Setting up default shell to Zsh" "sudo usermod -s $(which zsh) $REAL_USER"
    run_silent "⚙️ Installing Oh My Zsh" "sh -c 'RUNZSH=no CHSH=no bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"'"
}

install_vmtools() {
    run_silent "🟢 Installing NVM" "bash -c \"curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash\""
    echo 'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"' >> ~/.zshrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'  >> ~/.zshrc
    run_silent "🐍 Installing Pyenv" "curl -sSL https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash"
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
    echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
    echo 'eval "$(pyenv init - zsh)"' >> ~/.zshrc
}

# --------- Execution ---------
print_header
check_not_root
ask_password
install_packages
remove_packages
install_flatpak
setup_dev
setup_desktop
setup_shell
install_vmtools

read -p "🔁 Reboot now? [y/N] " answer
[ "$answer" = "y" ] && reboot
