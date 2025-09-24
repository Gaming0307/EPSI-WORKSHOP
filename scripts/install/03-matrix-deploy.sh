#!/bin/bash
# Script de déploiement Matrix pour Mission D.I.P.
# Auteur: DEV1 - Backend Team

set -e  # Arrêt en cas d'erreur

# === VARIABLES ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Détection automatique de la racine du projet
if [ -f "$SCRIPT_DIR/.env" ]; then
    PROJECT_ROOT="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../.env" ]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
elif [ -f "$(pwd)/.env" ]; then
    PROJECT_ROOT="$(pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

ENV_FILE="$PROJECT_ROOT/.env"

# === COULEURS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# === FONCTIONS ===
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# === VÉRIFICATIONS PRÉALABLES ===
check_requirements() {
    log "Vérification des prérequis..."
    
    command -v docker >/dev/null 2>&1 || error "Docker n'est pas installé"
    command -v docker-compose >/dev/null 2>&1 || error "Docker Compose n'est pas installé"
    
    if [ ! -f "$ENV_FILE" ]; then
        error "Fichier .env manquant. Copiez .env.example vers .env et configurez-le"
    fi
    
    success "Prérequis validés"
}

# === CRÉATION DES DOSSIERS ===
create_directories() {
    log "Création de la structure des dossiers..."
    
    mkdir -p "$PROJECT_ROOT/data/matrix"
    mkdir -p "$PROJECT_ROOT/data/postgres"
    mkdir -p "$PROJECT_ROOT/security/ssl"
    mkdir -p "$PROJECT_ROOT/backups/matrix"
    
    # Permissions correctes pour Matrix
    chmod 700 "$PROJECT_ROOT/data/matrix"
    chown -R 991:991 "$PROJECT_ROOT/data/matrix" 2>/dev/null || warning "Impossible de changer le propriétaire"
    
    success "Dossiers créés"
}

# === GÉNÉRATION CERTIFICATS SSL ===
generate_ssl_certificates() {
    log "Génération des certificats SSL..."
    
    SSL_DIR="$PROJECT_ROOT/security/ssl"
    
    if [ ! -f "$SSL_DIR/dip.local.crt" ]; then
        # Chargement des variables d'environnement
        source "$ENV_FILE"
        
        # Génération certificat auto-signé
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DIR/dip.local.key" \
            -out "$SSL_DIR/dip.local.crt" \
            -subj "/C=${SSL_COUNTRY:-FR}/ST=${SSL_STATE:-IDF}/L=${SSL_CITY:-Paris}/O=${SSL_ORG:-DIP}/OU=${SSL_UNIT:-IT}/CN=dip.local/emailAddress=admin@dip.local"
        
        success "Certificats SSL générés"
    else
        success "Certificats SSL déjà présents"
    fi
}

# === GÉNÉRATION CLÉS MATRIX ===
generate_matrix_keys() {
    log "Génération des clés Matrix..."
    
    # Configuration homeserver si pas encore fait
    if [ ! -f "$PROJECT_ROOT/data/matrix/homeserver.yaml" ]; then
        docker run --rm \
            -v "$PROJECT_ROOT/data/matrix:/data" \
            -e SYNAPSE_SERVER_NAME=dip.local \
            -e SYNAPSE_REPORT_STATS=no \
            matrixdotorg/synapse:latest generate
        
        # Copier notre configuration personnalisée
        cp "$PROJECT_ROOT/services/matrix/homeserver.yaml" "$PROJECT_ROOT/data/matrix/homeserver.yaml"
        
        success "Configuration Matrix générée"
    else
        success "Configuration Matrix déjà présente"
    fi
}

# === DÉMARRAGE DES SERVICES ===
start_services() {
    log "Démarrage des services Matrix..."
    
    cd "$PROJECT_ROOT"
    
    # Démarrage PostgreSQL d'abord
    docker-compose up -d postgres
    
    # Attente que PostgreSQL soit prêt
    log "Attente de PostgreSQL..."
    sleep 10
    
    # Démarrage Matrix Synapse
    docker-compose up -d matrix-synapse
    
    # Attente que Matrix soit prêt
    log "Attente de Matrix Synapse..."
    sleep 15
    
    success "Services Matrix démarrés"
}

# === CRÉATION UTILISATEUR ADMIN ===
create_admin_user() {
    log "Création de l'utilisateur administrateur..."
    
    source "$ENV_FILE"
    
    # Vérifier si Matrix répond
    for i in {1..30}; do
        if docker exec dip-matrix curl -f http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
            break
        fi
        log "Attente de Matrix... ($i/30)"
        sleep 2
    done
    
    # Créer l'utilisateur admin
    docker exec -it dip-matrix register_new_matrix_user \
        -c /data/homeserver.yaml \
        --user admin \
        --password "${MATRIX_ADMIN_PASSWORD}" \
        --admin \
        http://localhost:8008
    
    success "Utilisateur admin créé (admin / ${MATRIX_ADMIN_PASSWORD})"
}

# === TESTS DE CONNECTIVITÉ ===
test_connectivity() {
    log "Tests de connectivité Matrix..."
    
    # Test API Matrix
    if curl -f -s http://localhost:8008/_matrix/client/versions >/dev/null; then
        success "API Matrix accessible"
    else
        error "API Matrix inaccessible"
    fi
    
    # Test base de données
    if docker exec dip-postgres pg_isready -U synapse >/dev/null 2>&1; then
        success "Base de données accessible"
    else
        error "Base de données inaccessible"
    fi
    
    success "Tests de connectivité réussis"
}

# === FONCTION PRINCIPALE ===
main() {
    echo -e "${BLUE}"
    echo "================================================"
    echo "🛡️  DÉPLOIEMENT MATRIX - MISSION D.I.P."
    echo "================================================"
    echo -e "${NC}"
    
    check_requirements
    create_directories
    generate_ssl_certificates
    generate_matrix_keys
    start_services
    create_admin_user
    test_connectivity
    
    echo -e "${GREEN}"
    echo "================================================"
    echo "✅ DÉPLOIEMENT MATRIX TERMINÉ AVEC SUCCÈS"
    echo "================================================"
    echo -e "${NC}"
    echo
    echo "🔗 Accès Matrix: http://localhost:8008"
    echo "👤 Utilisateur admin: admin"
    echo "🔒 Mot de passe admin: (voir fichier .env)"
    echo
    echo "Prochaines étapes:"
    echo "1. Démarrer Element Web: docker-compose up -d element"
    echo "2. Configurer Nginx: docker-compose up -d nginx"
    echo "3. Tester la messagerie chiffrée"
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi