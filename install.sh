#!/bin/sh

# This install script is intended to download and install the latest available
# release of the ops.
# Installer script inspired from:
#  1) https://wasmer.io/
#  2) https://sh.rustup.rs
#  3) https://yarnpkg.com/install.sh
#  4) https://raw.githubusercontent.com/brainsik/virtualenv-burrito/master/virtualenv-burrito.sh
#
# It attempts to identify the current platform and an error will be thrown if
# the platform is not supported.
#
# Environment variables:
# - INSTALL_DIRECTORY (optional): defaults to $HOME/.ops

reset="\033[0m"
red="\033[31m"
green="\033[32m"
yellow="\033[33m"
cyan="\033[36m"
white="\033[37m"
bold="\e[1m"
dim="\e[2m"

RELEASES_URL="https://storage.googleapis.com/cli"


initOS() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    if [ -n "$OPS_OS" ]; then
        printf "$cyan> Using OPS_OS ($OPS_OS).$reset\n"
        OS="$OPS_OS"
    fi
    case "$OS" in
        darwin) OS='darwin';;
        linux) OS='linux';;
        *) printf "$red> The OS (${OS}) is not supported ops.$reset\n"; exit 1;;
    esac
}

download_file() {
    url="$1"
    destination="$2"

    echo "Fetching $url.."
    if test -x "$(command -v curl)"; then
        code=$(curl --progress-bar -w '%{http_code}' -L "$url" -o "$destination")
    elif test -x "$(command -v wget)"; then
        code=$(wget --show-progress --progress=bar:force:noscroll -q -O "$destination" --server-response "$url" 2>&1 | awk '/^  HTTP/{print $2}' | tail -1)
    else
        printf "$red> Neither curl nor wget was available to perform http requests.$reset\n"
        exit 1
    fi

    if [ "$code" != 200 ]; then
        printf "$red>File download failed with code $code.$reset\n"
        exit 1
    fi
}

ops_download() {


  # determine install directory if required
  if [ -z "$INSTALL_DIRECTORY" ]; then
      INSTALL_DIRECTORY="$HOME/.ops"
  fi
  OPS=INSTALL_DIRECTORY
  
  # TODO: Track release TAGS and update.
  # use github release tags

  # assemble expected release URL
  BINARY_URL="$RELEASES_URL/${OS}/ops"
  
  DOWNLOAD_FILE=$(mktemp -t ops.XXXXXXXXXX)

  download_file "$BINARY_URL" "$DOWNLOAD_FILE"
  printf "\033[2A$cyan> Downloading latest release... ✓$reset\033[K\n"
  printf "\033[K\n\033[1A"
  chmod +x "$DOWNLOAD_FILE"

  INSTALL_NAME="ops"
  mkdir -p $INSTALL_DIRECTORY/bin
  mv "$DOWNLOAD_FILE" "$INSTALL_DIRECTORY/bin/$INSTALL_NAME"
}


ops_detect_profile() {
  if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
    echo "${PROFILE}"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''
  local SHELLTYPE
  SHELLTYPE="$(basename "/$SHELL")"

  if [ "$SHELLTYPE" = "bash" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ "$SHELLTYPE" = "zsh" ]; then
    DETECTED_PROFILE="$HOME/.zshrc"
  elif [ "$SHELLTYPE" = "fish" ]; then
    DETECTED_PROFILE="$HOME/.config/fish/config.fish"
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    if [ -f "$HOME/.profile" ]; then
      DETECTED_PROFILE="$HOME/.profile"
    elif [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    elif [ -f "$HOME/.zshrc" ]; then
      DETECTED_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.config/fish/config.fish" ]; then
      DETECTED_PROFILE="$HOME/.config/fish/config.fish"
    fi
  fi

  if [ ! -z "$DETECTED_PROFILE" ]; then
    echo "$DETECTED_PROFILE"
  fi
}

ops_detect_supported_linux_distribution() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DETECTED_DISTRIBUTION=$NAME
  elif type lsb_release >/dev/null 2>&1; then
    DETECTED_DISTRIBUTION=$(lsb_release -si)
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    DETCTED_DISTRIBUTION=$DISTRIB_ID
  elif [ -f /etc/debian_version ]; then
    DETECTED_DISTRIBUTION=debian
  elif [ -f /etc/fedora-release ]; then
    DETECTED_DISTRIBUTION=fedora
  elif [ -f /etc/centos-release ]; then
    DETECTED_DISTRIBUTION=centos
  fi

  echo "$DETECTED_DISTRIBUTION"
}

ops_brew_install_qemu() {
  if which brew >/dev/null; then
    brew install qemu
  else
    printf "Homebrew not found.Please install from https://brew.sh/"
  fi
}

ops_apt_install_qemu(){
  apt install qemu -y --no-upgrade
}

ops_dnf_install_qemu(){
  dnf install qemu-kvm qemu-img -y
}

ops_yum_install_qemu(){
  yum install qemu-kvm qemu-img -y
}

ops_install_qemu() {
  if which qemu-system-x86_64>/dev/null; then
    return
  fi
  # install qemu on mac or supported linux distributions
  if [ "$OS" = "darwin" ]; then
    ops_brew_install_qemu
  else
    LINUX_DISTRIBUTION=`echo $(ops_detect_supported_linux_distribution) | tr '[:upper:]' '[:lower:]'`
    case "$LINUX_DISTRIBUTION" in
      *ubuntu*)
        ops_apt_install_qemu
        ;;
      *fedora*)
        ops_dnf_install_qemu
        ;;
      *centos*)
        ops_yum_install_qemu
        ;;
      *debian*)
        ops_apt_install_qemu
        ;;
    esac
  fi

  if ! which qemu-system-x86_64>/dev/null; then
    printf "QEMU not found. Please install qemu using your package manager and re-run this script"
  fi
}

ops_install_haxm() {
    if [ "$OS" != "darwin" ]; then
        return
    fi

    # check to see if a version of the package was previously
    # installed or if the haxm kext was otherwise loaded. 
    existing_install=`pkgutil --pkgs | grep haxm`
    loaded_module=`kextstat | grep intelhaxm`
    if [ ! -z $existing_install ] || [ ! -z $loaded_module ]; then
        return
    fi

    # get the binary package. No need to check the md5 since the we are going
    # for the included .dmg which is signed.
    curl -LJO https://github.com/intel/haxm/releases/download/v7.4.1/haxm-macosx_v7_4_1.zip
    tar -xvf haxm-macosx_v7_4_1.zip -C /tmp
    hdiutil attach /tmp/IntelHAXM_7.4.1.dmg
    installer -package /Volumes/IntelHAXM_7.4.1/IntelHAXM_7.4.1.mpkg -target /
    hdiutil detach /Volumes/IntelHAXM_7.4.1/
}

ops_link() {
  printf "$cyan> Adding to bash profile...$reset\n"
  OPS_PROFILE="$(ops_detect_profile)"
  SOURCE_STR="# OPS config\nexport OPS_DIR=\"\$HOME/.ops\"\nexport PATH=\"\$HOME/.ops/bin:\$PATH\"\n"

  # Create the ops.sh file
  echo "$SOURCE_STR" > "$HOME/.ops/ops.sh"

  if [ -z "${OPS_PROFILE-}" ] ; then
    printf "${red}Profile not found. Tried:\n* ${OPS_PROFILE} (as defined in \$PROFILE)\n* ~/.bashrc\n* ~/.bash_profile\n* ~/.zshrc\n* ~/.profile.\n"
    echo "\nHow to solve this issue?\n* Create one of them and run this script again"
    echo "* Create it (touch ${OPS_PROFILE}) and run this script again"
    echo "  OR"
    printf "* Append the following lines to the correct file yourself:$reset\n"
    command printf "${SOURCE_STR}"
  else
    if ! grep -q 'ops.sh' "$OPS_PROFILE"; then
      command printf "$SOURCE_STR" >> "$OPS_PROFILE"
    fi
    printf "\033[1A$cyan> Adding to bash profile... ✓$reset\n"
    printf "${dim}Note: We've added the following to your $OPS_PROFILE\n"
    echo "If this isn't the profile of your current shell then please add the following to your correct profile:"
    printf "   $SOURCE_STR$reset\n"

    version=`$HOME/.ops/bin/ops version` || (
      printf "$red> ops was installed, but doesn't seem to be working :($reset\n"
      exit 1;
    )
    printf "$green> Successfully installed ops $version! Please open another terminal where the \`ops\` command will now be available.$reset\n"
  fi
}

ops_install() {
  magenta1="${reset}\033[34;1m"
  magenta2="${reset}\033[34m"
  magenta3="${reset}\033[34;2m"

  if which ops >/dev/null; then
    printf "${reset}Updating ops$reset\n"
  else
    printf "${reset}Installing ops!$reset\n"
  fi

  # identify platform based on uname output
  initOS
  ops_install_qemu
  ops_install_haxm
  ops_download
  ops_link
}

ops_install
