FROM registry.redhat.io/ubi9/go-toolset:latest

LABEL konflux.additional-tags="latest"

ENV AGENT_VERSION=1.1.192
ENV CLI_VERSION=1.0.46
ENV GOTOOLCHAIN=auto

USER root

# Installs Sealights Go agent and Sealights CLI
RUN wget -qO- https://agents.sealights.co/slgoagent/v${AGENT_VERSION}/slgoagent-linux-amd64.tar.gz | tar -xzv -C /usr/local/bin
RUN wget -qO- https://agents.sealights.co/slcli/v${CLI_VERSION}/slcli-linux-amd64.tar.gz | tar -xzv -C /usr/local/bin

USER 1001
