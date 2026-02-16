# Prochaines Étapes - SAE DEV 6.01

## 🎯 Ce qui a été fait automatiquement

✅ **Structure du projet créée**
- Manifestes Kubernetes (namespace, deployment, service)
- Pipeline CI/CD amélioré (build + deploy)
- Scripts de déploiement et vérification
- Documentation complète (README, QUICKSTART, LIVRABLES)

## 📋 Ce qu'il reste à faire - DANS L'ORDRE

### 🔴 ÉTAPE 1: Configurer les GitLab Runners (PRIORITAIRE)

Vous devez configurer 2 runners GitLab:

#### Runner 1: Pour le Build Docker (sur la VM GitLab)
```bash
# Connectez-vous en SSH à la VM GitLab (10.129.4.175)
ssh user@10.129.4.175

# Installer GitLab Runner
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner

# Récupérer le token d'enregistrement:
# Dans GitLab UI: Settings > CI/CD > Runners > New project runner
# Copiez le registration token

# Enregistrer le runner
sudo gitlab-runner register \
  --url http://10.129.4.175 \
  --registration-token VOTRE_TOKEN \
  --executor docker \
  --docker-image docker:24 \
  --tag-list docker \
  --docker-privileged \
  --non-interactive \
  --description "Runner Docker pour build"

# Vérifier
sudo gitlab-runner list
sudo gitlab-runner verify
```

#### Runner 2: Pour le Déploiement k3s (sur le nœud Master k3s)
```bash
# Connectez-vous en SSH au nœud master k3s
ssh user@<IP_MASTER_K3S>

# Installer GitLab Runner
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner

# Enregistrer le runner
sudo gitlab-runner register \
  --url http://10.129.4.175 \
  --registration-token VOTRE_TOKEN \
  --executor shell \
  --tag-list k3s-deploy \
  --non-interactive \
  --description "Runner k3s pour deploy"

# Installer kubectl si nécessaire
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Configurer kubectl pour l'utilisateur gitlab-runner
sudo mkdir -p /home/gitlab-runner/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/gitlab-runner/.kube/config
sudo chown -R gitlab-runner:gitlab-runner /home/gitlab-runner/.kube

# Tester
sudo -u gitlab-runner kubectl get nodes
```

### 🟠 ÉTAPE 2: Créer un Token d'Accès GitLab

1. Dans GitLab: **Settings > Access Tokens**
2. Créez un token avec:
   - Name: `k3s-registry-access`
   - Expiration: dans 1 an
   - Scopes: `api`, `read_registry`, `write_registry`
3. **COPIEZ LE TOKEN** (important!)

### 🟡 ÉTAPE 3: Configurer les Variables CI/CD

Dans GitLab: **Settings > CI/CD > Variables**

#### Ajouter K3S_KUBECONFIG:

Sur le master k3s:
```bash
# Encoder le kubeconfig
cat /etc/rancher/k3s/k3s.yaml | base64 -w 0
```

Dans GitLab, créez la variable:
- Key: `K3S_KUBECONFIG`
- Value: [le résultat du base64]
- Type: Variable
- Protected: ✓
- Masked: ✓

### 🟢 ÉTAPE 4: Déploiement Initial sur k3s

Sur le nœud master k3s:

```bash
# 1. Cloner le projet
git clone http://10.129.4.175/root/sae-dev6.01.git
cd sae-dev6.01

# 2. Créer le secret pour la registry GitLab
kubectl create secret docker-registry gitlab-registry-secret \
  --docker-server=10.129.4.175:5050 \
  --docker-username=root \
  --docker-password=VOTRE_TOKEN_GITLAB \
  --docker-email=admin@example.com \
  --namespace=default

# 3. Copier le secret dans le namespace de production
kubectl create namespace sae-production
kubectl get secret gitlab-registry-secret -n default -o yaml | \
  sed 's/namespace: default/namespace: sae-production/' | \
  kubectl apply -f -

# 4. Déployer les manifestes Kubernetes
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml

# 5. Vérifier
kubectl get all -n sae-production
```

### 🔵 ÉTAPE 5: Tester le Pipeline CI/CD

```bash
# 1. Faire une modification dans le code
cd /path/to/sae-dev6.01
echo "Test pipeline" >> README.md

# 2. Commit et push
git add .
git commit -m "Test: Premier déploiement automatique"
git push origin main

# 3. Dans GitLab UI:
#    - CI/CD > Pipelines
#    - Vérifier que le stage "build" fonctionne
#    - Cliquer sur le bouton play du stage "deploy"

# 4. Vérifier sur k3s
kubectl get pods -n sae-production -w
```

### 🟣 ÉTAPE 6: Vérifier que Tout Fonctionne

```bash
# Exécuter le script de vérification
cd sae-dev6.01
chmod +x check-infrastructure.sh
./check-infrastructure.sh

# Tester l'accès à l'application
# Récupérer l'IP d'un nœud
kubectl get nodes -o wide

# Tester (remplacez <NODE_IP>)
curl http://<NODE_IP>:30080
```

### ⚪ ÉTAPE 7: Préparer les Livrables

Consultez [LIVRABLES.md](LIVRABLES.md) pour la liste complète.

**Captures essentielles à prendre:**
1. Proxmox avec les 4 VMs
2. GitLab avec le projet
3. Pipeline réussi
4. `kubectl get all -n sae-production`
5. Application dans le navigateur

## 🚨 Points d'Attention

### 1. Adresses IP
Vérifiez et adaptez les IP dans votre configuration:
- GitLab: `10.129.4.175` (à vérifier)
- Master k3s: à définir
- Workers: à définir

### 2. Registry Docker
La registry est configurée en HTTP (non HTTPS). Sur chaque nœud k3s, vérifiez:

```bash
# Fichier: /etc/rancher/k3s/registries.yaml
sudo cat /etc/rancher/k3s/registries.yaml

# Devrait contenir:
mirrors:
  "10.129.4.175:5050":
    endpoint:
      - "http://10.129.4.175:5050"

configs:
  "10.129.4.175:5050":
    tls:
      insecure_skip_verify: true
```

Si le fichier n'existe pas, créez-le et redémarrez k3s:
```bash
sudo systemctl restart k3s
```

### 3. Réseau k3s
Assurez-vous que tous les nœuds peuvent communiquer entre eux et avec GitLab.

Test de connectivité:
```bash
# Depuis chaque nœud k3s
ping 10.129.4.175
curl http://10.129.4.175:5050/v2/
```

## 📞 Aide au Dépannage

### Le runner ne se lance pas
```bash
sudo gitlab-runner status
sudo gitlab-runner verify
sudo journalctl -u gitlab-runner -f
```

### Le build échoue
- Vérifier que le runner Docker a les droits privilégiés
- Vérifier la connexion à la registry

### Le déploiement échoue
- Vérifier que la variable K3S_KUBECONFIG est bien configurée
- Vérifier que kubectl fonctionne pour l'utilisateur gitlab-runner
- Vérifier les logs du job dans GitLab

### Les pods ne démarrent pas
```bash
kubectl describe pod <pod-name> -n sae-production
kubectl get events -n sae-production --sort-by='.lastTimestamp'
```

## ✅ Checklist Rapide

Avant de considérer le projet terminé, vérifiez:

- [ ] Les 4 VMs Proxmox sont actives
- [ ] GitLab est accessible
- [ ] Les 2 runners GitLab sont actifs
- [ ] Le cluster k3s a 3 nœuds (1 master + 2 workers)
- [ ] Le token GitLab est créé
- [ ] La variable K3S_KUBECONFIG est configurée
- [ ] Le secret gitlab-registry-secret existe
- [ ] Les manifestes Kubernetes sont déployés
- [ ] Le pipeline CI/CD fonctionne
- [ ] L'application est accessible sur le NodePort

## 📚 Ordre de Lecture de la Documentation

1. **Ce fichier (NEXT_STEPS.md)** - Pour savoir quoi faire
2. **[QUICKSTART.md](QUICKSTART.md)** - Guide détaillé pas à pas
3. **[README.md](README.md)** - Documentation complète du projet
4. **[LIVRABLES.md](LIVRABLES.md)** - Liste des livrables à préparer

## 🎯 Résumé en 3 Commandes

```bash
# 1. Configurer les runners (voir ÉTAPE 1)
# 2. Configurer GitLab (voir ÉTAPES 2-3)

# 3. Déployer tout avec ce script simplifié:
git clone http://10.129.4.175/root/sae-dev6.01.git
cd sae-dev6.01
chmod +x deploy.sh
./deploy.sh
```

---

**Bon courage pour la suite du projet ! 🚀**

Si vous avez des questions, consultez la documentation complète ou utilisez le script de vérification.
