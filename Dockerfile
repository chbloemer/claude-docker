FROM claude-code-base

# ── Java + Gradle (via SDKMAN) ─────────────────────────────────────────────
RUN curl -s "https://get.sdkman.io" | bash \
    && bash -c "source ~/.sdkman/bin/sdkman-init.sh \
    && sdk install java 21.0.10-amzn \
    && sdk install java 25.0.2-amzn \
    && sdk default java 25.0.2-amzn \
    && sdk install gradle 9.4.1"
ENV SDKMAN_DIR=/home/claude/.sdkman
ENV JAVA_HOME=${SDKMAN_DIR}/candidates/java/current
ENV PATH="${SDKMAN_DIR}/candidates/java/current/bin:${SDKMAN_DIR}/candidates/gradle/current/bin:${PATH}"

# ── Maven ───────────────────────────────────────────────────────────────────
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends maven \
    && sudo rm -rf /var/lib/apt/lists/*

# ── .NET 8 SDK (required by NSwag for API client generation) ───────────────
RUN curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel 8.0 \
    && rm /tmp/dotnet-install.sh
ENV DOTNET_ROOT=/home/claude/.dotnet
ENV PATH="${DOTNET_ROOT}:${PATH}"
