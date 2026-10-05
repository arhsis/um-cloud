#!/usr/bin/env bash
# Containers and Kubernetes — Tutorial 2
# 来源：7403-tutorial_2-container_k8s(1).pdf（14 页）
# 面向讲义指定的 Ubuntu 24.04 虚拟机；以普通用户运行，命令内部按需使用 sudo。
# 用 bash 执行，不要用 sh，也不要 source 本文件。
# 仅运行你明确指定的一个步骤；默认显示帮助，不会自动依次安装、监听或清理。
set -euo pipefail

# 默认路径与 PDF 一致；可通过同名环境变量修改。
LAB_DIR="${LAB_DIR:-$HOME/container-tutorial-lab}"
PRECLASS_DIR="${PRECLASS_DIR:-$HOME/Downloads}"
k() { sudo k3s kubectl -n container-lab "$@"; }

enter_lab() {
  if [[ ! -d "$LAB_DIR" ]]; then
    printf '实验目录不存在：%s；请先执行步骤 04。\n' "$LAB_DIR" >&2
    return 1
  fi
  cd -- "$LAB_DIR"
}

show_help() {
  cat <<'HELP'
用法：
  bash tutorial2_commands.sh --list
  bash tutorial2_commands.sh 04
  bash tutorial2_commands.sh 05
  bash tutorial2_commands.sh 10 --vim
  bash tutorial2_commands.sh 18 实际Pod名称

本文件包含全部实验命令；每次传入一个两位步骤号。
主线先执行 01、02，然后 04–17；03、18 是按需排错。
19 在终端 A 持续运行，同时在 B 执行 20；随后在 A 按 Ctrl+C。
21、22 在 B；23 在 A 持续运行，同时在 B 执行 24；随后在 A 按 Ctrl+C。
25–28 在 B；29 在 A 持续运行，同时在 B 执行 30、31；随后在 A 按 Ctrl+C。
32 为诊断；33–35 是可选故障练习；36 仅在实验完成后清理。
首次安装依赖课程另行提供的 ~/Downloads/preclass-setup.sh。
每份独立步骤脚本都可脱离总脚本运行，但实验资源仍需按顺序创建。

步骤列表：
  01  运行课前安装脚本  [p.1, 终端 任一]
  02  课前检查 Docker、Compose 和 K3s  [p.2, 终端 任一]
  03  安装故障诊断（按需）  [p.2, 终端 任一]
  04  创建实验目录并检查环境  [p.3, 终端 A、B]
  05  创建 v1 的 HTML、nginx 配置和 Dockerfile  [p.3–4, 终端 B]
  06  检查基础镜像并构建 v1  [p.4–5, 终端 B]
  07  启动 v1 容器并访问 8081  [p.5, 终端 B]
  08  检查容器日志、主机名、进程和配置  [p.5, 终端 B]
  09  演示绑定挂载与数据持久化  [p.6, 终端 B]
  10  创建 Compose 配置（可选 Vim 模式）  [p.6, 终端 B]
  11  验证、启动并访问 Compose 服务  [p.6, 终端 B]
  12  关闭 Compose 服务  [p.6, 终端 B]
  13  移除独立 Docker 容器  [p.7, 终端 B]
  14  把 Docker 的 v1 镜像导入 K3s  [p.7, 终端 B]
  15  创建 Kubernetes 实验命名空间  [p.7, 终端 B]
  16  写入 Deployment 和 Service 的 YAML  [p.8–9, 终端 B]
  17  部署 v1 并检查资源  [p.9, 终端 B]
  18  列出 Pod 并诊断指定 Pod（按需）  [p.9、13, 终端 B]
  19  端口转发（终端 A，持续运行）  [p.9–10, 终端 A]
  20  访问端口转发（终端 B）  [p.9, 终端 B]
  21  创建临时客户端 Pod 并测试集群 DNS  [p.10, 终端 B]
  22  查看 Service 返回的 HTTP 响应头  [p.10, 终端 B]
  23  观察自愈过程（终端 A，持续运行）  [p.10, 终端 A]
  24  删除一个应用 Pod 并观察自动补建  [p.10, 终端 B]
  25  扩容到 4 个副本  [p.11, 终端 B]
  26  缩容回 2 个副本  [p.11, 终端 B]
  27  创建 v2 应用文件  [p.11, 终端 B]
  28  构建 v2 并导入 K3s  [p.11, 终端 B]
  29  观察滚动更新（终端 A，持续运行）  [p.11–12, 终端 A]
  30  滚动更新到 v2 并验证  [p.12, 终端 B]
  31  回滚并验证 v1  [p.12, 终端 B]
  32  查看 Kubernetes 工作负载诊断信息  [p.12, 终端 B]
  33  课后可选：故意指定不存在的镜像  [p.13, 终端 B]
  34  课后可选：检查故障 Pod  [p.13, 终端 B]
  35  课后可选：撤销故障镜像更新  [p.13, 终端 B]
  36  实验结束后清理资源  [p.13, 终端 B]
HELP
}

# 步骤 01：运行课前安装脚本
# 来源：PDF 第 1 页；终端：任一
# 先从课程渠道取得 preclass-setup.sh，默认放在 ~/Downloads；PDF 中没有其源码或下载地址。
step_01() (
printf '%s\n' '[01] 运行课前安装脚本 | PDF p.1 | 终端 任一'
printf '%s\n' '先从课程渠道取得 preclass-setup.sh，默认放在 ~/Downloads；PDF 中没有其源码或下载地址。'
cd -- "$PRECLASS_DIR"
ls -l preclass-setup.sh
sudo bash preclass-setup.sh --install
)

# 步骤 02：课前检查 Docker、Compose 和 K3s
# 来源：PDF 第 2 页；终端：任一
# 依赖步骤 01；也可在重启虚拟机后重复执行。
step_02() (
printf '%s\n' '[02] 课前检查 Docker、Compose 和 K3s | PDF p.2 | 终端 任一'
printf '%s\n' '依赖步骤 01；也可在重启虚拟机后重复执行。'
cd -- "$PRECLASS_DIR"
sudo bash preclass-setup.sh --check
sudo docker version
sudo docker compose version
sudo k3s kubectl get nodes
)

# 步骤 03：安装故障诊断（按需）
# 来源：PDF 第 2 页；终端：任一
# 仅在安装或启动有问题时执行；不属于主线必做步骤。
step_03() (
printf '%s\n' '[03] 安装故障诊断（按需） | PDF p.2 | 终端 任一'
printf '%s\n' '仅在安装或启动有问题时执行；不属于主线必做步骤。'
# 服务未启动时 status 会返回非零；继续收集下面的日志。
sudo systemctl status k3s --no-pager || true
sudo journalctl -u k3s -n 50 --no-pager
)

# 步骤 04：创建实验目录并检查环境
# 来源：PDF 第 3 页；终端：A、B
# 每个脚本都会自行进入实验目录并定义 k；运行脚本不会改变父终端的目录或函数。
step_04() (
printf '%s\n' '[04] 创建实验目录并检查环境 | PDF p.3 | 终端 A、B'
printf '%s\n' '每个脚本都会自行进入实验目录并定义 k；运行脚本不会改变父终端的目录或函数。'
# 原文：mkdir -p ~/container-tutorial-lab; cd ~/container-tutorial-lab
mkdir -p -- "$LAB_DIR"
cd -- "$LAB_DIR"
k() { sudo k3s kubectl -n container-lab "$@"; }
sudo docker version
sudo k3s kubectl get nodes
)

# 步骤 05：创建 v1 的 HTML、nginx 配置和 Dockerfile
# 来源：PDF 第 3–4 页；终端：B
# 依赖步骤 04；重复运行会覆盖这三个文件。
step_05() (
printf '%s\n' '[05] 创建 v1 的 HTML、nginx 配置和 Dockerfile | PDF p.3–4 | 终端 B'
printf '%s\n' '依赖步骤 04；重复运行会覆盖这三个文件。'
enter_lab
mkdir -p app/v1
cat > app/v1/index.html <<'EOF'
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<title>My Cloud App</title>
<h1>Hello from my application!</h1>
<p>Version: v1</p>
</html>
EOF

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

cat > app/v1/Dockerfile <<'EOF'
FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
EOF

ls -l app/v1
)

# 步骤 06：检查基础镜像并构建 v1
# 来源：PDF 第 4–5 页；终端：B
# 依赖步骤 05 和课前缓存的 nginx 镜像。
step_06() (
printf '%s\n' '[06] 检查基础镜像并构建 v1 | PDF p.4–5 | 终端 B'
printf '%s\n' '依赖步骤 05 和课前缓存的 nginx 镜像。'
enter_lab
sudo docker image inspect nginx:stable-alpine --format '{{.Id}}'
sudo docker build --pull=false -t cloud-demo:v1 app/v1
sudo docker image inspect cloud-demo:v1 --format '{{.Id}}'
)

# 步骤 07：启动 v1 容器并访问 8081
# 来源：PDF 第 5 页；终端：B
# 依赖步骤 06；容器名 cloud-web 和端口 8081 需可用。若 curl 因服务尚未就绪失败，稍候只重试 curl。
step_07() (
printf '%s\n' '[07] 启动 v1 容器并访问 8081 | PDF p.5 | 终端 B'
printf '%s\n' '依赖步骤 06；容器名 cloud-web 和端口 8081 需可用。若 curl 因服务尚未就绪失败，稍候只重试 curl。'
enter_lab
sudo docker run --pull=never -d --name cloud-web \
  -p 127.0.0.1:8081:80 cloud-demo:v1
curl -i http://127.0.0.1:8081
sudo docker ps
)

# 步骤 08：检查容器日志、主机名、进程和配置
# 来源：PDF 第 5 页；终端：B
# 依赖步骤 07。
step_08() (
printf '%s\n' '[08] 检查容器日志、主机名、进程和配置 | PDF p.5 | 终端 B'
printf '%s\n' '依赖步骤 07。'
enter_lab
sudo docker logs --tail 10 cloud-web
sudo docker exec cloud-web hostname
sudo docker exec cloud-web ps
sudo docker inspect cloud-web
)

# 步骤 09：演示绑定挂载与数据持久化
# 来源：PDF 第 6 页；终端：B
step_09() (
printf '%s\n' '[09] 演示绑定挂载与数据持久化 | PDF p.6 | 终端 B'
enter_lab
mkdir -p data
sudo docker run --rm \
  --mount type=bind,src="$PWD/data",dst=/data \
  docker.io/library/busybox:1.37.0 \
  sh -c 'echo hello > /data/hello.txt'
cat data/hello.txt
)

# 步骤 10：创建 Compose 配置（可选 Vim 模式）
# 来源：PDF 第 6 页；终端：B
# 默认覆盖 compose.yaml。Vim 示例：bash tutorial2_commands.sh 10 --vim。
step_10() (
printf '%s\n' '[10] 创建 Compose 配置（可选 Vim 模式） | PDF p.6 | 终端 B'
printf '%s\n' '默认覆盖 compose.yaml。Vim 示例：bash tutorial2_commands.sh 10 --vim。'
enter_lab
# PDF 原操作是 vim compose.yaml，再手动粘贴配置。
# 默认用 here-document 写入相同内容；传入 --vim 可按原文手动编辑。
if [[ "${1:-}" == '--vim' ]]; then
  printf '%s\n' '按 i 后输入以下配置，再按 Esc，输入 :wq 回车保存；:q! 放弃修改。'
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

# 步骤 11：验证、启动并访问 Compose 服务
# 来源：PDF 第 6 页；终端：B
# 依赖步骤 06、10；结束观察后执行步骤 12。
step_11() (
printf '%s\n' '[11] 验证、启动并访问 Compose 服务 | PDF p.6 | 终端 B'
printf '%s\n' '依赖步骤 06、10；结束观察后执行步骤 12。'
enter_lab
sudo docker compose config
sudo docker compose up -d && sleep 1
curl -s http://127.0.0.1:8083 && sleep 1
)

# 步骤 12：关闭 Compose 服务
# 来源：PDF 第 6 页；终端：B
step_12() (
printf '%s\n' '[12] 关闭 Compose 服务 | PDF p.6 | 终端 B'
enter_lab
sudo docker compose down
)

# 步骤 13：移除独立 Docker 容器
# 来源：PDF 第 7 页；终端：B
# 在完成 Docker 实验后执行。
step_13() (
printf '%s\n' '[13] 移除独立 Docker 容器 | PDF p.7 | 终端 B'
printf '%s\n' '在完成 Docker 实验后执行。'
enter_lab
sudo docker rm -f cloud-web
sudo docker ps -a
)

# 步骤 14：把 Docker 的 v1 镜像导入 K3s
# 来源：PDF 第 7 页；终端：B
# 依赖步骤 06；k8s.io 是 containerd 命名空间。
step_14() (
printf '%s\n' '[14] 把 Docker 的 v1 镜像导入 K3s | PDF p.7 | 终端 B'
printf '%s\n' '依赖步骤 06；k8s.io 是 containerd 命名空间。'
enter_lab
sudo docker save -o /tmp/cloud-demo-v1.tar cloud-demo:v1
sudo k3s ctr -n k8s.io images import /tmp/cloud-demo-v1.tar
sudo rm /tmp/cloud-demo-v1.tar
sudo k3s ctr -n k8s.io images list -q | grep cloud-demo
)

# 步骤 15：创建 Kubernetes 实验命名空间
# 来源：PDF 第 7 页；终端：B
step_15() (
printf '%s\n' '[15] 创建 Kubernetes 实验命名空间 | PDF p.7 | 终端 B'
enter_lab
sudo k3s kubectl create namespace container-lab --dry-run=client -o yaml |
  sudo k3s kubectl apply -f -
sudo k3s kubectl get namespace container-lab
)

# 步骤 16：写入 Deployment 和 Service 的 YAML
# 来源：PDF 第 8–9 页；终端：B
# 已合并 PDF 第 8–9 页的跨页内容；重复执行会覆盖 k8s/hello.yaml。
step_16() (
printf '%s\n' '[16] 写入 Deployment 和 Service 的 YAML | PDF p.8–9 | 终端 B'
printf '%s\n' '已合并 PDF 第 8–9 页的跨页内容；重复执行会覆盖 k8s/hello.yaml。'
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

# 步骤 17：部署 v1 并检查资源
# 来源：PDF 第 9 页；终端：B
# 依赖步骤 14–16；超时时用步骤 18 排查。
step_17() (
printf '%s\n' '[17] 部署 v1 并检查资源 | PDF p.9 | 终端 B'
printf '%s\n' '依赖步骤 14–16；超时时用步骤 18 排查。'
enter_lab
cat k8s/hello.yaml
k apply -f k8s/hello.yaml
k rollout status deployment/hello --timeout=120s
k get deployment,replicaset,pod,service -o wide
k get pods --show-labels
)

# 步骤 18：列出 Pod 并诊断指定 Pod（按需）
# 来源：PDF 第 9、13 页；终端：B
# 示例：bash tutorial2_commands.sh 18 hello-实际名称。无参数时只列出 Pod 并提示。
step_18() (
printf '%s\n' '[18] 列出 Pod 并诊断指定 Pod（按需） | PDF p.9、13 | 终端 B'
printf '%s\n' '示例：bash tutorial2_commands.sh 18 hello-实际名称。无参数时只列出 Pod 并提示。'
enter_lab
k get pods
# PDF 的 <POD_NAME> 是占位符，不能直接带尖括号执行。
POD_NAME="${1:-}"
if [[ -z "$POD_NAME" ]]; then
  printf '%s\n' '从上面的列表选择实际 Pod 名称，再把名称作为本步骤的参数。' >&2
  exit 2
fi
k describe pod "$POD_NAME"
)

# 步骤 19：端口转发（终端 A，持续运行）
# 来源：PDF 第 9–10 页；终端：A
# 依赖步骤 17；保持运行，在终端 B 执行步骤 20；完成后 Ctrl+C 退出。
step_19() (
printf '%s\n' '[19] 端口转发（终端 A，持续运行） | PDF p.9–10 | 终端 A'
printf '%s\n' '依赖步骤 17；保持运行，在终端 B 执行步骤 20；完成后 Ctrl+C 退出。'
enter_lab
k port-forward service/hello 8082:80
)

# 步骤 20：访问端口转发（终端 B）
# 来源：PDF 第 9 页；终端：B
# 执行时终端 A 的步骤 19 必须仍在运行。
step_20() (
printf '%s\n' '[20] 访问端口转发（终端 B） | PDF p.9 | 终端 B'
printf '%s\n' '执行时终端 A 的步骤 19 必须仍在运行。'
enter_lab
curl -i http://127.0.0.1:8082
)

# 步骤 21：创建临时客户端 Pod 并测试集群 DNS
# 来源：PDF 第 10 页；终端：B
# 依赖步骤 17；client 运行约 1 小时，后续版本验证依赖它仍在运行。重复创建前需确认旧 client 已移除。
step_21() (
printf '%s\n' '[21] 创建临时客户端 Pod 并测试集群 DNS | PDF p.10 | 终端 B'
printf '%s\n' '依赖步骤 17；client 运行约 1 小时，后续版本验证依赖它仍在运行。重复创建前需确认旧 client 已移除。'
enter_lab
k() { sudo k3s kubectl -n container-lab "$@"; }
# 修复 PDF 自动换行把 --image-pull-policy 分成两行的问题。
k run client --image=docker.io/library/busybox:1.37.0 \
  --image-pull-policy=Never --restart=Never --command -- sleep 3600
k wait --for=condition=Ready pod/client --timeout=90s
k exec client -- wget -qO- http://hello
k get endpointslices -l kubernetes.io/service-name=hello
)

# 步骤 22：查看 Service 返回的 HTTP 响应头
# 来源：PDF 第 10 页；终端：B
# 依赖步骤 21；这是 PDF 正文中的补充命令。
step_22() (
printf '%s\n' '[22] 查看 Service 返回的 HTTP 响应头 | PDF p.10 | 终端 B'
printf '%s\n' '依赖步骤 21；这是 PDF 正文中的补充命令。'
enter_lab
k exec client -- wget -S -O- http://hello
)

# 步骤 23：观察自愈过程（终端 A，持续运行）
# 来源：PDF 第 10 页；终端：A
# 保持运行，在终端 B 执行步骤 24；观察完成后 Ctrl+C 退出。
step_23() (
printf '%s\n' '[23] 观察自愈过程（终端 A，持续运行） | PDF p.10 | 终端 A'
printf '%s\n' '保持运行，在终端 B 执行步骤 24；观察完成后 Ctrl+C 退出。'
enter_lab
k get pods -l app=hello -w
)

# 步骤 24：删除一个应用 Pod 并观察自动补建
# 来源：PDF 第 10 页；终端：B
# 仅操作 container-lab 中标签为 app=hello 的一个 Pod；与步骤 23 配合。
step_24() (
printf '%s\n' '[24] 删除一个应用 Pod 并观察自动补建 | PDF p.10 | 终端 B'
printf '%s\n' '仅操作 container-lab 中标签为 app=hello 的一个 Pod；与步骤 23 配合。'
enter_lab
POD=$(k get pods -l app=hello -o jsonpath='{.items[0].metadata.name}')
printf 'Deleting pod: %s\n' "$POD"
k delete pod "$POD"
k rollout status deployment/hello --timeout=120s
k get pods -l app=hello
)

# 步骤 25：扩容到 4 个副本
# 来源：PDF 第 11 页；终端：B
step_25() (
printf '%s\n' '[25] 扩容到 4 个副本 | PDF p.11 | 终端 B'
enter_lab
k scale deployment/hello --replicas=4
k rollout status deployment/hello --timeout=120s
k get pods -l app=hello
)

# 步骤 26：缩容回 2 个副本
# 来源：PDF 第 11 页；终端：B
step_26() (
printf '%s\n' '[26] 缩容回 2 个副本 | PDF p.11 | 终端 B'
enter_lab
k scale deployment/hello --replicas=2
k rollout status deployment/hello --timeout=120s
)

# 步骤 27：创建 v2 应用文件
# 来源：PDF 第 11 页；终端：B
# 依赖步骤 05；重复执行会覆盖 app/v2 中的实验文件。
step_27() (
printf '%s\n' '[27] 创建 v2 应用文件 | PDF p.11 | 终端 B'
printf '%s\n' '依赖步骤 05；重复执行会覆盖 app/v2 中的实验文件。'
enter_lab
mkdir -p app/v2
cp app/v1/Dockerfile app/v1/nginx.conf app/v2/
sed 's/Version: v1/Version: v2/' app/v1/index.html > app/v2/index.html
cat app/v2/index.html
)

# 步骤 28：构建 v2 并导入 K3s
# 来源：PDF 第 11 页；终端：B
# 依赖步骤 27；此时 Deployment 仍使用 v1。
step_28() (
printf '%s\n' '[28] 构建 v2 并导入 K3s | PDF p.11 | 终端 B'
printf '%s\n' '依赖步骤 27；此时 Deployment 仍使用 v1。'
enter_lab
sudo docker build --pull=false -t cloud-demo:v2 app/v2
sudo docker save -o /tmp/cloud-demo-v2.tar cloud-demo:v2
sudo k3s ctr -n k8s.io images import /tmp/cloud-demo-v2.tar
sudo rm /tmp/cloud-demo-v2.tar
)

# 步骤 29：观察滚动更新（终端 A，持续运行）
# 来源：PDF 第 11–12 页；终端：A
# 保持运行，在终端 B 执行步骤 30、31；完成后 Ctrl+C 退出。
step_29() (
printf '%s\n' '[29] 观察滚动更新（终端 A，持续运行） | PDF p.11–12 | 终端 A'
printf '%s\n' '保持运行，在终端 B 执行步骤 30、31；完成后 Ctrl+C 退出。'
enter_lab
k get pods -l app=hello -w
)

# 步骤 30：滚动更新到 v2 并验证
# 来源：PDF 第 12 页；终端：B
# 依赖步骤 21、28；预期返回 Version: v2。
step_30() (
printf '%s\n' '[30] 滚动更新到 v2 并验证 | PDF p.12 | 终端 B'
printf '%s\n' '依赖步骤 21、28；预期返回 Version: v2。'
enter_lab
k set image deployment/hello web=docker.io/library/cloud-demo:v2
k rollout status deployment/hello --timeout=120s
k exec client -- wget -qO- http://hello
k rollout history deployment/hello
)

# 步骤 31：回滚并验证 v1
# 来源：PDF 第 12 页；终端：B
# 紧接步骤 30 执行。undo 回到上一修订；按本教程顺序执行时为 v1。
step_31() (
printf '%s\n' '[31] 回滚并验证 v1 | PDF p.12 | 终端 B'
printf '%s\n' '紧接步骤 30 执行。undo 回到上一修订；按本教程顺序执行时为 v1。'
enter_lab
k rollout undo deployment/hello
k rollout status deployment/hello --timeout=120s
sleep 2 && k exec client -- wget -qO- http://hello
)

# 步骤 32：查看 Kubernetes 工作负载诊断信息
# 来源：PDF 第 12 页；终端：B
step_32() (
printf '%s\n' '[32] 查看 Kubernetes 工作负载诊断信息 | PDF p.12 | 终端 B'
enter_lab
k get pods
k describe deployment hello
k logs deployment/hello --tail=20
k exec deployment/hello -- hostname
)

# 步骤 33：课后可选：故意指定不存在的镜像
# 来源：PDF 第 13 页；终端：B
# 可选故障实验，会使新 Pod 无法就绪；随后用步骤 34 诊断、步骤 35 恢复。
step_33() (
printf '%s\n' '[33] 课后可选：故意指定不存在的镜像 | PDF p.13 | 终端 B'
printf '%s\n' '可选故障实验，会使新 Pod 无法就绪；随后用步骤 34 诊断、步骤 35 恢复。'
enter_lab
k set image deployment/hello web=docker.io/library/cloud-demo:missing
k get pods
)

# 步骤 34：课后可选：检查故障 Pod
# 来源：PDF 第 13 页；终端：B
# 示例：bash tutorial2_commands.sh 34 hello-实际故障名称。
step_34() (
printf '%s\n' '[34] 课后可选：检查故障 Pod | PDF p.13 | 终端 B'
printf '%s\n' '示例：bash tutorial2_commands.sh 34 hello-实际故障名称。'
enter_lab
# PDF 原文：k describe pod <ACTUAL_POD_NAME>
# 将故障 Pod 的真实名称作为参数传入，避免把占位符当成重定向。
POD_NAME="${1:-}"
if [[ -z "$POD_NAME" ]]; then
  k get pods
  printf '%s\n' '请把故障 Pod 的真实名称作为参数再次执行本步骤。' >&2
  exit 2
fi
k describe pod "$POD_NAME"
)

# 步骤 35：课后可选：撤销故障镜像更新
# 来源：PDF 第 13 页；终端：B
# 仅在步骤 33 之后执行；不要无故重复 undo。
step_35() (
printf '%s\n' '[35] 课后可选：撤销故障镜像更新 | PDF p.13 | 终端 B'
printf '%s\n' '仅在步骤 33 之后执行；不要无故重复 undo。'
enter_lab
k rollout undo deployment/hello
k rollout status deployment/hello --timeout=120s
)

# 步骤 36：实验结束后清理资源
# 来源：PDF 第 13 页；终端：B
# 先在所有终端用 Ctrl+C 停止 watch / port-forward。删除实验资源及整个 container-lab 命名空间；保留本地文件、镜像和 K3s。
step_36() (
printf '%s\n' '[36] 实验结束后清理资源 | PDF p.13 | 终端 B'
printf '%s\n' '先在所有终端用 Ctrl+C 停止 watch / port-forward。删除实验资源及整个 container-lab 命名空间；保留本地文件、镜像和 K3s。'
enter_lab
k delete -f k8s/hello.yaml
k delete pod client --ignore-not-found
sudo k3s kubectl delete namespace container-lab
sudo docker compose down
sudo docker rm -f cloud-web 2>/dev/null || true
)

# PDF 第 14 页：命令速查模板（正文已有对应的具体可执行命令）。
# docker build -t NAME:TAG PATH
# docker ps
# docker logs NAME
# docker exec NAME CMD
# NAME:TAG、PATH、NAME、CMD 均需替换；不将模板自动当作命令运行。
# 第 13 页明确要求不要执行 docker system prune，也不要卸载 K3s。

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
  *) printf '未知步骤：%s；运行 --list 查看步骤编号。\n' "$1" >&2; exit 2 ;;
esac
