# Toolchain image used for the header-unit experiments (GCC from the official image, Clang from apt.llvm.org)
FROM gcc:latest
RUN apt-get update && apt-get install -y --no-install-recommends python3-venv wget ca-certificates gnupg \
 && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir cmake ninja
ENV PATH=/opt/venv/bin:$PATH
RUN wget -qO /etc/apt/trusted.gpg.d/apt.llvm.org.asc https://apt.llvm.org/llvm-snapshot.gpg.key \
 && echo "deb http://apt.llvm.org/trixie/ llvm-toolchain-trixie-22 main" > /etc/apt/sources.list.d/llvm.list \
 && apt-get update && apt-get install -y --no-install-recommends clang-22 clang-tools-22 libc++-22-dev libc++abi-22-dev lld-22 \
 && rm -rf /var/lib/apt/lists/*
