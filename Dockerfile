
# --- Stage 1: Builder ---
# 使用一个真实存在的、与您项目需求非常接近的 Python 版本作为基础镜像。
# 我们将 3.8.20 修正为 3.8.19，因为前者在 Docker Hub 上不存在。
FROM python:3.8.19-slim-buster AS builder


# 安装 uv，它是用 Rust 编写的极速 Python 包安装器。
# 我们直接从官方源下载二进制文件，避免了复杂的安装过程。
RUN apt-get update && apt-get install -y curl && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# 将 uv 添加到 PATH 环境变量中，以便后续可以直接调用。
ENV PATH="/root/.cargo/bin:${PATH}"

# 设置工作目录
WORKDIR /app

# 仅复制依赖定义文件，以最大化利用 Docker 的层缓存。
COPY pyproject.toml ./

# 使用 uv 创建一个虚拟环境，并将所有依赖安装到这个隔离的环境中。
# 这样做比安装到全局 site-packages 更干净、更可控。
RUN uv venv /opt/venv && \
    /opt/venv/bin/uv pip install --no-cache-dir .

# --- Stage 2: Final Image ---
# 再次使用同样精简的基础镜像，以确保最终镜像的体积最小。
# 这里同样需要修正版本号。
FROM python:3.8.19-slim-buster

# 设置工作目录
WORKDIR /app

# 从 builder 阶段，将包含所有依赖的完整虚拟环境复制过来。
# 这是多阶段构建的核心优势：最终镜像只包含运行所必需的文件。
COPY --from=builder /opt/venv /opt/venv

# 将项目的源代码复制到最终镜像中。
COPY src/ ./src/

# 更新 PATH 环境变量，让系统默认使用虚拟环境中的 Python 解释器和工具。
# 这样，后续的 CMD 指令就可以直接运行 `python`，无需激活虚拟环境。
ENV PATH="/opt/venv/bin:${PATH}"

# 定义容器启动时要执行的命令。
# Docker 会使用虚拟环境中的 Python 来执行此命令。
# 请将下面的命令替换为您项目的实际启动命令。
CMD ["python", "-c", "import sys; print(f'Hello from Python {sys.version} in a venv!')"]

