#!/usr/bin/env bash
# Install/check Docker and K3s in the Ubuntu 24.04 VirtualBox VM from the previous tutorial.
# This script creates no course working directory, source, Compose file, manifest, or app image.
# During --install it adds a small k() helper to the invoking user's ~/.bashrc.
set -Eeuo pipefail
umask 022
MODE=check
STATE_DIR=/var/lib/container-tutorial
NGINX_IMAGE=docker.io/library/nginx:stable-alpine
CLIENT_IMAGE=docker.io/library/busybox:1.37.0
K3S_VERSION=${K3S_VERSION:-}
usage() {
  cat <<'HELP'
Usage: sudo bash preclass-setup.sh [--check|--install]
  --check    Read-only readiness check (default); creates no course files or workloads.
  --install  Install Docker Engine, Compose and single-node K3s; cache public images;
             test Docker HTTP and K3s container execution using temporary resources;
             add the k() classroom helper to the invoking user's ~/.bashrc.
Environment (optional):
  K3S_VERSION  Exact K3s release chosen by the teaching team.
Recommended: 2+ vCPU, 4 GiB RAM, 20 GiB disk, internet and systemd.
Run inside Ubuntu 24.04, not in a Windows or macOS terminal. Allow 20-30 minutes.
No Docker-group membership or world-readable kubeconfig is added.
An existing unmanaged K3s installation is never reconfigured by --install.
HELP
}
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
say(){ printf '\n%s\n' "$*"; }
resolve_login_user(){
  local candidate=${SUDO_USER:-}
  if [[ -z $candidate || $candidate = root ]];then
    candidate=$(logname 2>/dev/null || true)
  fi
  [[ -n $candidate && $candidate != root ]] || return 1
  getent passwd "$candidate" >/dev/null || return 1
  printf '%s\n' "$candidate"
}
install_k_helper(){
  local target_user target_home target_group bashrc tmp mode
  target_user=$(resolve_login_user) || die 'Run --install with sudo from your normal Ubuntu account so the k helper can be added to that account.'
  target_home=$(getent passwd "$target_user" | awk -F: '{print $6}')
  target_group=$(id -gn "$target_user")
  [[ $target_home = /* && -d $target_home ]] || die "Cannot locate the home directory for $target_user."
  bashrc="$target_home/.bashrc"
  tmp=$(mktemp "$target_home/.bashrc.container-tutorial.XXXXXX")
  if [[ -f $bashrc ]];then
    awk '
      $0 == "# >>> container-tutorial k helper >>>" { skip=1; next }
      $0 == "# <<< container-tutorial k helper <<<" { skip=0; next }
      !skip { print }
    ' "$bashrc" >"$tmp"
    mode=$(stat -c '%a' "$bashrc")
  else
    : >"$tmp"
    mode=0644
  fi
  cat >>"$tmp" <<'BASHRC_BLOCK'

# >>> container-tutorial k helper >>>
# Short form for kubectl commands used in the container tutorial.
k() {
  sudo k3s kubectl -n container-lab "$@"
}
# <<< container-tutorial k helper <<<
BASHRC_BLOCK
  chown "$target_user:$target_group" "$tmp"
  chmod "$mode" "$tmp"
  mv -f -- "$tmp" "$bashrc"
  sudo -u "$target_user" env HOME="$target_home" \
    bash --noprofile --rcfile "$bashrc" -ic 'declare -F k >/dev/null' \
    >/dev/null 2>&1 || die "The k helper was written to $bashrc but could not be sourced in a validation shell."
  printf 'Installed and validated the k helper in %s.\n' "$bashrc"
}
while (($#)); do
  case "$1" in
    --check) MODE=check;shift ;;
    --install) MODE=install;shift ;;
    --help|-h) usage;exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
[[ $EUID -eq 0 ]] || die 'Run with sudo.'
[[ -r /etc/os-release ]] || die 'This script requires Ubuntu 24.04.'
. /etc/os-release
[[ $ID = ubuntu && $VERSION_ID = 24.04 ]] || die 'Supported target: Ubuntu 24.04 VM.'
[[ $(ps -p 1 -o comm=) = systemd ]] || die 'Use a VM booted with systemd.'
[[ $(dpkg --print-architecture) =~ ^(amd64|arm64)$ ]] || die 'Use amd64 or arm64.'
check_ready(){
  local failures=0 inventory
  say 'Readiness checks'
  for cmd in docker k3s curl;do command -v "$cmd" >/dev/null || { printf 'MISSING: %s\n' "$cmd";failures=$((failures+1)); };done
  ((failures==0)) || return 1
  docker info >/dev/null || return 1
  docker compose version
  k3s kubectl --request-timeout=20s get nodes -o wide
  k3s kubectl wait --for=condition=Ready nodes --all --timeout=30s || return 1
  for image in "$NGINX_IMAGE" "$CLIENT_IMAGE";do docker image inspect "$image" >/dev/null || { printf 'MISSING in Docker: %s\n' "$image";failures=$((failures+1)); };done
  inventory=$(k3s ctr -n k8s.io images list -q)
  grep -Fxq "$CLIENT_IMAGE" <<<"$inventory" || { printf 'MISSING in K3s: %s\n' "$CLIENT_IMAGE";failures=$((failures+1)); }
  k3s kubectl --request-timeout=20s get pods -n kube-system
  if ss -H -ltn | awk '{print $4}' | grep -Eq ':(8081|8082|8083)$';then printf 'NOTICE: a tutorial port is occupied. Stop that process before class.\n';fi
  ((failures==0)) || return 1
  say 'READY for class. The handout will create ~/container-tutorial-lab during class.'
}
if [[ $MODE = check ]];then check_ready;exit;fi
say 'Step 1/6: Checking the Ubuntu VM'
[[ $(nproc) -ge 2 ]] || die 'Allocate at least 2 vCPUs.'
[[ $(awk '/MemTotal/ {print $2}' /proc/meminfo) -ge 3500000 ]] || die 'Allocate at least 4 GiB RAM.'
[[ $(df -Pk /var | awk 'END {print $4}') -ge 6000000 ]] || die 'Free at least 6 GiB under /var.'
if command -v ufw >/dev/null && ufw status | grep -q 'Status: active';then die 'UFW is active. Ask a TA to configure K3s networking.';fi
if systemctl is-active --quiet firewalld;then die 'firewalld is active. Ask a TA to configure K3s networking.';fi
if [[ -e /etc/rancher/k3s/k3s.yaml || -e /var/lib/rancher/k3s || -x /usr/local/bin/k3s ]];then
  [[ -f $STATE_DIR/k3s-owned ]] || die 'K3s already exists outside this script. Ask a TA to review it.'
fi
say 'Step 2/6: Installing Docker Engine and Compose'
install -d -m 0755 "$STATE_DIR"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl iproute2
if ! command -v docker >/dev/null;then
  for pkg in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc;do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed';then die "Conflicting package $pkg is installed. Ask a TA to review it.";fi
  done
  [[ ! -e /etc/apt/sources.list.d/docker.list ]] || die 'Existing Docker apt source found. Ask a TA to review it.'
  install -m 0755 -d /etc/apt/keyrings
  curl --fail --show-error --silent --location --retry 3 --connect-timeout 15 --max-time 120 \
    https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat >/etc/apt/sources.list.d/docker.sources <<APT
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
APT
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
docker info >/dev/null
docker compose version >/dev/null || die 'Docker Compose plugin is missing.'
TMP_DIR=$(mktemp -d)
SMOKE_NS=
SMOKE_CONTAINER=
cleanup(){
  local rc=$?
  trap - EXIT
  [[ -z $SMOKE_NS ]] || k3s kubectl delete namespace "$SMOKE_NS" --wait=false >/dev/null 2>&1 || true
  [[ -z $SMOKE_CONTAINER ]] || docker rm -f "$SMOKE_CONTAINER" >/dev/null 2>&1 || true
  rm -rf -- "$TMP_DIR"
  ((rc==0)) || printf '\nPreparation stopped. Fix the reported error and rerun.\n' >&2
  exit "$rc"
}
trap cleanup EXIT
say 'Step 3/6: Installing and starting single-node K3s'
if ! command -v k3s >/dev/null || ! systemctl cat k3s >/dev/null 2>&1;then
  curl --fail --show-error --silent --location --retry 3 --connect-timeout 15 --max-time 120 https://get.k3s.io -o "$TMP_DIR/install-k3s.sh"
  touch "$STATE_DIR/k3s-owned"
  cp "$TMP_DIR/install-k3s.sh" "$STATE_DIR/install-k3s.sh"
  env INSTALL_K3S_VERSION="$K3S_VERSION" INSTALL_K3S_CHANNEL=stable \
    INSTALL_K3S_EXEC='server --disable traefik --disable servicelb --write-kubeconfig-mode 600 --kubelet-arg=fail-swap-on=false' \
    sh "$TMP_DIR/install-k3s.sh"
else
  if [[ -n $K3S_VERSION && $(k3s --version | awk 'NR==1 {print $3}') != "$K3S_VERSION" ]];then die 'Installed K3s differs from K3S_VERSION; this script does not upgrade clusters.';fi
  systemctl start k3s
fi
timeout 180 bash -c 'until k3s kubectl --request-timeout=5s get nodes -o name 2>/dev/null | grep -q .;do sleep 2;done'
k3s kubectl wait --for=condition=Ready nodes --all --timeout=180s
say 'Step 4/6: Caching public classroom images'
docker pull "$NGINX_IMAGE"
docker pull "$CLIENT_IMAGE"
docker save -o "$TMP_DIR/client-image.tar" "$CLIENT_IMAGE"
k3s ctr -n k8s.io images import "$TMP_DIR/client-image.tar"
say 'Step 5/6: Testing Docker HTTP and K3s execution'
SMOKE_CONTAINER="container-tutorial-smoke-$$"
docker run -d --name "$SMOKE_CONTAINER" -p 127.0.0.1::80 "$NGINX_IMAGE" >/dev/null
SMOKE_PORT=$(docker port "$SMOKE_CONTAINER" 80/tcp | awk -F: '{print $NF}')
curl --fail --silent --show-error --retry 15 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$SMOKE_PORT" | grep -q 'Welcome to nginx'
docker rm -f "$SMOKE_CONTAINER" >/dev/null
SMOKE_CONTAINER=
SMOKE_NS="container-smoke-$(date +%s)-$$"
k3s kubectl create namespace "$SMOKE_NS"
k3s kubectl -n "$SMOKE_NS" run runtime-check --image="$CLIENT_IMAGE" --image-pull-policy=Never --restart=Never --command -- sh -c 'echo K3S_RUNTIME_OK'
k3s kubectl -n "$SMOKE_NS" wait --for=jsonpath='{.status.phase}'=Succeeded pod/runtime-check --timeout=120s
k3s kubectl -n "$SMOKE_NS" logs runtime-check | grep -q K3S_RUNTIME_OK
k3s kubectl delete namespace "$SMOKE_NS" --wait=true --timeout=120s
SMOKE_NS=
say 'Step 6/6: Installing the classroom kubectl helper'
install_k_helper
{
 date -u '+Prepared at %Y-%m-%dT%H:%M:%SZ'
 uname -m
 docker version --format 'Docker server {{.Server.Version}}'
 docker compose version
 k3s --version
 printf 'Cached public images: %s ; %s\n' "$NGINX_IMAGE" "$CLIENT_IMAGE"
 printf 'Checks: Docker nginx HTTP and K3s BusyBox execution PASS\n'
} >"$STATE_DIR/versions.txt"
check_ready
say "Setup complete. No course files or application images were created. Version details: $STATE_DIR/versions.txt"
printf 'To enable k in this already-open terminal, run:\n  source ~/.bashrc\nA newly opened Terminal will load it automatically.\n'

