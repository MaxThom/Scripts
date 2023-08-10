#! /bin/bash

# usage:
#  -t K3S_TOKEN
#  -u K3S_SERVER
#  -[i|w|c] ::: Init, Worker or Controller installation
#  -k ::: Install with Static CPU
#  -h ::: Display help
#  -v ::: Verbose
#
# Select one of these options:
#   - init (-i) to start a new cluster.
#   - controller (-c) to add a control node to the cluster. Must specify server url (-u) and token (-t).
#   - worker (-w) to add a worker node to the cluster. Must specify server url (-u) and token (-t).
#
# To add dedicated core install, add the the StaticCPU option (-k).
#
# scp k3s_install.sh user@host:k3s_install.sh
#

k3s_version="v1.23.6+k3s1"
registries_opsw_nexus=""
registries_photon_nexus=""

echo "---"
echo "K3s Install Script!";
echo "---"

install_type_check=0
while getopts ht:u:wcikv flag
do
    case "${flag}" in
        t) token=${OPTARG};;
        u) url=${OPTARG};;
        w) worker="true"
           (( install_type_check++ ))
           ;;
        c) controller="true"
           (( install_type_check++ ))
           ;;
        i) init="true"
           (( install_type_check++ ))
           ;;
        k) kubelet="--config $PWD/config.yaml";;
        h) echo "usage:
           -t K3S_TOKEN
           -u K3S_SERVER
           -[i|w|c] ::: Init, Worker or Controller installation
           -k ::: Install with Static CPU
           -h ::: Display help
           -v ::: Verbose
           "
           exit 0
           ;;
        v) set -x;;
        *) exit 1
           ;;
    esac
done

# Check installation type
if [[ ! install_type_check -eq 1 ]];
then
    echo "Choose Controller (-c), Worker (-w) or Init (-i) installation."
    exit 1
fi

echo "Version: $k3s_version";
echo "Token: $token";
echo "Url: $url";

# Check if we want static cpu config
if [[ -v kubelet ]];
then
    echo "StaticCpu: enabled";
    sudo rm -f /var/lib/kubelet/cpu_manager_state

cat > config.yaml << ENDOFFILE
kubelet-arg: "config=$PWD/kubelet.config"
ENDOFFILE

cat > kubelet.config  << ENDOFFILE
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cpuManagerPolicy: static
reservedSystemCPUs: 0-1
ENDOFFILE

else
    echo "StaticCpu: disabled";
fi

# Create registries file if passwords are set
if [[ -n $registries_opsw_nexus && -n $registries_photon_nexus ]]
then
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/registries.yaml  << ENDOFFILE
mirrors:
  docker.io:
    endpoint:
      - "https://docker.rocketlab.global"
configs:
  "docker.rocketlab.global":
    auth:
      username: ServiceOpswNexus
      password: $registries_opsw_nexus
  "photon.docker.rocketlab.global":
    auth:
      username: ServiceRnchrEdgNexus
      password: $registries_photon_nexus
ENDOFFILE
fi

if [[ -v worker ]];
then
    echo "Worker installation...";
    echo "---"
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$k3s_version" K3S_TOKEN="$token" K3S_URL="$url" sh -s - agent $kubelet
elif [[ -v controller ]];
then
    echo "Controller installation...";
    echo "---"
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$k3s_version" K3S_TOKEN="$token" sh -s - server --server "$url" --disable traefik $kubelet
    echo "--- KubeConfig"
    sudo cat /etc/rancher/k3s/k3s.yaml
    echo "--- NodeToken"
    sudo cat /var/lib/rancher/k3s/server/node-token
elif [[ -v init ]];
then
    echo "Init installation...";
    echo "---"
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$k3s_version" sh -s - server --cluster-init --disable traefik $kubelet
    echo "--- KubeConfig"
    sudo cat /etc/rancher/k3s/k3s.yaml
    echo "--- NodeToken"
    sudo cat /var/lib/rancher/k3s/server/node-token
fi

if [[ -v kubelet ]];
then
    echo "--- CpuManagerState"
    sleep 3s
    sudo cat /var/lib/kubelet/cpu_manager_state
    echo ""
fi

echo "--- Troubleshoot"
echo "sudo systemctl status k3s[-agent]"
echo "sudo journalctl -u k3s[-agent].service"

echo "---"
echo "Au revoir !"
exit 0