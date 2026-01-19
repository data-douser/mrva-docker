FROM codercom/code-server:4.92.2-debian

# ======================
# Stage 1: Install System Dependencies
# 
# Pre-install a custom JDK for this platform and redirect CodeQL to it

USER root
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update && apt-get install --no-install-recommends --assume-yes \
    ca-certificates                                 \
    curl                                            \
    default-jdk                                     \
    git                                             \
    libcurl4-openssl-dev                            \
    libssl-dev                                      \
    python3                                         \
    python3-dev                                     \
    unzip

# ======================
# Stage 2: Install CodeQL

# Build argument for CodeQL version, defaulting to the latest release
ARG CODEQL_VERSION=latest

# If the version is 'latest', get the latest release version from GitHub, unzip
# the bundle into /opt, and delete the archive
RUN if [ "$CODEQL_VERSION" = "latest" ]; then \
    CODEQL_VERSION=$(curl -s \
        https://api.github.com/repos/github/codeql-cli-binaries/releases/latest | \
        grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'); \
    fi && \
    echo "Using CodeQL version $CODEQL_VERSION" && \
    curl -L "https://github.com/github/codeql-cli-binaries/releases/download/$CODEQL_VERSION/codeql-linux64.zip" -o /tmp/codeql.zip && \
    unzip /tmp/codeql.zip -d /opt && \
    rm /tmp/codeql.zip && \
    chmod -R +x /opt/codeql && \
    chown -R coder:coder /opt/codeql

# ======================
# Stage 3: Set up coder user environment
USER root
RUN mkdir -p /home/coder/.local/ && \
    chown -R coder:coder /home/coder/.local

# ======================
# Stage 4: Install VS Code Extensions
USER coder

# Set environment variables
ENV PASSWORD=mrva

# Copy vscode-codeql extension build(s) - pattern matches any version
COPY ./artifacts/vscode-codeql-*.vsix /home/coder/

# Install VS Code extensions globally
RUN code-server --install-extension ms-python.python \
    && code-server --install-extension esbenp.prettier-vscode \
    && VSIX_FILE=$(ls -t /home/coder/vscode-codeql-*.vsix 2>/dev/null | head -n 1) \
    && if [ -z "$VSIX_FILE" ]; then echo "Error: No vscode-codeql VSIX file found"; exit 1; fi \
    && code-server --install-extension "$VSIX_FILE" \
    && rm -f /home/coder/vscode-codeql-*.vsix

# ======================
# Stage 5: Set CodeQL Java Home
USER coder
# Point CodeQL to the java binary for this platform
ENV CODEQL_JAVA_HOME=/usr

# Expose the port that Code Server runs on
EXPOSE 9080

# ======================
# Stage 6: Configure Code Server

# Add
#   codeQl.cli.executablePath
# to user settings.
# This is in addition to the environment variable CODEQL_JAVA_HOME which has no
# effect on the plugin
USER coder
COPY ./settings.json  /home/coder/
RUN mkdir -p /home/coder/.local/share/code-server/User/ && \
    cp /home/coder/settings.json /home/coder/.local/share/code-server/User/

# Start Code Server
ENTRYPOINT ["dumb-init", "code-server", "--bind-addr", "0.0.0.0:9080", "."]

# Run as the coder user
USER coder
