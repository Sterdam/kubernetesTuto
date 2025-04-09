# Documentation MicroK8s Stress Test

Ce document détaille la mise en place et l'utilisation d'un environnement de test de stress pour MicroK8s, permettant d'évaluer les performances et la stabilité d'un cluster Kubernetes.

## Table des matières

- [Présentation du projet](#présentation-du-projet)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration du cluster](#configuration-du-cluster)
- [Construction et déploiement des images](#construction-et-déploiement-des-images)
- [Exécution des tests de stress](#exécution-des-tests-de-stress)
- [Surveillance des métriques](#surveillance-des-métriques)
- [Guide de dépannage](#guide-de-dépannage)

## Présentation du projet

Le projet MicroK8s Stress Test est composé de deux composants principaux :

1. **alpine-lab** : Environnement basé sur Alpine Linux contenant des outils de stress-test pour :
   - CPU (stress-cpu.sh)
   - Mémoire (stress-memory.sh)
   - I/O disque (stress-io.sh)
   - Réseau (stress-network.sh)
   - Test combiné (stress-all.sh)

2. **observer** : Plateforme de monitoring avec :
   - Prometheus pour la collecte de métriques
   - Grafana pour la visualisation
   - Scripts Python pour l'analyse et la génération de graphiques

## Prérequis

- Un cluster MicroK8s opérationnel
- Docker installé
- kubectl configuré pour communiquer avec le cluster
- Un registre d'images Docker local (port 32000)
- Les add-ons MicroK8s suivants activés :
  - dns
  - storage
  - registry
  - metrics-server

## Installation

### Création de la structure de répertoires

```bash
# Créer le répertoire principal du projet
mkdir -p ~/microk8s-stress-test

# Créer les sous-répertoires pour les composants
mkdir -p ~/microk8s-stress-test/alpine-lab
mkdir -p ~/microk8s-stress-test/observer
```

### Configuration du script d'installation

1. Créez un fichier `setup.sh` à la racine du projet et copiez le contenu du script fourni.
2. Rendez le script exécutable et lancez-le :

```bash
chmod +x ~/microk8s-stress-test/setup.sh
cd ~/microk8s-stress-test
./setup.sh
```

Le script va créer tous les fichiers nécessaires avec le contenu approprié dans les répertoires correspondants.

## Configuration du cluster

1. Activez les add-ons nécessaires sur MicroK8s :

```bash
microk8s enable dns storage registry metrics-server
```

2. Vérifiez que le registre local est accessible :

```bash
curl http://localhost:32000/v2/_catalog
```

3. Créez le namespace pour le projet :

```bash
kubectl create namespace stress-test
```

4. Appliquez les configurations RBAC pour les permissions :

```bash
kubectl apply -f ~/microk8s-stress-test/rbac-config.yaml
```

## Construction et déploiement des images

### Image alpine-lab

```bash
# Construire l'image
cd ~/microk8s-stress-test/alpine-lab
docker build -t localhost:32000/alpine-lab:latest .

# Pousser l'image vers le registre local
docker push localhost:32000/alpine-lab:latest
```

### Image observer

```bash
# Construire l'image
cd ~/microk8s-stress-test/observer
docker build -t localhost:32000/observer:latest .

# Pousser l'image vers le registre local
docker push localhost:32000/observer:latest
```

### Déploiement des applications

```bash
# Déployer le composant alpine-lab
kubectl apply -f ~/microk8s-stress-test/alpine-lab-deployment.yaml

# Déployer le composant observer
kubectl apply -f ~/microk8s-stress-test/observer-deployment.yaml
```

### Vérification du déploiement

```bash
# Vérifier que les pods sont en cours d'exécution
kubectl get pods -n stress-test

# Vérifier les services
kubectl get services -n stress-test
```

## Exécution des tests de stress

Pour exécuter les tests de stress, vous devez accéder au pod alpine-lab :

```bash
# Obtenir le nom du pod
POD_NAME=$(kubectl get pods -n stress-test -l app=alpine-lab -o jsonpath='{.items[0].metadata.name}')

# Accéder au pod
kubectl exec -it $POD_NAME -n stress-test -- /bin/bash
```

Une fois dans le pod, vous pouvez exécuter les différents tests de stress :

1. **Test de stress CPU** :
```bash
cd /stress-scripts
./stress-cpu.sh
```

2. **Test de stress mémoire** :
```bash
cd /stress-scripts
./stress-memory.sh
```

3. **Test de stress I/O disque** :
```bash
cd /stress-scripts
./stress-io.sh
```

4. **Test de stress réseau** :
```bash
cd /stress-scripts
./stress-network.sh
```

5. **Test de stress combiné** (tous les aspects) :
```bash
cd /stress-scripts
./stress-all.sh
```

## Surveillance des métriques

### Accès à Prometheus

Prometheus est accessible via un service NodePort :

```bash
# Obtenir le port NodePort de Prometheus
PROMETHEUS_PORT=$(kubectl get svc -n stress-test observer -o jsonpath='{.spec.ports[?(@.name=="prometheus")].nodePort}')

# Accéder à Prometheus
echo "Prometheus est accessible à l'adresse : http://$(hostname -I | awk '{print $1}'):$PROMETHEUS_PORT"
```

### Accès à Grafana

Grafana est également accessible via un service NodePort :

```bash
# Obtenir le port NodePort de Grafana
GRAFANA_PORT=$(kubectl get svc -n stress-test observer -o jsonpath='{.spec.ports[?(@.name=="grafana")].nodePort}')

# Accéder à Grafana
echo "Grafana est accessible à l'adresse : http://$(hostname -I | awk '{print $1}'):$GRAFANA_PORT"
```

Informations de connexion par défaut pour Grafana :
- Utilisateur : admin
- Mot de passe initial : admin

### Configuration de Grafana

1. Connectez-vous à l'interface Grafana
2. Ajoutez une source de données Prometheus :
   - Type : Prometheus
   - URL : http://localhost:9090
   - Accès : Browser
3. Importez le dashboard prédéfini :
   - Dans le menu de gauche, cliquez sur "+" puis "Import"
   - Cliquez sur "Upload JSON file"
   - Sélectionnez le fichier `~/microk8s-stress-test/observer/grafana-dashboard.json`
   - Cliquez sur "Import"

### Analyse des métriques via les scripts Python

Le composant observer inclut également un script Python pour analyser les métriques et générer des graphiques :

```bash
# Obtenir le nom du pod observer
OBSERVER_POD=$(kubectl get pods -n stress-test -l app=observer -o jsonpath='{.items[0].metadata.name}')

# Exécuter le script de monitoring
kubectl exec -it $OBSERVER_POD -n stress-test -- python3 /monitoring-scripts/monitor.py
```

Les graphiques générés seront sauvegardés dans le répertoire `/monitoring-scripts/` du pod observer.

## Guide de dépannage

### Problèmes courants et solutions

1. **Les pods restent en état "Pending"** :
   - Vérifiez les ressources disponibles dans le cluster : `kubectl describe nodes`
   - Vérifiez les événements du pod : `kubectl describe pod <nom-du-pod> -n stress-test`

2. **Erreur "ImagePullBackOff"** :
   - Vérifiez que les images sont correctement poussées vers le registre local
   - Vérifiez les logs du pod : `kubectl logs <nom-du-pod> -n stress-test`
   - Essayez de retirer l'image localement et de la reconstruire

3. **Prometheus ne collecte pas de métriques** :
   - Vérifiez que les annotations sont correctement définies sur les pods
   - Vérifiez la configuration de Prometheus : `kubectl get configmap prometheus-config -n stress-test -o yaml`
   - Consultez les logs de Prometheus : `kubectl logs <nom-du-pod-observer> -n stress-test -c prometheus`

4. **Grafana n'affiche pas de données** :
   - Vérifiez que la source de données Prometheus est correctement configurée
   - Vérifiez que Prometheus collecte des métriques
   - Vérifiez les requêtes des panneaux Grafana

### Commandes utiles pour le diagnostic

```bash
# Vérifier l'état des pods
kubectl get pods -n stress-test

# Voir les logs d'un conteneur
kubectl logs <nom-du-pod> -n stress-test

# Décrire un pod pour voir les événements et les problèmes
kubectl describe pod <nom-du-pod> -n stress-test

# Vérifier les services et leurs endpoints
kubectl get endpoints -n stress-test

# Redémarrer un déploiement
kubectl rollout restart deployment <nom-du-déploiement> -n stress-test
```

### Nettoyage du cluster

Pour supprimer toutes les ressources créées :

```bash
# Supprimer les déploiements
kubectl delete -f ~/microk8s-stress-test/alpine-lab-deployment.yaml
kubectl delete -f ~/microk8s-stress-test/observer-deployment.yaml

# Supprimer les configurations RBAC
kubectl delete -f ~/microk8s-stress-test/rbac-config.yaml

# Supprimer le namespace
kubectl delete namespace stress-test
```
