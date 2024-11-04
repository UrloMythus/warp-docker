FROM ubuntu:22.04

ARG WARP_VERSION
ARG GOST_VERSION
ARG COMMIT_SHA
ARG TARGETPLATFORM="linux/amd64"

LABEL org.opencontainers.image.authors="cmj2002"
LABEL org.opencontainers.image.url="https://github.com/cmj2002/warp-docker"
LABEL WARP_VERSION=${WARP_VERSION}
LABEL GOST_VERSION=${GOST_VERSION}
LABEL COMMIT_SHA=${COMMIT_SHA}

COPY entrypoint.sh /entrypoint.sh
COPY ./healthcheck /healthcheck

RUN set -ex && \
    echo "Building for TARGETPLATFORM: ${TARGETPLATFORM}" && \
    # Determine ARCH based on TARGETPLATFORM
    case ${TARGETPLATFORM} in \
      "linux/amd64") ARCH="amd64" ;; \
      "linux/arm64") ARCH="arm64" ;; \
      *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" && exit 1 ;; \
    esac && \
    echo "Architecture set to: ${ARCH}"

# Install dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl gnupg lsb-release sudo jq ipcalc

# Add Cloudflare WARP repository
RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y cloudflare-warp && \
    apt-get clean && \
    apt-get autoremove -y

# Determine GOST file naming convention and download
RUN MAJOR_VERSION=$(echo ${GOST_VERSION} | cut -d. -f1) && \
    MINOR_VERSION=$(echo ${GOST_VERSION} | cut -d. -f2) && \
    if [ "${MAJOR_VERSION}" -ge 3 ] || { [ "${MAJOR_VERSION}" -eq 2 ] && [ "${MINOR_VERSION}" -ge 12 ]; }; then \
      FILE_NAME="gost_${GOST_VERSION}_linux_${ARCH}.tar.gz"; \
    else \
      FILE_NAME="gost-linux-${ARCH}-${GOST_VERSION}.gz"; \
    fi && \
    echo "Downloading GOST file: ${FILE_NAME}" && \
    curl -LO https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/${FILE_NAME} && \
    if [ "${FILE_NAME##*.}" = "tar.gz" ]; then \
      tar -xzf ${FILE_NAME} -C /usr/bin/ gost; \
    else \
      gunzip ${FILE_NAME} && \
      mv gost-linux-${ARCH}-${GOST_VERSION} /usr/bin/gost; \
    fi && \
    chmod +x /usr/bin/gost

RUN chmod +x /entrypoint.sh && \
    chmod +x /healthcheck/index.sh && \
    useradd -m -s /bin/bash warp && \
    echo "warp ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/warp
