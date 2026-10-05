#!/usr/bin/env bash
# Containers and Kubernetes — Tutorial 2
# Source: 7403-tutorial_2-container_k8s.pdf (14-page handout)
# Target: the Ubuntu 24.04 VM from the handout. Run as a normal user; commands use sudo where needed.
# Run with bash (not sh), and do not source this file.
# Runs only the one step you name; with no arguments it prints help and never installs,
# watches or cleans up on its own.
set -euo pipefail

# Default paths match the handout; override with environment variables of the same name.
LAB_DIR="${LAB_DIR:-$HOME/container-tutorial-lab}"
PRECLASS_DIR="${PRECLASS_DIR:-$HOME/Downloads}"
# Shortcut used by every Kubernetes step: kubectl bundled with K3s, scoped to the lab namespace.
k() { sudo k3s kubectl -n container-lab "$@"; }

# Move into the lab directory, or stop with a hint if step 04 has not been run yet.
enter_lab() {
  if [[ ! -d "$LAB_DIR" ]]; then
    printf 'Lab directory not found: %s; run step 04 first.\n' "$LAB_DIR" >&2
    return 1
  fi
  cd -- "$LAB_DIR"
}

show_help() {
  cat <<'HELP'
Usage:
  bash tutorial2_commands.sh --list
  bash tutorial2_commands.sh 04
  bash tutorial2_commands.sh 05
  bash tutorial2_commands.sh 10 --vim
  bash tutorial2_commands.sh 18 ACTUAL_POD_NAME
  bash tutorial2_commands.sh catchup 19

This file holds every lab command; pass one two-digit step number per run.
Main path: 01, 02, then 04–17. Steps 03 and 18 are for troubleshooting only.
19 keeps running in terminal A while you run 20 in B; then press Ctrl+C in A.
21 and 22 run in B. 23 keeps running in A while you run 24 in B; then press Ctrl+C in A.
25–28 run in B. 29 keeps running in A while you run 30 and 31 in B; then press Ctrl+C in A.
32 is diagnostics; 33–35 are an optional failure exercise; 36 is cleanup after the lab only.
First-time install needs ~/Downloads/preclass-setup.sh, provided separately by the course.
Each step can run on its own, but lab resources must still be created in order.

Steps:
  01  Run the pre-class install script  [p.1, any terminal]
  02  Pre-class check of Docker, Compose and K3s  [p.2, any terminal]
  03  Install troubleshooting (only if needed)  [p.2, any terminal]
  04  Create the lab directory and check the environment  [p.3, terminals A and B]
  05  Create the v1 HTML page, nginx config and Dockerfile  [p.3–4, terminal B]
  06  Check the base image and build v1  [p.4–5, terminal B]
  07  Start the v1 container and open port 8081  [p.5, terminal B]
  08  Inspect the container's logs, hostname, processes and config  [p.5, terminal B]
  09  Bind mount demo: data outlives the container  [p.6, terminal B]
  10  Create the Compose file (optional vim mode)  [p.6, terminal B]
  11  Validate, start and open the Compose service  [p.6, terminal B]
  12  Stop the Compose service  [p.6, terminal B]
  13  Remove the standalone Docker container  [p.7, terminal B]
  14  Import the v1 image from Docker into K3s  [p.7, terminal B]
  15  Create the Kubernetes lab namespace  [p.7, terminal B]
  16  Write the Deployment and Service YAML  [p.8–9, terminal B]
  17  Deploy v1 and check the resources  [p.9, terminal B]
  18  List Pods and describe one Pod (only if needed)  [p.9, 13, terminal B]
  19  Port-forward (terminal A, keeps running)  [p.9–10, terminal A]
  20  Request the app through the port-forward  [p.9, terminal B]
  21  Create a temporary client Pod and test cluster DNS  [p.10, terminal B]
  22  Show the HTTP response headers from the Service  [p.10, terminal B]
  23  Watch self-healing (terminal A, keeps running)  [p.10, terminal A]
  24  Delete one app Pod and watch it be replaced  [p.10, terminal B]
  25  Scale up to 4 replicas  [p.11, terminal B]
  26  Scale back down to 2 replicas  [p.11, terminal B]
  27  Create the v2 app files  [p.11, terminal B]
  28  Build v2 and import it into K3s  [p.11, terminal B]
  29  Watch the rolling update (terminal A, keeps running)  [p.11–12, terminal A]
  30  Roll out v2 and verify  [p.12, terminal B]
  31  Roll back and verify v1  [p.12, terminal B]
  32  Kubernetes workload diagnostics  [p.12, terminal B]
  33  Optional after class: set an image that does not exist  [p.13, terminal B]
  34  Optional after class: describe the failing Pod  [p.13, terminal B]
  35  Optional after class: undo the broken image update  [p.13, terminal B]
  36  Clean up after the lab  [p.13, terminal B]

Catch-up (if you fell behind; terminal B; safe to rerun):
  catchup 14  Prepare v1 files and image, then continue from step 14 (import into K3s)
  catchup 19  Also deploy v1 to K3s, then continue from step 19 (access the Service)
  catchup 29  Also prepare the client Pod and v2 image, then continue from step 29 (rolling update)
Catch-up overwrites app/v1, app/v2 and k8s/hello.yaml, and resets the Deployment to v1 with 2 replicas.
HELP
}

# Step 01: Run the pre-class install script
# Handout p.1 · any terminal
# Get preclass-setup.sh from the course first (default location ~/Downloads); the handout has no source or URL for it.
step_01() (
printf '%s\n' '[01] Run the pre-class install script | Handout p.1 | any terminal'
printf '%s\n' 'Get preclass-setup.sh from the course first (default location ~/Downloads).'
cd -- "$PRECLASS_DIR"
# Confirm the script is actually in this folder before running it.
ls -l preclass-setup.sh
# Install Docker Engine, the Compose plugin and a single-node K3s cluster, and cache the nginx and BusyBox images.
sudo bash preclass-setup.sh --install
)

# Step 02: Pre-class check of Docker, Compose and K3s
# Handout p.2 · any terminal
# Needs step 01; safe to rerun after restarting the VM.
step_02() (
printf '%s\n' '[02] Pre-class check of Docker, Compose and K3s | Handout p.2 | any terminal'
printf '%s\n' 'Needs step 01; safe to rerun after restarting the VM.'
cd -- "$PRECLASS_DIR"
# Read-only readiness check; expect "READY for class".
sudo bash preclass-setup.sh --check
# Both Client and Server versions should print, which means the Docker daemon is running.
sudo docker version
# The Compose plugin is installed.
sudo docker compose version
# The K3s node should show STATUS Ready.
sudo k3s kubectl get nodes
)

# Step 03: Install troubleshooting (only if needed)
# Handout p.2 · any terminal
# Only when install or startup fails; not part of the main path.
step_03() (
printf '%s\n' '[03] Install troubleshooting (only if needed) | Handout p.2 | any terminal'
printf '%s\n' 'Only when install or startup fails; not part of the main path.'
# Show whether the k3s service is running. It exits non-zero when the service is down,
# so ignore that and still collect the logs below.
sudo systemctl status k3s --no-pager || true
# Show the last 50 log lines from the k3s service; show these to a TA.
sudo journalctl -u k3s -n 50 --no-pager
)

# Step 04: Create the lab directory and check the environment
# Handout p.3 · terminals A and B
# The script enters the lab directory and defines k by itself; running it does not change
# the directory or functions of your own terminal.
step_04() (
printf '%s\n' '[04] Create the lab directory and check the environment | Handout p.3 | terminals A and B'
printf '%s\n' 'This script cannot change your own terminal: still run cd and define k there yourself.'
# Handout version: mkdir -p ~/container-tutorial-lab; cd ~/container-tutorial-lab
# Create the working directory for every lab file (no error if it already exists).
mkdir -p -- "$LAB_DIR"
cd -- "$LAB_DIR"
# Shortcut so "k ..." means "sudo k3s kubectl -n container-lab ...".
k() { sudo k3s kubectl -n container-lab "$@"; }
# Docker is reachable.
sudo docker version
# K3s is reachable and the node is Ready.
sudo k3s kubectl get nodes
)

# Step 05: Create the v1 HTML page, nginx config and Dockerfile
# Handout p.3–4 · terminal B
# Needs step 04; rerunning overwrites these three files.
step_05() (
printf '%s\n' '[05] Create the v1 HTML page, nginx config and Dockerfile | Handout p.3–4 | terminal B'
printf '%s\n' 'Needs step 04; rerunning overwrites these three files.'
enter_lab
# Folder for the v1 source files; it is also the build context in step 06.
mkdir -p app/v1
# The page nginx serves. Keep "Version: v1" unchanged; later checks look for it.
cat > app/v1/index.html <<'EOF'
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<title>My Cloud App</title>
<h1>Hello from my application!</h1>
<p>Version: v1</p>
</html>
EOF

# nginx config: listen on port 80, serve index.html, and add an X-Pod-Name header
# with the container's hostname so you can tell which container answered.
cat > app/v1/nginx.conf <<'EOF'
server {
    listen 80;
    server_name _;
    add_header X-Pod-Name $hostname always;
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

# The image recipe: start from the cached nginx base image, then copy in our config and page.
cat > app/v1/Dockerfile <<'EOF'
FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
EOF

# Expect three files: Dockerfile, index.html and nginx.conf.
ls -l app/v1
)

# Step 06: Check the base image and build v1
# Handout p.4–5 · terminal B
# Needs step 05 and the nginx image cached before class.
step_06() (
printf '%s\n' '[06] Check the base image and build v1 | Handout p.4–5 | terminal B'
printf '%s\n' 'Needs step 05 and the nginx image cached before class.'
enter_lab
# Confirm the base image is in the local Docker store (prints its sha256 ID).
sudo docker image inspect nginx:stable-alpine --format '{{.Id}}'
# Build the image from the app/v1 build context and name it cloud-demo:v1.
# --pull=false uses the cached base image instead of downloading it again.
sudo docker build --pull=false -t cloud-demo:v1 app/v1
# Confirm the new image exists (prints its sha256 ID).
sudo docker image inspect cloud-demo:v1 --format '{{.Id}}'
)

# Step 07: Start the v1 container and open port 8081
# Handout p.5 · terminal B
# Needs step 06; the name cloud-web and port 8081 must be free. If curl fails because nginx
# is not ready yet, wait a moment and rerun only curl.
step_07() (
printf '%s\n' '[07] Start the v1 container and open port 8081 | Handout p.5 | terminal B'
printf '%s\n' 'Needs step 06. If curl fails because nginx is not ready yet, wait a moment and rerun only curl.'
enter_lab
# Start a container from cloud-demo:v1:
#   --pull=never  only use the local image, never download
#   -d            run in the background
#   --name        a fixed name for later commands
#   -p 127.0.0.1:8081:80  VM port 8081 -> container port 80, reachable only from inside the VM
sudo docker run --pull=never -d --name cloud-web \
  -p 127.0.0.1:8081:80 cloud-demo:v1
# Request the page; -i also prints the headers. Expect "Version: v1" and an X-Pod-Name header.
curl -i http://127.0.0.1:8081
# List running containers; cloud-web should be Up.
sudo docker ps
)

# Step 08: Inspect the container's logs, hostname, processes and config
# Handout p.5 · terminal B
# Needs step 07.
step_08() (
printf '%s\n' '[08] Inspect the container logs, hostname, processes and config | Handout p.5 | terminal B'
printf '%s\n' 'Needs step 07.'
enter_lab
# What the app printed: the last 10 nginx log lines, including your curl request.
sudo docker logs --tail 10 cloud-web
# Run a command inside the container: its own hostname (UTS namespace).
sudo docker exec cloud-web hostname
# Processes visible inside the container: only nginx (PID namespace).
sudo docker exec cloud-web ps
# Full container configuration as JSON: image, ports, mounts, network.
sudo docker inspect cloud-web
)

# Step 09: Bind mount demo: data outlives the container
# Handout p.6 · terminal B
step_09() (
printf '%s\n' '[09] Bind mount demo: data outlives the container | Handout p.6 | terminal B'
enter_lab
# Host folder that will be mounted into the container.
mkdir -p data
# Run a throwaway BusyBox container (--rm deletes it on exit) with ./data mounted at /data,
# and write a file there.
sudo docker run --rm \
  --mount type=bind,src="$PWD/data",dst=/data \
  docker.io/library/busybox:1.37.0 \
  sh -c 'echo hello > /data/hello.txt'
# The container is gone, but the file is still on the VM: prints "hello".
cat data/hello.txt
)

# Step 10: Create the Compose file (optional vim mode)
# Handout p.6 · terminal B
# Overwrites compose.yaml by default. Vim mode: bash tutorial2_commands.sh 10 --vim
step_10() (
printf '%s\n' '[10] Create the Compose file (optional vim mode) | Handout p.6 | terminal B'
printf '%s\n' 'Overwrites compose.yaml by default. Vim mode: bash tutorial2_commands.sh 10 --vim'
enter_lab
# The handout opens vim compose.yaml and pastes the config by hand.
# By default this writes the same content with a here-document; pass --vim to edit by hand instead.
# The file describes one service "web": run cloud-demo:v1, never pull, publish VM port 8083 -> container port 80.
if [[ "${1:-}" == '--vim' ]]; then
  printf '%s\n' 'Press i, type the config below, press Esc, then type :wq and Enter to save (:q! quits without saving).'
  cat <<'EOF'
services:
  web:
    image: cloud-demo:v1
    pull_policy: never
    ports:
      - "127.0.0.1:8083:80"
EOF
  vim compose.yaml
else
  cat > compose.yaml <<'EOF'
services:
  web:
    image: cloud-demo:v1
    pull_policy: never
    ports:
      - "127.0.0.1:8083:80"
EOF
fi
)

# Step 11: Validate, start and open the Compose service
# Handout p.6 · terminal B
# Needs steps 06 and 10; run step 12 when you are done looking.
step_11() (
printf '%s\n' '[11] Validate, start and open the Compose service | Handout p.6 | terminal B'
printf '%s\n' 'Needs steps 06 and 10; run step 12 when you are done.'
enter_lab
# Parse compose.yaml and print the resolved config; a YAML or indentation error shows up here.
sudo docker compose config
# Create and start the service in the background, then give nginx a second to start.
sudo docker compose up -d && sleep 1
# Request the page through the Compose port; expect the HTML with "Version: v1".
curl -s http://127.0.0.1:8083 && sleep 1
)

# Step 12: Stop the Compose service
# Handout p.6 · terminal B
step_12() (
printf '%s\n' '[12] Stop the Compose service | Handout p.6 | terminal B'
enter_lab
# Stop and remove the Compose service's container and network.
sudo docker compose down
)

# Step 13: Remove the standalone Docker container
# Handout p.7 · terminal B
# Run after finishing the Docker part.
step_13() (
printf '%s\n' '[13] Remove the standalone Docker container | Handout p.7 | terminal B'
printf '%s\n' 'Run after finishing the Docker part.'
enter_lab
# Force-remove cloud-web (stops it first if it is running). Docker will not bring it back.
sudo docker rm -f cloud-web
# List all containers, including stopped ones; cloud-web should be gone.
sudo docker ps -a
)

# Step 14: Import the v1 image from Docker into K3s
# Handout p.7 · terminal B
# Needs step 06. Docker and K3s keep separate image stores, so the image has to be copied across.
step_14() (
printf '%s\n' '[14] Import the v1 image from Docker into K3s | Handout p.7 | terminal B'
printf '%s\n' 'Needs step 06; k8s.io is a containerd namespace, not a Kubernetes namespace.'
enter_lab
# Export the image from Docker's store into a tar archive.
sudo docker save -o /tmp/cloud-demo-v1.tar cloud-demo:v1
# Load the archive into K3s's containerd store (k8s.io is the containerd namespace Kubernetes uses).
sudo k3s ctr -n k8s.io images import /tmp/cloud-demo-v1.tar
# Delete the temporary archive.
sudo rm /tmp/cloud-demo-v1.tar
# Confirm K3s now has the image: expect docker.io/library/cloud-demo:v1.
sudo k3s ctr -n k8s.io images list -q | grep cloud-demo
)

# Step 15: Create the Kubernetes lab namespace
# Handout p.7 · terminal B
step_15() (
printf '%s\n' '[15] Create the Kubernetes lab namespace | Handout p.7 | terminal B'
enter_lab
# Create the container-lab namespace if missing, without failing if it already exists:
# generate its YAML locally (--dry-run=client) and pipe it into apply.
sudo k3s kubectl create namespace container-lab --dry-run=client -o yaml |
  sudo k3s kubectl apply -f -
# Confirm it exists; STATUS should be Active.
sudo k3s kubectl get namespace container-lab
)

# Step 16: Write the Deployment and Service YAML
# Handout p.8–9 · terminal B
# Joins the block that spans handout pages 8–9; rerunning overwrites k8s/hello.yaml.
# Deployment "hello":
#   replicas: 2                     keep two Pods running
#   strategy.rollingUpdate          maxSurge 1 / maxUnavailable 0: start a new Pod before removing an old one
#   selector.matchLabels + template.metadata.labels   both app: hello; they must match
#   image + imagePullPolicy: Never  use the image imported in step 14, never download
#   readinessProbe                  send traffic only after the Pod answers HTTP on /
# Service "hello": a stable ClusterIP address and DNS name in front of every ready Pod labelled app: hello.
step_16() (
printf '%s\n' '[16] Write the Deployment and Service YAML | Handout p.8–9 | terminal B'
printf '%s\n' 'Joins the block that spans handout pages 8–9; rerunning overwrites k8s/hello.yaml.'
enter_lab
mkdir -p k8s
cat > k8s/hello.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  namespace: container-lab
spec:
  replicas: 2
  revisionHistoryLimit: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
        - name: web
          image: docker.io/library/cloud-demo:v1
          imagePullPolicy: Never
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 1
            periodSeconds: 2
---
apiVersion: v1
kind: Service
metadata:
  name: hello
  namespace: container-lab
spec:
  selector:
    app: hello
  ports:
    - name: http
      port: 80
      targetPort: http
  type: ClusterIP
EOF
)

# Step 17: Deploy v1 and check the resources
# Handout p.9 · terminal B
# Needs steps 14–16; if the rollout times out, use step 18 to investigate.
step_17() (
printf '%s\n' '[17] Deploy v1 and check the resources | Handout p.9 | terminal B'
printf '%s\n' 'Needs steps 14–16; if the rollout times out, use step 18 to investigate.'
enter_lab
# Review the manifest before applying it.
cat k8s/hello.yaml
# Send the desired state to the API server; Kubernetes creates or updates the objects to match.
k apply -f k8s/hello.yaml
# Wait until both Pods are ready (gives up after 120 seconds).
k rollout status deployment/hello --timeout=120s
# The whole chain: Deployment -> ReplicaSet -> Pods, plus the Service and its ClusterIP.
k get deployment,replicaset,pod,service -o wide
# Show each Pod's labels; app=hello is what the Service selects on.
k get pods --show-labels
)

# Step 18: List Pods and describe one Pod (only if needed)
# Handout p.9, 13 · terminal B
# Example: bash tutorial2_commands.sh 18 hello-ACTUAL-NAME. Without an argument it only lists Pods and stops.
step_18() (
printf '%s\n' '[18] List Pods and describe one Pod (only if needed) | Handout p.9, 13 | terminal B'
printf '%s\n' 'Example: bash tutorial2_commands.sh 18 hello-ACTUAL-NAME. Without a name it only lists Pods.'
enter_lab
# What exists, and in which state.
k get pods
# The handout's <POD_NAME> is a placeholder; typing the angle brackets would be read as a shell redirect.
POD_NAME="${1:-}"
if [[ -z "$POD_NAME" ]]; then
  printf '%s\n' 'Pick a real Pod name from the list above and pass it as the argument to this step.' >&2
  exit 2
fi
# Why it is stuck: read the Events section at the bottom.
k describe pod "$POD_NAME"
)

# Step 19: Port-forward (terminal A, keeps running)
# Handout p.9–10 · terminal A
# Needs step 17; leave it running, run step 20 in terminal B, then press Ctrl+C here.
step_19() (
printf '%s\n' '[19] Port-forward (terminal A, keeps running) | Handout p.9–10 | terminal A'
printf '%s\n' 'Needs step 17; leave it running, run step 20 in terminal B, then press Ctrl+C here.'
enter_lab
# Tunnel VM port 8082 to port 80 of the hello Service. It is a debugging tunnel to one Pod, not load balancing.
k port-forward service/hello 8082:80
)

# Step 20: Request the app through the port-forward
# Handout p.9 · terminal B
# Step 19 must still be running in terminal A.
step_20() (
printf '%s\n' '[20] Request the app through the port-forward | Handout p.9 | terminal B'
printf '%s\n' 'Step 19 must still be running in terminal A.'
enter_lab
# Expect "Version: v1".
curl -i http://127.0.0.1:8082
)

# Step 21: Create a temporary client Pod and test cluster DNS
# Handout p.10 · terminal B
# Needs step 17. The client lives for about an hour and later version checks rely on it;
# remove any old client before creating it again.
step_21() (
printf '%s\n' '[21] Create a temporary client Pod and test cluster DNS | Handout p.10 | terminal B'
printf '%s\n' 'Needs step 17. The client lives about 1 hour and later checks use it; delete an old client before recreating it.'
enter_lab
k() { sudo k3s kubectl -n container-lab "$@"; }
# Start a BusyBox Pod named client that just sleeps for an hour, so we can run commands from inside the cluster.
# It has no app=hello label, so the Service never sends traffic to it.
# (The handout's line wrap splits --image-pull-policy over two lines; it is joined here.)
k run client --image=docker.io/library/busybox:1.37.0 \
  --image-pull-policy=Never --restart=Never --command -- sleep 3600
# Wait until the client Pod is ready.
k wait --for=condition=Ready pod/client --timeout=90s
# From inside the cluster, request the Service by name; cluster DNS resolves "hello".
k exec client -- wget -qO- http://hello
# The Pod IPs currently behind the Service; expect two endpoints.
k get endpointslices -l kubernetes.io/service-name=hello
)

# Step 22: Show the HTTP response headers from the Service
# Handout p.10 · terminal B
# Needs step 21; an extra command from the handout text.
step_22() (
printf '%s\n' '[22] Show the HTTP response headers from the Service | Handout p.10 | terminal B'
printf '%s\n' 'Needs step 21.'
enter_lab
# -S prints the headers; repeat it to see X-Pod-Name change as the Service spreads requests across Pods.
k exec client -- wget -S -O- http://hello
)

# Step 23: Watch self-healing (terminal A, keeps running)
# Handout p.10 · terminal A
# Leave it running, run step 24 in terminal B, then press Ctrl+C here.
step_23() (
printf '%s\n' '[23] Watch self-healing (terminal A, keeps running) | Handout p.10 | terminal A'
printf '%s\n' 'Leave it running, run step 24 in terminal B, then press Ctrl+C here.'
enter_lab
# -w keeps printing every change to the app Pods in real time.
k get pods -l app=hello -w
)

# Step 24: Delete one app Pod and watch it be replaced
# Handout p.10 · terminal B
# Only touches one Pod labelled app=hello in container-lab; pair it with step 23.
step_24() (
printf '%s\n' '[24] Delete one app Pod and watch it be replaced | Handout p.10 | terminal B'
printf '%s\n' 'Only deletes one Pod labelled app=hello; watch terminal A (step 23).'
enter_lab
# Store the name of the first app=hello Pod in POD (jsonpath just picks that one field).
POD=$(k get pods -l app=hello -o jsonpath='{.items[0].metadata.name}')
printf 'Deleting pod: %s\n' "$POD"
# Delete it. The ReplicaSet sees 1 of 2 and creates a replacement with a new name.
k delete pod "$POD"
# Wait until the Deployment is back to 2 ready Pods.
k rollout status deployment/hello --timeout=120s
# Two Pods again; one has a new name.
k get pods -l app=hello
)

# Step 25: Scale up to 4 replicas
# Handout p.11 · terminal B
step_25() (
printf '%s\n' '[25] Scale up to 4 replicas | Handout p.11 | terminal B'
enter_lab
# Change only the desired count; the ReplicaSet creates two more Pods.
k scale deployment/hello --replicas=4
# Wait until all 4 are ready.
k rollout status deployment/hello --timeout=120s
# Expect 4 Pods.
k get pods -l app=hello
)

# Step 26: Scale back down to 2 replicas
# Handout p.11 · terminal B
step_26() (
printf '%s\n' '[26] Scale back down to 2 replicas | Handout p.11 | terminal B'
enter_lab
# Lower the desired count; the ReplicaSet removes two Pods.
k scale deployment/hello --replicas=2
k rollout status deployment/hello --timeout=120s
)

# Step 27: Create the v2 app files
# Handout p.11 · terminal B
# Needs step 05; rerunning overwrites the files in app/v2.
step_27() (
printf '%s\n' '[27] Create the v2 app files | Handout p.11 | terminal B'
printf '%s\n' 'Needs step 05; rerunning overwrites the files in app/v2.'
enter_lab
mkdir -p app/v2
# Reuse the same Dockerfile and nginx config.
cp app/v1/Dockerfile app/v1/nginx.conf app/v2/
# Copy the page with "Version: v1" replaced by "Version: v2".
sed 's/Version: v1/Version: v2/' app/v1/index.html > app/v2/index.html
# Expect "Version: v2".
cat app/v2/index.html
)

# Step 28: Build v2 and import it into K3s
# Handout p.11 · terminal B
# Needs step 27. The Deployment still runs v1 until step 30 changes it.
step_28() (
printf '%s\n' '[28] Build v2 and import it into K3s | Handout p.11 | terminal B'
printf '%s\n' 'Needs step 27; the Deployment still runs v1 after this.'
enter_lab
# Same pipeline as v1: build in Docker ...
sudo docker build --pull=false -t cloud-demo:v2 app/v2
# ... export to a tar archive ...
sudo docker save -o /tmp/cloud-demo-v2.tar cloud-demo:v2
# ... import into K3s ...
sudo k3s ctr -n k8s.io images import /tmp/cloud-demo-v2.tar
# ... and delete the archive.
sudo rm /tmp/cloud-demo-v2.tar
)

# Step 29: Watch the rolling update (terminal A, keeps running)
# Handout p.11–12 · terminal A
# Leave it running, run steps 30 and 31 in terminal B, then press Ctrl+C here.
step_29() (
printf '%s\n' '[29] Watch the rolling update (terminal A, keeps running) | Handout p.11–12 | terminal A'
printf '%s\n' 'Leave it running, run steps 30 and 31 in terminal B, then press Ctrl+C here.'
enter_lab
# Shows new Pods starting before old ones terminate.
k get pods -l app=hello -w
)

# Step 30: Roll out v2 and verify
# Handout p.12 · terminal B
# Needs steps 21 and 28; expect "Version: v2".
step_30() (
printf '%s\n' '[30] Roll out v2 and verify | Handout p.12 | terminal B'
printf '%s\n' 'Needs steps 21 and 28; expect Version: v2.'
enter_lab
# Change the Pod template's image for container "web". A new template means a new ReplicaSet and a rolling update.
k set image deployment/hello web=docker.io/library/cloud-demo:v2
# Wait until every Pod runs v2.
k rollout status deployment/hello --timeout=120s
# Ask the Service from inside the cluster; expect "Version: v2".
k exec client -- wget -qO- http://hello
# List the Deployment's revisions (one per Pod template).
k rollout history deployment/hello
)

# Step 31: Roll back and verify v1
# Handout p.12 · terminal B
# Run right after step 30. undo returns to the previous revision, which is v1 when the steps are followed in order.
step_31() (
printf '%s\n' '[31] Roll back and verify v1 | Handout p.12 | terminal B'
printf '%s\n' 'Run right after step 30; undo returns to the previous revision (v1 in this lab).'
enter_lab
# Switch back to the previous Pod template (the v1 ReplicaSet).
k rollout undo deployment/hello
k rollout status deployment/hello --timeout=120s
# Give old Pods a moment to leave the Service, then expect "Version: v1".
sleep 2 && k exec client -- wget -qO- http://hello
)

# Step 32: Kubernetes workload diagnostics
# Handout p.12 · terminal B
step_32() (
printf '%s\n' '[32] Kubernetes workload diagnostics | Handout p.12 | terminal B'
enter_lab
# What exists?
k get pods
# Deployment settings, rollout state and recent events.
k describe deployment hello
# What did the app report? Last 20 log lines from one of the Deployment's Pods.
k logs deployment/hello --tail=20
# Run a command inside one of the Deployment's Pods.
k exec deployment/hello -- hostname
)

# Step 33: Optional after class: set an image that does not exist
# Handout p.13 · terminal B
# Optional failure exercise: the new Pod never becomes ready. Diagnose with step 34, recover with step 35.
step_33() (
printf '%s\n' '[33] Optional after class: set an image that does not exist | Handout p.13 | terminal B'
printf '%s\n' 'The new Pod will not become ready; diagnose with step 34 and recover with step 35.'
enter_lab
# Point the Deployment at a tag that was never imported. The old Pods keep serving
# because maxUnavailable is 0.
k set image deployment/hello web=docker.io/library/cloud-demo:missing
# Expect a new Pod stuck in ErrImageNeverPull.
k get pods
)

# Step 34: Optional after class: describe the failing Pod
# Handout p.13 · terminal B
# Example: bash tutorial2_commands.sh 34 hello-ACTUAL-FAILING-NAME
step_34() (
printf '%s\n' '[34] Optional after class: describe the failing Pod | Handout p.13 | terminal B'
printf '%s\n' 'Example: bash tutorial2_commands.sh 34 hello-ACTUAL-FAILING-NAME'
enter_lab
# Handout version: k describe pod <ACTUAL_POD_NAME>
# Pass the real Pod name as the argument, so the placeholder is never read as a shell redirect.
POD_NAME="${1:-}"
if [[ -z "$POD_NAME" ]]; then
  k get pods
  printf '%s\n' 'Run this step again with the failing Pod name as the argument.' >&2
  exit 2
fi
# The Events section explains the image error.
k describe pod "$POD_NAME"
)

# Step 35: Optional after class: undo the broken image update
# Handout p.13 · terminal B
# Only after step 33; do not repeat undo for no reason (each undo flips to the previous revision).
step_35() (
printf '%s\n' '[35] Optional after class: undo the broken image update | Handout p.13 | terminal B'
printf '%s\n' 'Only after step 33; do not repeat undo for no reason.'
enter_lab
# Return to the last working Pod template.
k rollout undo deployment/hello
k rollout status deployment/hello --timeout=120s
)

# Step 36: Clean up after the lab
# Handout p.13 · terminal B
# First stop any watch or port-forward with Ctrl+C in every terminal. Deletes the lab resources and the whole
# container-lab namespace; keeps local files, images and K3s.
step_36() (
printf '%s\n' '[36] Clean up after the lab | Handout p.13 | terminal B'
printf '%s\n' 'First press Ctrl+C in every terminal running watch or port-forward. Keeps local files, images and K3s.'
enter_lab
# Delete the Deployment and Service defined in the manifest.
k delete -f k8s/hello.yaml
# Delete the client Pod (no error if it is already gone).
k delete pod client --ignore-not-found
# Delete the namespace and anything left inside it.
sudo k3s kubectl delete namespace container-lab
# Stop the Compose service if it is still running.
sudo docker compose down
# Remove the standalone container if it still exists; ignore the error if it does not.
sudo docker rm -f cloud-web 2>/dev/null || true
)

# Catch-up: bring the lab state up to just before a given step, so a student can rejoin from there.
# Only combines the steps above; each catch-up includes the previous one, and all are safe to rerun.

# Up to step 14: lab directory, v1 files and the cloud-demo:v1 image are ready; the standalone container is removed.
catchup_14() (
printf '%s\n' '[catchup 14] Prepare v1 files and image'
step_04
step_05
step_06
# Same end state as step 13; ignore the error if the container never existed.
sudo docker rm -f cloud-web >/dev/null 2>&1 || true
printf '%s\n' '[catchup 14] Done; continue with step 14.'
)

# Up to step 19: v1 is imported into K3s and the Deployment and Service are ready.
catchup_19() (
catchup_14
printf '%s\n' '[catchup 19] Deploy v1 to K3s'
step_14
step_15
step_16
enter_lab
# apply also resets a changed image or replica count back to the manifest's v1 with 2 replicas.
k apply -f k8s/hello.yaml
k rollout status deployment/hello --timeout=120s
k get deployment,pod,service
printf '%s\n' '[catchup 19] Done; continue with step 19.'
)

# Up to step 29: the client Pod is running, v2 is imported, and the Deployment still runs v1.
catchup_29() (
catchup_19
printf '%s\n' '[catchup 29] Prepare the client Pod and v2 image'
enter_lab
# Recreate the client if it is missing or has exited (its sleep 3600 ran out).
if [[ "$(k get pod client -o jsonpath='{.status.phase}' 2>/dev/null || true)" != 'Running' ]]; then
  k delete pod client --ignore-not-found
  k run client --image=docker.io/library/busybox:1.37.0 \
    --image-pull-policy=Never --restart=Never --command -- sleep 3600
fi
k wait --for=condition=Ready pod/client --timeout=90s
step_27
step_28
# Confirm the cluster still serves v1 before the rolling update.
k exec client -- wget -qO- http://hello
printf '%s\n' '[catchup 29] Done; the output above should show Version: v1. Continue with step 29.'
)

catchup() {
  case "${1:-}" in
    14) catchup_14 ;;
    19) catchup_19 ;;
    29) catchup_29 ;;
    *) printf 'Usage: bash tutorial2_commands.sh catchup 14|19|29\n' >&2; exit 2 ;;
  esac
  # A script cannot change its parent terminal, so remind students to restore the directory and k themselves.
  printf '%s\n' 'Now run these in your own terminals A and B:' \
    '  cd ~/container-tutorial-lab' \
    '  k() { sudo k3s kubectl -n container-lab "$@"; }'
}

# Handout p.14: command quick-reference templates (the steps above already contain the concrete commands).
# docker build -t NAME:TAG PATH
# docker ps
# docker logs NAME
# docker exec NAME CMD
# NAME:TAG, PATH, NAME and CMD are placeholders; these templates are never run automatically.
# Handout p.13 says: do not run docker system prune, and do not uninstall K3s.

case "${1:---help}" in
  -h|--help|--list|help|list) show_help ;;
  01) shift; step_01 "$@" ;;
  02) shift; step_02 "$@" ;;
  03) shift; step_03 "$@" ;;
  04) shift; step_04 "$@" ;;
  05) shift; step_05 "$@" ;;
  06) shift; step_06 "$@" ;;
  07) shift; step_07 "$@" ;;
  08) shift; step_08 "$@" ;;
  09) shift; step_09 "$@" ;;
  10) shift; step_10 "$@" ;;
  11) shift; step_11 "$@" ;;
  12) shift; step_12 "$@" ;;
  13) shift; step_13 "$@" ;;
  14) shift; step_14 "$@" ;;
  15) shift; step_15 "$@" ;;
  16) shift; step_16 "$@" ;;
  17) shift; step_17 "$@" ;;
  18) shift; step_18 "$@" ;;
  19) shift; step_19 "$@" ;;
  20) shift; step_20 "$@" ;;
  21) shift; step_21 "$@" ;;
  22) shift; step_22 "$@" ;;
  23) shift; step_23 "$@" ;;
  24) shift; step_24 "$@" ;;
  25) shift; step_25 "$@" ;;
  26) shift; step_26 "$@" ;;
  27) shift; step_27 "$@" ;;
  28) shift; step_28 "$@" ;;
  29) shift; step_29 "$@" ;;
  30) shift; step_30 "$@" ;;
  31) shift; step_31 "$@" ;;
  32) shift; step_32 "$@" ;;
  33) shift; step_33 "$@" ;;
  34) shift; step_34 "$@" ;;
  35) shift; step_35 "$@" ;;
  36) shift; step_36 "$@" ;;
  catchup) shift; catchup "$@" ;;
  *) printf 'Unknown step: %s; run --list to see the step numbers.\n' "$1" >&2; exit 2 ;;
esac
