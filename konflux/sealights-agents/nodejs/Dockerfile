FROM registry.redhat.io/ubi9/nodejs-22:latest

LABEL konflux.additional-tags="latest"

ENV AGENT_VERSION=6.1.1143

# Installs Sealights Node.js agent
RUN npm i -g slnodejs@${AGENT_VERSION}