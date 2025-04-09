FROM alpine:latest

# Installation des outils de base et des outils de stress
RUN apk update && apk add --no-cache \
    stress-ng \
    curl \
    wget \
    htop \
    procps \
    bash \
    coreutils \
    util-linux \
    python3 \
    py3-pip

# Création d'un répertoire pour les scripts de stress
WORKDIR /stress-scripts

# Copie des scripts de stress
COPY stress-cpu.sh /stress-scripts/
COPY stress-memory.sh /stress-scripts/
COPY stress-io.sh /stress-scripts/
COPY stress-network.sh /stress-scripts/
COPY stress-all.sh /stress-scripts/

# Rendre les scripts exécutables
RUN chmod +x /stress-scripts/*.sh

# Exposition d'un port pour le monitoring
EXPOSE 8080

# Commande par défaut (juste pour garder le conteneur en vie)
CMD ["tail", "-f", "/dev/null"]
