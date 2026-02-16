#!/bin/bash

# Script de déploiement et gestion pour SAE Dev 6.01
# Usage: ./deploy.sh [command]

set -e

NAMESPACE="sae-production"
APP_NAME="sae-app"
REGISTRY="10.129.4.175:5050"
PROJECT_PATH="root/sae-dev6.01"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl n'est pas installé"
        exit 1
    fi
}

function create_namespace() {
    print_info "Création du namespace $NAMESPACE..."
    kubectl apply -f kubernetes/namespace.yaml
}

function create_registry_secret() {
    print_info "Création du secret pour le registry Docker..."
    
    read -p "Username GitLab: " username
    read -sp "Password GitLab: " password
    echo
    
    kubectl create secret docker-registry gitlab-registry-secret \
        --docker-server=$REGISTRY \
        --docker-username=$username \
        --docker-password=$password \
        -n $NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_info "Secret créé avec succès"
}

function deploy_app() {
    print_info "Déploiement de l'application..."
    
    kubectl apply -f kubernetes/deployment.yaml
    kubectl apply -f kubernetes/service.yaml
    
    print_info "Application déployée. En attente du rollout..."
    kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=5m
    
    print_info "Déploiement terminé avec succès!"
}

function show_status() {
    print_info "Status de l'application:"
    echo ""
    echo "=== PODS ==="
    kubectl get pods -n $NAMESPACE
    echo ""
    echo "=== SERVICES ==="
    kubectl get svc -n $NAMESPACE
    echo ""
    echo "=== DEPLOYMENTS ==="
    kubectl get deployment -n $NAMESPACE
}

function show_logs() {
    print_info "Récupération des logs..."
    POD=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$POD" ]; then
        print_error "Aucun pod trouvé"
        exit 1
    fi
    
    print_info "Logs du pod: $POD"
    kubectl logs -f $POD -n $NAMESPACE
}

function delete_app() {
    print_warn "Suppression de l'application..."
    read -p "Êtes-vous sûr? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete -f kubernetes/deployment.yaml
        kubectl delete -f kubernetes/service.yaml
        print_info "Application supprimée"
    else
        print_info "Annulé"
    fi
}

function restart_app() {
    print_info "Redémarrage de l'application..."
    kubectl rollout restart deployment/$APP_NAME -n $NAMESPACE
    kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=5m
    print_info "Application redémarrée"
}

function scale_app() {
    read -p "Nombre de replicas: " replicas
    
    if ! [[ "$replicas" =~ ^[0-9]+$ ]]; then
        print_error "Le nombre de replicas doit être un entier"
        exit 1
    fi
    
    print_info "Scaling à $replicas replicas..."
    kubectl scale deployment/$APP_NAME -n $NAMESPACE --replicas=$replicas
    print_info "Scaling effectué"
}

function setup_complete() {
    print_info "Configuration complète de l'infrastructure..."
    
    check_kubectl
    create_namespace
    create_registry_secret
    deploy_app
    
    print_info ""
    print_info "=========================================="
    print_info "Configuration terminée avec succès!"
    print_info "=========================================="
    show_status
}

function show_help() {
    cat << EOF
Usage: ./deploy.sh [command]

Commands:
    setup       - Configuration complète (namespace, secrets, déploiement)
    deploy      - Déployer l'application
    status      - Afficher le status de l'application
    logs        - Afficher les logs de l'application
    restart     - Redémarrer l'application
    scale       - Modifier le nombre de replicas
    delete      - Supprimer l'application
    namespace   - Créer le namespace
    secret      - Créer le secret pour le registry
    help        - Afficher cette aide

Examples:
    ./deploy.sh setup       # Premier déploiement
    ./deploy.sh status      # Voir l'état
    ./deploy.sh logs        # Voir les logs
    ./deploy.sh scale       # Scaler l'application

EOF
}

# Main
case "${1:-help}" in
    setup)
        setup_complete
        ;;
    deploy)
        check_kubectl
        deploy_app
        ;;
    status)
        check_kubectl
        show_status
        ;;
    logs)
        check_kubectl
        show_logs
        ;;
    restart)
        check_kubectl
        restart_app
        ;;
    scale)
        check_kubectl
        scale_app
        ;;
    delete)
        check_kubectl
        delete_app
        ;;
    namespace)
        check_kubectl
        create_namespace
        ;;
    secret)
        check_kubectl
        create_registry_secret
        ;;
    help|*)
        show_help
        ;;
esac
