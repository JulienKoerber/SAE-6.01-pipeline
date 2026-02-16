# Guide de Configuration CI/CD pour SAE Dev 6.01

## Prérequis

1. GitLab installé et accessible
2. GitLab Runner configuré
3. Registry Docker GitLab activé
4. Cluster Kubernetes (k3s) déployé

## Configuration du GitLab Runner

### 1. Installation du Runner sur la VM GitLab

```bash
# Télécharger et installer GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner
```

### 2. Enregistrer le Runner

```bash
sudo gitlab-runner register
```

Paramètres à fournir:
- GitLab URL: `http://10.129.4.175`
- Registration token: Disponible dans Settings > CI/CD > Runners
- Description: `docker-runner`
- Tags: `docker`
- Executor: `docker`
- Default Docker image: `docker:24`

### 3. Configuration du Runner pour Docker-in-Docker

Éditer `/etc/gitlab-runner/config.toml`:

```toml
[[runners]]
  name = "docker-runner"
  url = "http://10.129.4.175"
  token = "VOTRE_TOKEN"
  executor = "docker"
  [runners.docker]
    tls_verify = false
    image = "docker:24"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/certs/client", "/cache"]
    shm_size = 0
```

**Important**: `privileged = true` est nécessaire pour Docker-in-Docker.

## Configuration du Registry Docker GitLab

### 1. Activer le Registry dans GitLab

Éditer `/etc/gitlab/gitlab.rb`:

```ruby
registry_external_url 'http://10.129.4.175:5050'
registry['enable'] = true
```

Reconfigurer GitLab:
```bash
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
```

### 2. Configurer les Variables CI/CD dans GitLab

Aller dans: Settings > CI/CD > Variables

Ajouter les variables suivantes:

| Variable | Valeur | Protected | Masked |
|----------|--------|-----------|---------|
| `CI_REGISTRY_USER` | `root` ou votre username GitLab | ✓ | - |
| `CI_REGISTRY_PASSWORD` | Votre mot de passe ou Personal Access Token | ✓ | ✓ |
| `KUBECONFIG_CONTENT` | Contenu de votre kubeconfig encodé en base64 | ✓ | ✓ |

### 3. Obtenir le KUBECONFIG encodé

Sur votre nœud master k3s:

```bash
# Copier le kubeconfig depuis le master k3s
sudo cat /etc/rancher/k3s/k3s.yaml

# Encoder en base64 (tout sur une ligne)
cat ~/.kube/config | base64 -w 0
```

Copier le résultat dans la variable `KUBECONFIG_CONTENT`.

## Configuration du Cluster Kubernetes

### 1. Créer le Secret pour le Registry Docker

Sur votre cluster k3s:

```bash
# Créer le namespace
kubectl create namespace sae-production

# Créer le secret pour pull les images
kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=10.129.4.175:5050 \
  --docker-username=root \
  --docker-password=VOTRE_MOT_DE_PASSE \
  -n sae-production
```

### 2. Déployer l'application initiale

```bash
# Appliquer les manifests Kubernetes
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
```

### 3. Vérifier le déploiement

```bash
# Vérifier les pods
kubectl get pods -n sae-production

# Vérifier le service
kubectl get svc -n sae-production

# Accéder à l'application
curl http://<NODE_IP>:30080
```

## Résolution des Problèmes Courants

### Erreur 502 lors du push vers GitLab

**Problème**: `fatal: unable to access 'http://10.129.4.175/root/sae-dev6.01/': The requested URL returned error: 502`

**Solutions**:
1. Vérifier que GitLab est bien démarré:
   ```bash
   sudo gitlab-ctl status
   ```

2. Redémarrer GitLab si nécessaire:
   ```bash
   sudo gitlab-ctl restart
   ```

3. Vérifier les logs:
   ```bash
   sudo gitlab-ctl tail
   ```

4. Augmenter la mémoire disponible si nécessaire (minimum 4GB recommandé)

### Le Runner ne peut pas se connecter au daemon Docker

**Solution**: Vérifier que `privileged = true` est bien défini dans `/etc/gitlab-runner/config.toml`

### Erreur d'authentification au Registry

**Solutions**:
1. Vérifier que les variables `CI_REGISTRY_USER` et `CI_REGISTRY_PASSWORD` sont définies
2. Créer un Personal Access Token dans GitLab:
   - Profile > Access Tokens
   - Name: `ci-cd-token`
   - Scopes: `read_registry`, `write_registry`
   - Utiliser ce token comme `CI_REGISTRY_PASSWORD`

### Les pods ne peuvent pas pull l'image

**Solution**: Vérifier que le secret `gitlab-registry-secret` existe:
```bash
kubectl get secret gitlab-registry-secret -n sae-production
```

Si non, le recréer avec les bonnes credentials.

### Le déploiement sur k3s échoue

**Solutions**:
1. Vérifier que `KUBECONFIG_CONTENT` est correctement défini
2. Vérifier que le cluster k3s est accessible depuis le runner GitLab
3. Tester la connectivité manuellement:
   ```bash
   # Sur le runner
   kubectl --kubeconfig=/path/to/config get nodes
   ```

## Test de la Pipeline

### 1. Faire un commit et push

```bash
git add .
git commit -m "test: Pipeline CI/CD"
git push origin main
```

### 2. Suivre l'exécution

Aller dans GitLab: CI/CD > Pipelines

Vous devriez voir 3 stages:
1. ✓ test (lint et tests unitaires)
2. ✓ build (construction et push de l'image)
3. ⏸ deploy (manuel - cliquer pour déployer)

## Architecture de la Solution

```
┌─────────────────┐
│   GitLab VM     │
│  (10.129.4.175) │
│                 │
│  - GitLab       │
│  - Registry:5050│
│  - Runner       │
└────────┬────────┘
         │
         ├──────────────────────┐
         │                      │
┌────────▼────────┐    ┌────────▼────────┐
│   K3s Master    │    │   K3s Workers   │
│                 │    │   (x2)          │
│  - Control      │    │                 │
│    Plane        │    │  - sae-app pods │
└─────────────────┘    └─────────────────┘
```

## Commandes Utiles

### GitLab
```bash
# Status
sudo gitlab-ctl status

# Logs
sudo gitlab-ctl tail

# Restart
sudo gitlab-ctl restart
```

### GitLab Runner
```bash
# Status
sudo gitlab-runner status

# Logs
sudo gitlab-runner --debug run

# Verify
sudo gitlab-runner verify
```

### Kubernetes
```bash
# Voir tous les pods
kubectl get pods -A

# Logs d'un pod
kubectl logs -f <pod-name> -n sae-production

# Décrire un pod
kubectl describe pod <pod-name> -n sae-production

# Supprimer un déploiement
kubectl delete -f kubernetes/deployment.yaml
```

## Prochaines Étapes

1. ✓ Configure GitLab et le Runner
2. ✓ Active le Registry Docker
3. ✓ Configure les variables CI/CD
4. ✓ Déploie le cluster k3s
5. ✓ Crée les secrets Kubernetes
6. ✓ Test la pipeline complète
7. Ajout de monitoring (optionnel)
8. Ajout d'alerting (optionnel)
