# SAE Dev 6.01 - Address Book Service

Service de carnet d'adresses avec CI/CD complète sur GitLab et déploiement Kubernetes.

## Description du Projet

Cette SAE (Situation d'Apprentissage et d'Évaluation) consiste à mettre en place une infrastructure complète de CI/CD pour une application Python utilisant Tornado.

### Architecture

- **Application**: Service REST de carnet d'adresses en Python/Tornado
- **CI/CD**: GitLab CI avec Registry Docker
- **Orchestration**: Kubernetes (k3s)
- **Infrastructure**: Proxmox avec 4 VMs

## Structure du Projet

```
.
├── addrservice/           # Code source de l'application
│   ├── database/          # Couche d'accès aux données
│   ├── tornado/           # Application web Tornado
│   └── utils/             # Utilitaires
├── configs/               # Fichiers de configuration
├── data/                  # Données de test
├── kubernetes/            # Manifests Kubernetes
├── schema/                # Schémas JSON
├── tests/                 # Tests unitaires et d'intégration
├── Dockerfile             # Construction de l'image Docker
├── .gitlab-ci.yml         # Pipeline CI/CD
└── requirements.txt       # Dépendances Python
```

## Pipeline CI/CD

La pipeline GitLab comprend 3 stages:

### 1. Test
- Exécution du linter (flake8)
- Validation du code (mypy)
- Tests unitaires

### 2. Build
- Construction de l'image Docker
- Push vers le Registry GitLab
- Tagging avec SHA du commit et 'latest'

### 3. Deploy
- Déploiement sur cluster Kubernetes (k3s)
- Mise à jour du déploiement existant
- Vérification du rollout
- **Mode manuel** pour contrôle

## Développement Local

### Prérequis

- Python 3.9+
- Docker (optionnel)

### Installation

```bash
# Cloner le projet
git clone http://10.129.4.175/root/sae-dev6.01.git
cd sae-dev6.01

# Installer les dépendances
pip install -r requirements.txt
```

### Exécution

```bash
# Lancer l'application
python addrservice/tornado/server.py --port 8080 --config ./configs/addressbook-local.yaml
```

L'application sera accessible sur http://localhost:8080

### Tests

```bash
# Tous les tests
python run.py test --suite all

# Tests unitaires uniquement
python run.py test --suite unit

# Tests d'intégration
python run.py test --suite integration

# Linting
python run.py lint

# Type checking
python run.py typecheck
```

### Construction Docker

```bash
# Build de l'image
docker build -t sae-addressbook:latest .

# Exécution du conteneur
docker run -p 8080:8080 sae-addressbook:latest
```

## Déploiement

### Prérequis Infrastructure

1. **VM GitLab** (10.129.4.175)
   - GitLab CE installé
   - GitLab Runner configuré
   - Registry Docker actif sur port 5050

2. **VM Kubernetes** (3 nœuds)
   - k3s installé
   - kubectl configuré
   - Accès réseau depuis GitLab Runner

### Configuration

Voir [GITLAB_SETUP.md](GITLAB_SETUP.md) pour la configuration complète de:
- GitLab Runner
- Registry Docker
- Variables CI/CD
- Secrets Kubernetes

### Déploiement Manuel sur k3s

```bash
# Créer le namespace
kubectl apply -f kubernetes/namespace.yaml

# Déployer l'application
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml

# Vérifier le déploiement
kubectl get pods -n sae-production
kubectl get svc -n sae-production
```

### Accès à l'Application

Une fois déployée:
```bash
# Via NodePort (depuis le réseau local)
curl http://<NODE_IP>:30080

# Vérifier les endpoints
kubectl get endpoints -n sae-production
```

## API Endpoints

L'application expose les endpoints suivants:

```
GET  /addresses          # Liste toutes les adresses
GET  /addresses/{id}     # Récupère une adresse par ID
POST /addresses          # Crée une nouvelle adresse
PUT  /addresses/{id}     # Met à jour une adresse
DELETE /addresses/{id}   # Supprime une adresse
```

### Exemple d'utilisation

```bash
# Lister les adresses
curl http://localhost:8080/addresses

# Ajouter une adresse
curl -X POST http://localhost:8080/addresses \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com"
  }'
```

## Résolution de Problèmes

### Erreur 502 sur GitLab

Le serveur GitLab n'est pas accessible. Solutions:

```bash
# Vérifier le status
sudo gitlab-ctl status

# Redémarrer si nécessaire
sudo gitlab-ctl restart

# Vérifier les logs
sudo gitlab-ctl tail
```

### Pipeline échoue au stage Build

1. Vérifier que le Runner est actif:
   ```bash
   sudo gitlab-runner verify
   ```

2. Vérifier les variables CI/CD dans GitLab:
   - `CI_REGISTRY_USER`
   - `CI_REGISTRY_PASSWORD`

3. Vérifier que le Registry est accessible:
   ```bash
   curl http://10.129.4.175:5050/v2/
   ```

### Pods ne démarrent pas

1. Vérifier les logs du pod:
   ```bash
   kubectl logs <pod-name> -n sae-production
   ```

2. Vérifier le secret pour le registry:
   ```bash
   kubectl get secret gitlab-registry-secret -n sae-production
   ```

3. Vérifier l'image:
   ```bash
   kubectl describe pod <pod-name> -n sae-production
   ```

## Technologies Utilisées

- **Python 3.9**: Langage de programmation
- **Tornado 6.0**: Framework web asynchrone
- **Docker**: Conteneurisation
- **Kubernetes (k3s)**: Orchestration
- **GitLab**: CI/CD et Registry
- **Proxmox**: Virtualisation

## Auteur

Projet SAE Dev 6.01 - DevOps & Infrastructure

## Licence

Voir fichier [LICENSE](LICENSE)

## Prochaines Améliorations

- [ ] Ajout de tests d'intégration dans la pipeline
- [ ] Monitoring avec Prometheus/Grafana
- [ ] Logging centralisé
- [ ] Health checks et readiness probes
- [ ] Ingress Controller pour accès HTTP
- [ ] Certificats SSL/TLS
- [ ] Backup automatique des données
