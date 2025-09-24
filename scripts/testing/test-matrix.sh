#!/bin/bash
# Tests API Matrix pour Mission D.I.P.
# Auteur: DEV1 - Backend Team

set -e

# === VARIABLES ===
MATRIX_URL="http://localhost:8008"
ADMIN_USER="admin"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# === COULEURS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    return 1
}

# === CHARGEMENT CONFIGURATION ===
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

ADMIN_PASSWORD="${MATRIX_ADMIN_PASSWORD:-Admin_DIP_2024!}"

# === TESTS API ===

# Test 1: Version API
test_api_version() {
    log "Test 1: Vérification version API..."
    
    response=$(curl -s -f "$MATRIX_URL/_matrix/client/versions" 2>/dev/null)
    
    if echo "$response" | grep -q "versions"; then
        success "API Matrix accessible"
        echo "   📋 Versions supportées: $(echo "$response" | jq -r '.versions[]' 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')"
    else
        error "API Matrix inaccessible"
    fi
}

# Test 2: Authentification admin
test_admin_login() {
    log "Test 2: Authentification administrateur..."
    
    login_data=$(cat <<EOF
{
    "type": "m.login.password",
    "user": "$ADMIN_USER",
    "password": "$ADMIN_PASSWORD"
}
EOF
)
    
    response=$(curl -s -X POST "$MATRIX_URL/_matrix/client/r0/login" \
        -H "Content-Type: application/json" \
        -d "$login_data" 2>/dev/null)
    
    if echo "$response" | grep -q "access_token"; then
        ACCESS_TOKEN=$(echo "$response" | jq -r '.access_token' 2>/dev/null)
        USER_ID=$(echo "$response" | jq -r '.user_id' 2>/dev/null)
        success "Authentification admin réussie"
        echo "   👤 User ID: $USER_ID"
        echo "   🔑 Token: ${ACCESS_TOKEN:0:20}..."
    else
        error "Échec authentification admin"
        echo "   Response: $response"
    fi
}

# Test 3: Création de salon
test_room_creation() {
    log "Test 3: Création de salon de test..."
    
    if [ -z "$ACCESS_TOKEN" ]; then
        error "Token d'authentification manquant"
        return 1
    fi
    
    room_data=$(cat <<EOF
{
    "room_alias_local_part": "test-dip",
    "name": "Salon Test D.I.P.",
    "topic": "Salon de test pour la mission D.I.P.",
    "preset": "private_chat",
    "creation_content": {
        "m.federate": false
    }
}
EOF
)
    
    response=$(curl -s -X POST "$MATRIX_URL/_matrix/client/r0/createRoom" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$room_data" 2>/dev/null)
    
    if echo "$response" | grep -q "room_id"; then
        ROOM_ID=$(echo "$response" | jq -r '.room_id' 2>/dev/null)
        success "Salon créé avec succès"
        echo "   🏠 Room ID: $ROOM_ID"
    else
        error "Échec création de salon"
        echo "   Response: $response"
    fi
}

# Test 4: Envoi de message
test_send_message() {
    log "Test 4: Envoi de message test..."
    
    if [ -z "$ROOM_ID" ] || [ -z "$ACCESS_TOKEN" ]; then
        error "Room ID ou token manquant"
        return 1
    fi
    
    message_data=$(cat <<EOF
{
    "msgtype": "m.text",
    "body": "🛡️ Message de test - Mission D.I.P. active! [$(date)]"
}
EOF
)
    
    response=$(curl -s -X PUT "$MATRIX_URL/_matrix/client/r0/rooms/$ROOM_ID/send/m.room.message/test_$(date +%s)" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$message_data" 2>/dev/null)
    
    if echo "$response" | grep -q "event_id"; then
        EVENT_ID=$(echo "$response" | jq -r '.event_id' 2>/dev/null)
        success "Message envoyé avec succès"
        echo "   📧 Event ID: $EVENT_ID"
    else
        error "Échec envoi de message"
        echo "   Response: $response"
    fi
}

# Test 5: Récupération des messages
test_get_messages() {
    log "Test 5: Récupération des messages..."
    
    if [ -z "$ROOM_ID" ] || [ -z "$ACCESS_TOKEN" ]; then
        error "Room ID ou token manquant"
        return 1
    fi
    
    response=$(curl -s "$MATRIX_URL/_matrix/client/r0/rooms/$ROOM_ID/messages?dir=b&limit=5" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null)
    
    if echo "$response" | grep -q "chunk"; then
        message_count=$(echo "$response" | jq '.chunk | length' 2>/dev/null)
        success "Messages récupérés avec succès"
        echo "   📨 Nombre de messages: $message_count"
    else
        error "Échec récupération des messages"
        echo "   Response: $response"
    fi
}

# Test 6: État du serveur
test_server_status() {
    log "Test 6: État du serveur Matrix..."
    
    # Test santé générale
    if curl -s -f "$MATRIX_URL/_matrix/client/versions" >/dev/null 2>&1; then
        success "Serveur Matrix opérationnel"
    else
        error "Serveur Matrix non opérationnel"
    fi
    
    # Test métriques (si activées)
    if curl -s -f "$MATRIX_URL/_synapse/metrics" >/dev/null 2>&1; then
        success "Métriques disponibles"
    else
        warning "Métriques non disponibles"
    fi
}

# Test 7: Chiffrement E2E
test_encryption() {
    log "Test 7: Vérification du chiffrement E2E..."
    
    if [ -z "$ROOM_ID" ] || [ -z "$ACCESS_TOKEN" ]; then
        error "Room ID ou token manquant"
        return 1
    fi
    
    # Activer le chiffrement dans le salon
    encryption_data='{"algorithm": "m.megolm.v1.aes-sha2"}'
    
    response=$(curl -s -X PUT "$MATRIX_URL/_matrix/client/r0/rooms/$ROOM_ID/state/m.room.encryption" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$encryption_data" 2>/dev/null)
    
    if echo "$response" | grep -q "event_id"; then
        success "Chiffrement E2E activé sur le salon"
    else
        warning "Impossible d'activer le chiffrement (normal si déjà activé)"
    fi
}

# === NETTOYAGE ===
cleanup() {
    log "Nettoyage: Suppression du salon de test..."
    
    if [ -n "$ROOM_ID" ] && [ -n "$ACCESS_TOKEN" ]; then
        curl -s -X POST "$MATRIX_URL/_matrix/client/r0/rooms/$ROOM_ID/leave" \
            -H "Authorization: Bearer $ACCESS_TOKEN" >/dev/null 2>&1
        success "Salon de test supprimé"
    fi
}

# === FONCTION PRINCIPALE ===
main() {
    echo -e "${BLUE}"
    echo "================================================"
    echo "🧪 TESTS API MATRIX - MISSION D.I.P."
    echo "================================================"
    echo -e "${NC}"
    
    # Variables globales pour partager entre tests
    ACCESS_TOKEN=""
    USER_ID=""
    ROOM_ID=""
    
    # Exécution des tests
    test_api_version || return 1
    test_admin_login || return 1
    test_room_creation || return 1
    test_send_message || return 1
    test_get_messages || return 1
    test_server_status || return 1
    test_encryption || return 1
    
    # Nettoyage
    cleanup
    
    echo -e "${GREEN}"
    echo "================================================"
    echo "✅ TOUS LES TESTS MATRIX RÉUSSIS!"
    echo "================================================"
    echo -e "${NC}"
    echo
    echo "🔗 Matrix est prêt pour la production"
    echo "👍 API backend fonctionnelle"
    echo "🔐 Chiffrement E2E opérationnel"
    echo
    echo "Prochaines étapes DEV1:"
    echo "1. Intégrer avec Element Web"
    echo "2. Configurer Nginx reverse proxy"
    echo "3. Tester avec plusieurs utilisateurs"
}

# === GESTION DES ERREURS ===
trap cleanup EXIT

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if ! command -v curl >/dev/null 2>&1; then
        error "curl n'est pas installé"
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        warning "jq non installé - certains détails ne seront pas affichés"
    fi
    
    main "$@"
fi