FROM public.ecr.aws/lts/ubuntu:24.04_stable

ENV DEBIAN_FRONTEND=noninteractive \
    AGENT_ALLOW_RUNASROOT=true

# Install all dependencies in single layer and cleanup
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    jq \
    unzip \
    && curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip \
    && unzip -q awscliv2.zip && ./aws/install \
    && rm -rf awscliv2.zip aws /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && apt-get autoremove -y && apt-get clean

# Create agent directory and download agent
WORKDIR /azp
RUN curl -sL https://download.agent.dev.azure.com/agent/4.258.1/vsts-agent-linux-x64-4.258.1.tar.gz | tar -zx

CMD ["bash", "-c", "./config.sh --unattended --url $AZP_URL --auth pat --token $AZP_TOKEN --pool $AZP_POOL --agent $AZP_AGENT_NAME --replace --acceptTeeEula && ./run.sh --once"]