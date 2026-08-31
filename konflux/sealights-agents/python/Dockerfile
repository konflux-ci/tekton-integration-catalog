FROM registry.redhat.io/ubi9/python-311:latest

LABEL konflux.additional-tags="latest"

ENV AGENT_VERSION=2.10.19

# Installs Sealights Python agent
RUN pip install sealights-python-agent==${AGENT_VERSION}