#!/bin/bash
# Script de déploiement Matrix - Mission D.I.P. - VERSION CORRIGÉE

set -e

echo "🛡️ === DÉPLOIEMENT MATRIX SYNAPSE - MISSION D.I.P. ==="

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
MATRIX_DATA="$PROJECT_ROOT/data/matrix"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[ÉTAPE]${NC} $1"
}

# Vérifications préalables
check_requirements() {
    log_step "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    # Vérifier Docker Compose (nouvelle ou ancienne syntaxe)
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        log_error "Fichier .env manquant. Copiez .env.example vers .env"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
        log_error "Fichier docker-compose.yml manquant"
        exit 1
    fi
    
    log_info "✅ Prérequis validés"
}

# Création des répertoires
create_directories() {
    log_step "Création des répertoires de données..."
    
    mkdir -p "$MATRIX_DATA"/{media_store,uploads}
    mkdir -p "$PROJECT_ROOT/data/postgres"
    mkdir -p "$PROJECT_ROOT/security/ssl"
    
    # Permissions appropriées
    chmod 755 "$MATRIX_DATA"
    chmod 755 "$MATRIX_DATA"/{media_store,uploads}
    
    log_info "✅ Répertoires créés"
}

# Génération des certificats SSL
generate_ssl_certs() {
    log_step "Vérification des certificats SSL..."
    
    local ssl_dir="$PROJECT_ROOT/security/ssl"
    local cert_file="$ssl_dir/dip.crt"
    local key_file="$ssl_dir/dip.key"
    
    if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
        log_info "Génération des certificats SSL..."
        
        # Créer le script de génération s'il n'existe pas
        if [ ! -f "$ssl_dir/generate-certs.sh" ]; then
            cat > "$ssl_dir/generate-certs.sh" << 'EOF'
#!/bin/bash
DOMAIN="dip.local"
CERT_DIR="$(dirname "$0")"

openssl genrsa -out "$CERT_DIR/dip.key" 2048
openssl req -new -x509 -key "$CERT_DIR/dip.key" -out "$CERT_DIR/dip.crt" -days 365 \
    -subj "/C=FR/ST=IDF/L=Paris/O=D.I.P./CN=$DOMAIN"

chmod 600 "$CERT_DIR/dip.key"
chmod 644 "$CERT_DIR/dip.crt"

echo "✅ Certificats SSL générés"
EOF
            chmod +x "$ssl_dir/generate-certs.sh"
        fi
        
        # Exécuter la génération
        cd "$ssl_dir" && bash generate-certs.sh
        log_info "✅ Certificats SSL générés"
    else
        log_info "✅ Certificats SSL existants"
    fi
}

# Configuration Matrix avec auto-génération des clés
setup_matrix_config() {
    log_step "Configuration de Matrix Synapse..."
    
    # Le homeserver.yaml doit être présent
    if [ ! -f "$PROJECT_ROOT/services/matrix/homeserver.yaml" ]; then
        log_error "Configuration homeserver.yaml manquante dans services/matrix/"
        exit 1
    fi
    
    log_info "✅ Configuration Matrix validée"
}

# Test de configuration
test_configuration() {
    log_step "Démarrage et test des services..."
    
    cd "$PROJECT_ROOT"
    
    # Démarrer PostgreSQL
    log_info "Démarrage de PostgreSQL..."
    $COMPOSE_CMD up -d postgres
    
    # Attendre PostgreSQL
    log_info "Attente de PostgreSQL..."
    for i in {1..30}; do
        if $COMPOSE_CMD exec -T postgres pg_isready -U synapse >/dev/null 2>&1; then
            break
        fi
        sleep 2
        echo -n "."
    done
    echo
    log_info "✅ PostgreSQL opérationnel"
    
    # Démarrer Matrix (avec auto-génération des clés)
    log_info "Démarrage de Matrix Synapse..."
    $COMPOSE_CMD up -d matrix-synapse
    
    # Attendre Matrix
    log_info "Attente de Matrix Synapse..."
    for i in {1..60}; do
        if curl -sf http://localhost:8008/health >/dev/null 2>&1; then
            break
        fi
        sleep 2
        echo -n "."
    done
    echo
    
    if curl -sf http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
        log_info "✅ Matrix Synapse opérationnel"
        
        # Vérifier que la clé a été générée
        if $COMPOSE_CMD exec -T synapse test -f /data/homeserver.signing.key; then
            log_info "✅ Clé de signature générée automatiquement"
        fi
    else
        log_error "❌ Problème avec Matrix Synapse"
        $COMPOSE_CMD logs matrix-synapse | tail -20
        exit 1
    fi
    
    # Démarrer Nginx
    log_info "Démarrage du reverse proxy..."
    $COMPOSE_CMD up -d nginx
    
    # Test final HTTPS
    sleep 5
    if curl -sk https://localhost/_matrix/client/versions >/dev/null 2>&1; then
        log_info "✅ Interface HTTPS opérationnelle"
    else
        log_warn "⚠️  Interface HTTPS ne répond pas encore"
    fi
}

# Création du premier administrateur
create_admin_user() {
    log_step "Création de l'utilisateur administrateur..."
    
    echo ""
    echo "📝 Création du compte administrateur D.I.P."
    echo "   Nom d'utilisateur recommandé: admin"
    echo "   Mot de passe: [choisir un mot de passe fort]"
    echo "   Admin: répondez 'y' pour les privilèges admin"
    echo ""
    
    cd "$PROJECT_ROOT"
    
    if $COMPOSE_CMD exec -it synapse register_new_matrix_user \
        -c /data/homeserver.yaml \
        -a http://localhost:8008; then
        log_info "✅ Utilisateur admin créé avec succès"
    else
        log_error "❌ Erreur lors de la création de l'utilisateur"
        return 1
    fi
}

# Configuration des salons par défaut
setup_default_rooms() {
    log_step "Information sur les salons par défaut..."
    
    echo ""
    echo "📋 Salons recommandés à créer via l'interface web:"
    echo "   - #general:dip.local (public, discussions générales)"
    echo "   - #annonces:dip.local (admins seulement, annonces)"
    echo "   - #support:dip.local (public, support technique)"
    echo "   - #urgence:dip.local (alertes d'urgence)"
    echo ""
    echo "🌐 Accès: https://localhost"
}

# Menu principal
main() {
    echo "🛡️ Configuration Matrix Synapse - Mission D.I.P."
    echo "================================================="
    
    check_requirements
    create_directories
    generate_ssl_certs
    setup_matrix_config
    test_configuration
    
    echo ""
    echo "✅ Matrix Synapse déployé avec succès!"
    echo ""
    echo "🌐 Accès aux services:"
    echo "   - Interface D.I.P.: https://localhost"
    echo "   - API Matrix: https://localhost/_matrix"
    echo "   - Element intégré: https://localhost/element"
    echo ""
    
    read -p "Créer un utilisateur administrateur maintenant? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_admin_user
    else
        echo "⚠️  Vous pourrez créer l'admin plus tard avec:"
        echo "   $COMPOSE_CMD exec -it synapse register_new_matrix_user -c /data/homeserver.yaml -a http://localhost:8008"
    fi
    
    setup_default_rooms
    
    echo ""
    echo "🎯 Mission accomplie! La résistance peut maintenant communiquer de manière sécurisée."
    echo ""
    echo "📚 Documentation: docs/users/matrix-guide.md"
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi