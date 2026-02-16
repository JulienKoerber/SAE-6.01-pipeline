# Guide de Dépannage - Erreur 502 GitLab

## Problème Actuel

```
fatal: unable to access 'http://10.129.4.175/root/sae-dev6.01/': 
The requested URL returned error: 502
```

## Causes Possibles

L'erreur 502 (Bad Gateway) indique que le serveur GitLab ne répond pas correctement. Voici les causes courantes:

1. GitLab n'est pas complètement démarré
2. Manque de ressources (RAM/CPU)
3. Services GitLab en erreur
4. Configuration réseau incorrecte

## Solutions par Ordre de Priorité

### 1. Vérifier l'État de GitLab

Connectez-vous à votre VM GitLab (10.129.4.175):

```bash
ssh user@10.129.4.175
```

Vérifier le status de tous les services:

```bash
sudo gitlab-ctl status
```

**Résultat attendu**: Tous les services doivent être "run"

Si certains services sont "down":

```bash
# Redémarrer GitLab
sudo gitlab-ctl restart

# Attendre quelques minutes que tous les services démarrent
# GitLab peut prendre 2-5 minutes pour être complètement opérationnel
```

### 2. Vérifier les Ressources Système

GitLab nécessite **minimum 4GB de RAM**:

```bash
# Vérifier la mémoire disponible
free -h

# Vérifier l'utilisation CPU
top
```

Si la RAM est insuffisante:

**Sur Proxmox**:
1. Arrêter la VM GitLab
2. Augmenter la RAM à au moins 4GB (8GB recommandé)
3. Redémarrer la VM

**Alternative temporaire** - Ajouter du swap:

```bash
# Créer un fichier swap de 2GB
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Rendre permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 3. Vérifier les Logs GitLab

Consulter les logs pour identifier le problème:

```bash
# Logs de tous les services
sudo gitlab-ctl tail

# Logs spécifiques
sudo gitlab-ctl tail nginx
sudo gitlab-ctl tail unicorn
sudo gitlab-ctl tail postgresql
```

Rechercher les erreurs critiques (ERROR, FATAL).

### 4. Reconfigurer GitLab

Si les services ne démarrent pas correctement:

```bash
# Arrêter GitLab
sudo gitlab-ctl stop

# Reconfigurer
sudo gitlab-ctl reconfigure

# Redémarrer
sudo gitlab-ctl start

# Vérifier le status après 2-3 minutes
sudo gitlab-ctl status
```

### 5. Vérifier la Configuration Réseau

Tester l'accès HTTP à GitLab:

```bash
# Depuis la VM GitLab elle-même
curl -I http://localhost

# Depuis votre machine locale
curl -I http://10.129.4.175
```

**Résultat attendu**: Code HTTP 200 ou 302

Vérifier que le port 80 est ouvert:

```bash
sudo netstat -tlnp | grep :80
```

### 6. Redémarrage Complet de la VM

Si rien ne fonctionne:

```bash
# Depuis Proxmox ou sur la VM
sudo reboot
```

Attendre 5-10 minutes après le redémarrage que GitLab démarre complètement.

## Vérification Finale

Une fois GitLab opérationnel:

```bash
# Test depuis votre machine locale
curl http://10.129.4.175

# Pousser vers GitLab
cd /Users/julienkoerber/Documents/DevCloud_3/sae-dev6.01
git push origin main
```

## Alternative: Utiliser HTTPS au lieu de HTTP

Si le problème persiste avec HTTP, configurer HTTPS:

### Sur la VM GitLab:

```bash
sudo vim /etc/gitlab/gitlab.rb
```

Modifier:
```ruby
external_url 'https://10.129.4.175'
```

Reconfigurer:
```bash
sudo gitlab-ctl reconfigure
```

### Sur votre machine locale:

```bash
# Mettre à jour l'URL remote
git remote set-url origin https://10.129.4.175/root/sae-dev6.01.git

# Pousser
git push origin main
```

## Checklist de Diagnostic Rapide

Exécutez ces commandes sur la VM GitLab:

```bash
#!/bin/bash

echo "=== GitLab Services Status ==="
sudo gitlab-ctl status

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Disk Usage ==="
df -h

echo ""
echo "=== GitLab Version ==="
sudo gitlab-rake gitlab:env:info

echo ""
echo "=== Network Check ==="
curl -I http://localhost

echo ""
echo "=== Recent Logs (last 20 lines) ==="
sudo gitlab-ctl tail nginx 2>&1 | tail -20
```

Copiez le résultat pour analyser le problème.

## Après Résolution

Une fois GitLab fonctionnel:

1. **Configurer les Variables CI/CD**
   - Aller dans Settings > CI/CD > Variables
   - Ajouter `CI_REGISTRY_USER` et `CI_REGISTRY_PASSWORD`

2. **Vérifier le Runner**
   ```bash
   sudo gitlab-runner verify
   sudo gitlab-runner list
   ```

3. **Tester la Pipeline**
   ```bash
   git add .
   git commit -m "test: Pipeline CI/CD"
   git push origin main
   ```

4. **Surveiller la Pipeline**
   - Aller dans GitLab > CI/CD > Pipelines
   - Vérifier que les 3 stages s'exécutent correctement

## Ressources Utiles

- Documentation GitLab: https://docs.gitlab.com/ee/administration/
- Troubleshooting: https://docs.gitlab.com/ee/administration/troubleshooting/
- Requirements: https://docs.gitlab.com/ee/install/requirements.html

## Contact Support

Si le problème persiste après toutes ces étapes:

1. Capturer les logs complets:
   ```bash
   sudo gitlab-ctl tail > /tmp/gitlab-logs.txt
   ```

2. Noter la version de GitLab:
   ```bash
   sudo gitlab-rake gitlab:env:info
   ```

3. Documenter les étapes de reproduction du problème
