#!/usr/bin/env bash
# AIra Lug - macOS and Linux installer.
# Checks Git, Obsidian, QMD (with Node.js >= 22) and Hermes Agent, and offers
# to install each missing program. Default answer is "yes".
#
# Remote usage:
#   curl -fsSL https://raw.githubusercontent.com/CarlosLongarela/aira-lug/main/install/install.sh | bash
#
# Compatible with the bash 3.2 shipped with macOS.

NODE_MIN_MAJOR=22
NVM_VERSION="v0.40.3"
HERMES_INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

RESULTS=""
OS="$(uname -s)"
PM=""
SUDO=""

if [ -t 1 ]; then
	C_RESET="$(printf '\033[0m')"
	C_CYAN="$(printf '\033[36m')"
	C_GREEN="$(printf '\033[32m')"
	C_YELLOW="$(printf '\033[33m')"
	C_RED="$(printf '\033[31m')"
	C_BOLD="$(printf '\033[1m')"
else
	C_RESET="" C_CYAN="" C_GREEN="" C_YELLOW="" C_RED="" C_BOLD=""
fi

info() { printf '  %s%s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
ok()   { printf '  %s[OK] %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '  %s[!] %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
err()  { printf '  %s[X] %s%s\n' "$C_RED" "$*" "$C_RESET"; }
step() { printf '\n%s== %s ==%s\n' "$C_BOLD" "$*" "$C_RESET"; }

add_result() { RESULTS="${RESULTS}$(printf '  %-10s %s' "$1" "$2")
"; }

has() { command -v "$1" >/dev/null 2>&1; }

# Ask a yes/no question. Empty answer means yes.
# Reads from /dev/tty so it works when the script is piped into bash.
ask_yes_no() {
	local answer
	if [ ! -r /dev/tty ]; then
		warn "Sin terminal interactiva: se asume Sí para \"$1\"."
		return 0
	fi
	while true; do
		printf '  %s [S/n] ' "$1" >/dev/tty
		IFS= read -r answer </dev/tty || answer=""
		case "$answer" in
			""|[Ss]|[Ss][Ii]|[Ss]í|[Ss]Í|[Yy]|[Yy][Ee][Ss]) return 0 ;;
			[Nn]|[Nn][Oo]) return 1 ;;
			*) warn "Responde S (sí) o N (no)." ;;
		esac
	done
}

# --- Platform helpers -------------------------------------------------------

detect_platform() {
	if [ "$(id -u)" -ne 0 ] && has sudo; then
		SUDO="sudo"
	fi
	case "$OS" in
		Darwin) PM="brew" ;;
		Linux)
			if has apt-get; then PM="apt"
			elif has dnf; then PM="dnf"
			elif has pacman; then PM="pacman"
			elif has zypper; then PM="zypper"
			fi
			;;
		*)
			err "Sistema no soportado: $OS. En Windows usa install.ps1."
			exit 1
			;;
	esac
}

load_brew_env() {
	if [ -x /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [ -x /usr/local/bin/brew ]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi
}

ensure_brew() {
	load_brew_env
	if has brew; then return 0; fi
	warn "Homebrew no se encuentra y es necesario para instalar en macOS."
	if ! ask_yes_no "¿Quieres instalar Homebrew?"; then return 1; fi
	/bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")" </dev/tty
	load_brew_env
	has brew
}

pkg_install() {
	case "$PM" in
		brew)   ensure_brew && brew install "$@" ;;
		apt)    $SUDO apt-get update && $SUDO apt-get install -y "$@" ;;
		dnf)    $SUDO dnf install -y "$@" ;;
		pacman) $SUDO pacman -S --noconfirm --needed "$@" ;;
		zypper) $SUDO zypper install -y "$@" ;;
		*)
			err "No se ha detectado un gestor de paquetes compatible (apt, dnf, pacman, zypper)."
			return 1
			;;
	esac
}

ensure_curl() {
	if has curl; then return 0; fi
	warn "curl es necesario y no se encuentra; se instalará."
	pkg_install curl
}

# --- Program checks ---------------------------------------------------------

git_ok() {
	has git || return 1
	# On macOS /usr/bin/git is a stub until the Command Line Tools are installed.
	if [ "$OS" = "Darwin" ] && [ "$(command -v git)" = "/usr/bin/git" ]; then
		xcode-select -p >/dev/null 2>&1 || return 1
	fi
	git --version >/dev/null 2>&1
}

obsidian_ok() {
	if [ "$OS" = "Darwin" ]; then
		[ -d "/Applications/Obsidian.app" ] || [ -d "$HOME/Applications/Obsidian.app" ]
		return
	fi
	has obsidian && return 0
	has flatpak && flatpak info md.obsidian.Obsidian >/dev/null 2>&1 && return 0
	has snap && snap list obsidian >/dev/null 2>&1 && return 0
	ls "$HOME"/Applications/Obsidian*.AppImage >/dev/null 2>&1 && return 0
	return 1
}

node_major() {
	has node || { echo 0; return; }
	node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0
}

load_nvm() {
	export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
	# shellcheck disable=SC1091
	[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
}

# --- Program steps ----------------------------------------------------------

step_git() {
	step "Git"
	if git_ok; then
		ok "$(git --version)"
		add_result "Git" "ya instalado"
		return
	fi
	warn "Git no se encuentra en el sistema."
	if ! ask_yes_no "¿Quieres instalar Git?"; then add_result "Git" "omitido"; return; fi
	if pkg_install git && git_ok; then
		ok "$(git --version)"
		add_result "Git" "instalado"
	else
		err "No se pudo instalar Git. Descárgalo desde https://git-scm.com/downloads"
		add_result "Git" "error"
	fi
}

install_obsidian_linux() {
	if has flatpak; then
		flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
			&& flatpak install --user -y flathub md.obsidian.Obsidian
		return
	fi
	if has snap; then
		$SUDO snap install obsidian --classic
		return
	fi
	err "No hay flatpak ni snap disponibles."
	info "Descarga el AppImage o el .deb desde https://obsidian.md/download"
	return 1
}

step_obsidian() {
	step "Obsidian"
	if obsidian_ok; then
		ok "Obsidian está instalado."
		add_result "Obsidian" "ya instalado"
		return
	fi
	warn "Obsidian no se encuentra en el sistema."
	if ! ask_yes_no "¿Quieres instalar Obsidian?"; then add_result "Obsidian" "omitido"; return; fi
	if [ "$OS" = "Darwin" ]; then
		ensure_brew && brew install --cask obsidian
	else
		install_obsidian_linux
	fi
	if obsidian_ok; then
		ok "Obsidian instalado."
		add_result "Obsidian" "instalado"
	else
		err "No se pudo instalar Obsidian. Descárgalo desde https://obsidian.md/download"
		add_result "Obsidian" "error"
	fi
}

# Node.js >= 22 is a QMD prerequisite.
ensure_node() {
	local major
	load_nvm
	major="$(node_major)"
	if [ "$major" -ge "$NODE_MIN_MAJOR" ]; then
		ok "Node.js $(node --version)"
		return 0
	fi
	if [ "$major" -gt 0 ]; then
		warn "QMD necesita Node.js $NODE_MIN_MAJOR o superior; tienes $(node --version)."
	else
		warn "QMD necesita Node.js y no se encuentra en el sistema."
	fi
	if ! ask_yes_no "¿Quieres instalar Node.js LTS?"; then return 1; fi

	if [ "$OS" = "Darwin" ]; then
		ensure_brew && brew install node
	else
		# nvm installs a current LTS per user, without sudo and without
		# depending on the (often outdated) distribution package.
		ensure_curl || return 1
		if [ ! -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
			curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
		fi
		load_nvm
		has nvm && nvm install --lts && nvm alias default 'lts/*' >/dev/null
	fi
	hash -r 2>/dev/null
	if [ "$(node_major)" -ge "$NODE_MIN_MAJOR" ]; then
		ok "Node.js $(node --version)"
		return 0
	fi
	err "No se pudo instalar Node.js $NODE_MIN_MAJOR o superior."
	return 1
}

step_qmd() {
	local npm_prefix npm_sudo=""
	step "QMD"
	load_nvm
	if has qmd; then
		ok "QMD $(qmd --version 2>/dev/null)"
		add_result "QMD" "ya instalado"
		return
	fi
	warn "QMD no se encuentra en el sistema."
	if ! ask_yes_no "¿Quieres instalar QMD?"; then add_result "QMD" "omitido"; return; fi
	if ! ensure_node; then
		err "QMD no se instala sin Node.js $NODE_MIN_MAJOR o superior."
		add_result "QMD" "error (falta Node.js)"
		return
	fi
	# macOS system SQLite lacks extension loading; QMD needs Homebrew's.
	if [ "$OS" = "Darwin" ]; then
		ensure_brew && brew install sqlite
	fi
	npm_prefix="$(npm prefix -g 2>/dev/null)"
	if [ -n "$npm_prefix" ] && [ ! -w "$npm_prefix/lib" ] && [ ! -w "$npm_prefix" ]; then
		npm_sudo="$SUDO"
	fi
	$npm_sudo npm install -g @tobilu/qmd
	hash -r 2>/dev/null
	if has qmd; then
		ok "QMD $(qmd --version 2>/dev/null)"
		add_result "QMD" "instalado"
	else
		err "No se pudo instalar QMD. Revisa la salida de npm."
		add_result "QMD" "error"
	fi
}

step_hermes() {
	step "Hermes Agent"
	export PATH="$HOME/.local/bin:$PATH"
	if has hermes; then
		ok "Hermes Agent está instalado."
		add_result "Hermes" "ya instalado"
		return
	fi
	warn "Hermes Agent no se encuentra en el sistema."
	if ! ask_yes_no "¿Quieres instalar Hermes Agent?"; then add_result "Hermes" "omitido"; return; fi
	ensure_curl || { add_result "Hermes" "error"; return; }
	curl -fsSL "$HERMES_INSTALL_URL" | bash
	hash -r 2>/dev/null
	if has hermes; then
		ok "Hermes Agent instalado."
		add_result "Hermes" "instalado"
	else
		warn "Instalador ejecutado, pero \"hermes\" no aparece en el PATH. Abre una terminal nueva para comprobarlo."
		add_result "Hermes" "revisar"
	fi
}

# --- Main -------------------------------------------------------------------

main() {
	printf '\n%sAIra Lug - instalador para %s%s\n' "$C_BOLD" "$OS" "$C_RESET"
	echo "Se comprobará Git, Obsidian, QMD y Hermes Agent."

	detect_platform
	step_git
	step_obsidian
	step_qmd
	step_hermes

	step "Resumen"
	printf '%s' "$RESULTS"
	echo
	info "Abre una terminal nueva para que el PATH actualizado tenga efecto."
	info "Siguientes pasos: https://github.com/CarlosLongarela/aira-lug#readme"
	echo
}

main "$@"
