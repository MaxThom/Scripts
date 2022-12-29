#!/bin/bash

BIN_PATH=/usr/local/bin/
UPDATE=false

# COLORS
# Reset
Color_Off='\033[0m'       # Text Reset
# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Github download, how to download latest if and only if the name of the assets are always the same between releases
#   curl -fsSL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_x86_64.tar.gz | tar -xzf - k9s
# Github download, how to download latest if the name of the assets contain the version name, but have same prefix or suffix.
#   curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | grep "browser_download_url.*linux-amd64.tar.gz.asc" | cut -d : -f 2,3 | tr -d \" | wget -i -

echo -e "${BBlue}Tuiling!${Color_Off}"

help () {
    echo -e "${BWhite}NAME${Color_Off}"
    echo -e "\tTuiling - Software Easy Installer for Tui"
    echo -e "${BWhite}SYNOPSIS${Color_Off}"
    echo -e "\ttuiling [FLAGS] [SOFTWARES]"
    echo -e "${BWhite}FLAGS${Color_Off}"
    echo -e "\t--update, -u\tuninstall and reinstall the latest version of each software"
    echo -e "\t--help, -h\tdisplay manual"
    echo -e "${BWhite}SOFTWARES${Color_Off}"
    echo -e "\tIf no software is specified, all softwares are installed.\n"
    echo -e "\tkubectl\t\tkubernetes cli to interact with your cluster"
    echo -e "\thelm\t\tpackage manager for kubernetes"
    echo -e "\tkrew\t\tplugin manager for kubectl"
    echo -e "\tk9s\t\tterminal base UI to interact with your cluster"
    echo -e "\tkubeseal\tutility cli to encrypt secrets with the sealed secrets controller"
    echo -e "\targocd\t\tcli to interact with ArgoCD, the declarative continuous delivery tool for kubernetes"
    echo -e "\tktop\t\ta top like tool to follow your cluster (requires KREW)"
    echo -e "\tctx\t\tan utility tool to easy change your kubernetes context (requires KREW)"
    echo -e "\tns\t\tan utility tool to easy change your kubernetes namespace (requires KREW)"
    echo -e "\tkonfig\t\tan utility tool to help to merge, split or import kubeconfig files (requires KREW)"
}

install_krew_plugin() {
    local APP=$1
    if [[ -f "${KREW_ROOT:-$HOME/.krew}/bin/kubectl-$APP" ]] && [[ "$UPDATE" = false ]]; then
        echo -e "${BBlack}> $APP already installed. ✔️ ${Purple}"
        echo "$(kubectl krew info $APP | grep VERSION)"
        echo -e "${Color_Off}"
    fi

    if [[ "$UPDATE" = true ]] ; then
        kubectl krew uninstall $APP
    fi

    if [[ ! -f "${KREW_ROOT:-$HOME/.krew}/bin/kubectl-$APP" ]]; then
        echo -e "${BBlack}> installing $APP...${Black}"
        kubectl krew install $APP
        echo -e "${Color_Off}  $APP installed! ✔️"
    fi
}

# Kubectl
install_kubectl() {
    local APP=kubectl

    if [[ -f "$BIN_PATH$APP" ]] && [[ "$UPDATE" = false ]]; then
        echo -e "${BBlack}> $APP already installed. ✔️ ${Purple}"
        echo "$(kubectl version --client --short)"
        echo -e "${Color_Off}"
    fi

    if [[ "$UPDATE" = true ]] ; then
        sudo rm -f "$BIN_PATH$APP"
    fi

    if [[ ! -f "$BIN_PATH$APP" ]]; then
        echo -e "${BBlack}> installing $APP...${Black}"
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm $APP
        echo -e "${BBlack}  $APP installed! ✔️${Color_Off}"
    fi
}

install_k9s() {
    # K9S
    local APP=k9s
    if [[ -f "$BIN_PATH$APP" ]] && [[ "$UPDATE" = false ]]; then
        echo -e "${BBlack}> $APP already installed. ✔️ ${Purple}"
        echo "$(k9s version --short)"
        echo -e "${Color_Off}"
    fi

    if [[ "$UPDATE" = true ]] ; then
        sudo rm -f "$BIN_PATH$APP"
    fi

    if [[ ! -f "$BIN_PATH$APP" ]]; then
        echo -e "${BBlack}> installing $APP...${Black}"
        curl -fsSL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_x86_64.tar.gz | tar -xzf - k9s
        mv "$APP" "$BIN_PATH"
        echo -e "${BBlack}  $APP installed! ✔️${Color_Off}"
    fi
}

install_helm() {
    # Helm
    local APP=helm
    if [[ -f "$BIN_PATH$APP" ]] && [[ "$UPDATE" = false ]]; then
        echo -e "${BBlack}> $APP already installed. ✔️ ${Purple}"
        echo "$(helm version --short)"
        echo -e "${Color_Off}"
    fi

    if [[ "$UPDATE" = true ]] ; then
        sudo rm -f "$BIN_PATH$APP"
    fi

    if [[ ! -f "$BIN_PATH$APP" ]]; then
        echo -e "${BBlack}> installing $APP...${Black}"
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
        chmod +700 get_helm.sh
        ./get_helm.sh
        rm get_helm.sh
        echo -e "${BBlack}  $APP installed! ✔️${Color_Off}"
    fi
}

install_krew() {
    # Krew
    local APP=krew
    if [[ -f "${KREW_ROOT:-$HOME/.krew}/bin/kubectl-$APP" ]] && [[ "$UPDATE" = false ]]; then
        echo -e "${BBlack}> $APP already installed. ✔️ ${Purple}"
        export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
        echo "$(kubectl krew info krew | grep VERSION)"
        echo -e "${Color_Off}"
    fi

    if [[ "$UPDATE" = true ]] ; then
        sudo rm -rf "${KREW_ROOT:-$HOME/.krew}"
    fi

    if [[ ! -f "${KREW_ROOT:-$HOME/.krew}/bin/kubectl-$APP" ]]; then
        echo -e "${BBlack}> installing $APP...${Black}"
        cd "$(mktemp -d)" &&
        OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
        ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
        KREW="krew-${OS}_${ARCH}" &&
        curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
        tar zxvf "${KREW}.tar.gz" &&
        ./"${KREW}" install krew

        export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
        echo "export PATH='${KREW_ROOT:-$HOME/.krew}/bin:$PATH'" >> ~/.profile
        source ~/.profile
        echo -e "${BBlack}  $APP installed! ✔️${Color_Off}"
    fi
}

install_argocd() {
    # Argocd
    APP=argocd
    if [[ -f "$BIN_PATH$APP" ]] && [[ "$UPDATE" = false ]]; then
        echo -e "${BBlack}> $APP already installed. ✔️ ${Purple}"
        echo "$(argocd version --short)"
        echo -e "${Color_Off}"
    fi

    if [[ "$UPDATE" = true ]] ; then
        sudo rm -f "$BIN_PATH$APP"
    fi

    if [[ ! -f "$BIN_PATH$APP" ]]; then
        echo -e "${BBlack}> installing $APP...${Black}"
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd #sudo
        rm argocd-linux-amd64
        echo -e "${BBlack}  $APP installed! ✔️${Color_Off}"
    fi
}

install_kubeseal() {
    # Kubeseal
    APP=kubeseal
    if [[ -f "$BIN_PATH$APP" ]] && [[ "$UPDATE" = false ]]; then
        echo -e "${BBlack}> $APP already installed. ✔️ ${Purple}"
        echo "$(kubeseal --version)"
        echo -e "${Color_Off}"
    fi

    if [[ "$UPDATE" = true ]] ; then
        sudo rm -f "$BIN_PATH$APP"
    fi

    if [[ ! -f "$BIN_PATH$APP" ]]; then
        echo -e "${BBlack}> installing $APP...${Black}"
        curl -fsSL https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep "browser_download_url.*linux-amd64.tar.gz" | cut -d : -f 2,3 | tr -d \" | wget -i -
        tar -xvzf kubeseal-*-linux-amd64.tar.gz kubeseal
        rm kubeseal-*-linux-amd64.tar.gz
        rm kubeseal-*-linux-amd64.tar.gz.sig
        sudo install -m 755 "$APP" "$BIN_PATH$APP"
        rm "$APP"
        echo -e "${BBlack}  $APP installed! ✔️${Color_Off}"
    fi
}

runAsRoot() {
    #if [ $EUID -ne 0 ]; then
    #    sudo "${@}"
    #    echo "caca"
    #else
    #    "${@}"
    #    echo "pipi"
    #fi

    if [[ $EUID -ne 0 ]]; then
        echo "$0 is not running as root. Try using sudo."
        exit 2
    fi
}

to_install=()
to_install_krew=()
export INPUT_ARGUMENTS="${@}"
echo $INPUT_ARGUMENTS
set -u
while [[ $# -gt 0 ]]; do
  case $1 in
    '--help'|-h)
        # Display manual
        help
        echo -e "${BBlue}Au revoir! ${Color_Off}"
        exit 0
        ;;
    '--update'|-u)
        # Reinstall each software
        UPDATE=true
        ;;
    'kubectl')
        to_install+=("install_kubectl")
        ;;
    'helm')
        to_install+=("install_helm")
        ;;
    'krew')
        to_install+=("install_krew")
        ;;
    'k9s')
        to_install+=("install_k9s")
        ;;
    'kubeseal')
        to_install+=("install_kubeseal")
        ;;
    'argocd')
        to_install+=("install_argocd")
        ;;
    'ktop')
        to_install_krew+=("ktop")
        ;;
    'ctx')
        to_install_krew+=("ctx")
        ;;
    'ns')
        to_install_krew+=("ns")
        ;;
    'konfig')
        to_install_krew+=("konfig")
        ;;
    *)
        echo "Unknown argument. Use --help to see manual."
        exit 1
      ;;
  esac
  shift
done
set +u

#runAsRoot

for t in ${to_install[@]}; do
    $t
done

for t in ${to_install_krew[@]}; do
    install_krew_plugin $t
done

if [[ "${#to_install[@]}" -eq 0 ]] && [[ "${#to_install_krew[@]}" -eq 0 ]]; then
    install_kubectl
    install_helm
    install_krew
    install_k9s
    install_argocd
    install_kubeseal
    install_krew_plugin ktop
    install_krew_plugin ctx
    install_krew_plugin ns
    install_krew_plugin konfig
fi

# Rl-Kubeseal
# Tuiseal

echo -e "${BBlue}Au revoir! ${Color_Off}"