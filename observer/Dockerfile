FROM ubuntu:latest

# Installation des outils essentiels et dépendances
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gpg \
    apt-transport-https \
    software-properties-common \
    htop \
    iftop \
    net-tools \
    python3 \
    python3-pip \
    python3-venv \
    python3-full \
    vim \
    jq \
    dnsutils \
    iputils-ping \
    iproute2 \
    openssh-client

# Installation de Grafana selon la procédure officielle
RUN mkdir -p /etc/apt/keyrings/ && \
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list && \
    apt-get update && \
    apt-get install -y grafana && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Installation manuelle de Prometheus
RUN wget -q https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz && \
    tar -xzf prometheus-2.47.0.linux-amd64.tar.gz && \
    mv prometheus-2.47.0.linux-amd64/prometheus /usr/local/bin/ && \
    mv prometheus-2.47.0.linux-amd64/promtool /usr/local/bin/ && \
    mkdir -p /etc/prometheus && \
    mv prometheus-2.47.0.linux-amd64/consoles /etc/prometheus/ && \
    mv prometheus-2.47.0.linux-amd64/console_libraries /etc/prometheus/ && \
    rm -rf prometheus-2.47.0.linux-amd64.tar.gz prometheus-2.47.0.linux-amd64

# Installation manuelle de Node Exporter
RUN wget -q https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz && \
    tar -xzf node_exporter-1.6.1.linux-amd64.tar.gz && \
    mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/ && \
    rm -rf node_exporter-1.6.1.linux-amd64.tar.gz node_exporter-1.6.1.linux-amd64

# Création d'un environnement virtuel Python et installation des packages
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip && \
    pip install requests pandas matplotlib prometheus-client kubernetes

# Création d'un répertoire pour les scripts d'observation
WORKDIR /monitoring-scripts

# Copie des scripts d'observation
COPY monitor.py /monitoring-scripts/
COPY prometheus.yml /etc/prometheus/
COPY grafana-dashboard.json /var/lib/grafana/dashboards/

# Création du répertoire pour les dashboards Grafana
RUN mkdir -p /var/lib/grafana/dashboards && \
    chown -R grafana:grafana /var/lib/grafana

# Création d'un script de démarrage pour les services
RUN echo '#!/bin/bash \n\
mkdir -p /var/lib/grafana/dashboards \n\
chown -R grafana:grafana /var/lib/grafana \n\
service grafana-server start \n\
/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/ --web.console.libraries=/etc/prometheus/console_libraries --web.console.templates=/etc/prometheus/consoles & \n\
/usr/local/bin/node_exporter & \n\
/opt/venv/bin/python /monitoring-scripts/monitor.py & \n\
tail -f /dev/null' > /start.sh && chmod +x /start.sh

# Exposition des ports pour Prometheus et Grafana
EXPOSE 9090 3000

# Commande de démarrage
CMD ["/start.sh"]
