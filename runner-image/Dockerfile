# Runner image for the homelab's self-hosted GitHub Actions runners (ARC scale sets in K3s, homelab-k3s
# platform/arc, BookStack p379). The official runner image plus what our workflows expect from GitHub's
# ubuntu-latest: python3 + pip, a C toolchain, shellcheck, docker compose, kubectl, helm, yq and gh.
# Rebuilt weekly with the newest runner release (.github/workflows/runner-image.yml): ARC runners never
# self-update, and GitHub stops sending jobs to a runner more than 30 days behind the latest release.
ARG RUNNER_VERSION=2.338.0
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

# Pinned binaries; bump the version and its sha256 together (the sha256 is of the linux-amd64 download).
ARG KUBECTL_VERSION=v1.36.5
ARG KUBECTL_SHA256=33bc88a24c3b09cf55bfd59e6ca977881b61fc3f25ab65bc80c65b430248648e
ARG HELM_VERSION=v4.3.0
ARG HELM_SHA256=86584a54def73570558f66f5111cc53dfed56689637ae32c1201205d494f54fb
ARG YQ_VERSION=v4.54.1
ARG YQ_SHA256=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f
ARG GH_VERSION=2.102.0
ARG GH_SHA256=bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386
ARG COMPOSE_VERSION=v5.6.0
ARG COMPOSE_SHA256=40343e21ca777173e69cff5dbafeb37c6f81f3b0d57d9e597f036e95eb63e76a

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-dev pipx build-essential pkg-config \
      shellcheck make zip unzip xz-utils rsync openssh-client wget file ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; cd /tmp; \
    curl -fsSLo kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    echo "${KUBECTL_SHA256}  kubectl" | sha256sum -c -; install -m 0755 kubectl /usr/local/bin/kubectl; \
    curl -fsSLo helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"; \
    echo "${HELM_SHA256}  helm.tgz" | sha256sum -c -; tar xzf helm.tgz linux-amd64/helm; install -m 0755 linux-amd64/helm /usr/local/bin/helm; \
    curl -fsSLo yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"; \
    echo "${YQ_SHA256}  yq" | sha256sum -c -; install -m 0755 yq /usr/local/bin/yq; \
    curl -fsSLo gh.tgz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz"; \
    echo "${GH_SHA256}  gh.tgz" | sha256sum -c -; tar xzf gh.tgz; install -m 0755 "gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh; \
    curl -fsSLo docker-compose "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64"; \
    echo "${COMPOSE_SHA256}  docker-compose" | sha256sum -c -; install -m 0755 docker-compose /usr/local/lib/docker/cli-plugins/docker-compose; \
    rm -rf /tmp/*

# setup-python's prebuilt Pythons expect GitHub's tool cache path (their shared libs are linked against it),
# and the runner reads its tool cache location from these two variables. PIP_BREAK_SYSTEM_PACKAGES: like
# the hosted images, `pip install` into the system Python works (Ubuntu 24.04 refuses it by default).
RUN mkdir -p /opt/hostedtoolcache && chown runner:docker /opt/hostedtoolcache
# Package lists stay in the image, as on the hosted runners: workflows run `sudo apt-get install` without an update.
RUN apt-get update
ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache \
    AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache \
    PIP_BREAK_SYSTEM_PACKAGES=1

USER runner
