# Runtime container - binary built on host
# NOTE: This image is linux/amd64 ONLY because CodeQL CLI does not provide ARM64 Linux binaries.
# ARM64 Mac users can run this image via Docker's Rosetta 2 emulation.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

ARG CODEQL_VERSION=latest

# Install packages
RUN apt-get update && apt-get install --no-install-recommends --assume-yes \
    unzip curl ca-certificates default-jdk && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Download CodeQL CLI (linux64 only - no ARM64 Linux support from GitHub)
RUN if [ "$CODEQL_VERSION" = "latest" ]; then \
    CODEQL_VERSION=$(curl -s https://api.github.com/repos/github/codeql-cli-binaries/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'); \
    fi && \
    echo "Using CodeQL version $CODEQL_VERSION" && \
    curl -L "https://github.com/github/codeql-cli-binaries/releases/download/$CODEQL_VERSION/codeql-linux64.zip" -o /tmp/codeql.zip && \
    unzip /tmp/codeql.zip -d /opt && \
    rm /tmp/codeql.zip && \
    chmod -R +x /opt/codeql

# Set environment variables for CodeQL
ENV CODEQL_CLI_PATH=/opt/codeql/codeql

# Set environment variable for CodeQL for `codeql database analyze` support on ARM
# This env var has no functional effect on CodeQL when running on x86_64 linux
ENV CODEQL_JAVA_HOME=/usr

# Copy the agent binary (amd64 only)
COPY mrvaagent /usr/local/bin/mrvaagent

# Copy the binary-replacement support script to the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Run the agent with the default mode set to container
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

