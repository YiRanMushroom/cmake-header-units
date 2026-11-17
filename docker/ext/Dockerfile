# Adds real-world external header-only libraries for header-unit experiments
FROM hu-toolchain:latest
RUN apt-get update && apt-get install -y --no-install-recommends libfmt-dev nlohmann-json3-dev libboost-dev \
 && rm -rf /var/lib/apt/lists/*
