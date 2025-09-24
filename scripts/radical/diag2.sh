#!/bin/bash
# Reset PostgreSQL complet pour résoudre l'authentification - Mission D.I.P.

set -e

echo "🚨 RESET POSTGRESQL COMPLET - MISSION D.I.P."
echo "============================================="
echo "⚠️  Ceci va SUPPRIMER toutes les données PostgreSQL"
echo "⚠️  Matrix sera reconfiguré from scratch"
echo ""

read -p "Continuer ? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "❌ Annulé"
    exit 1
fi

# Chargement variables
source .env
echo "✅ Variables chargées"
echo "Password PostgreSQL: ${POSTGRES_PASSWORD:0:8}***"

echo ""
echo "🛑 ÉTAPE 1: ARRÊT TOTAL"
echo "======================"
docker-compose stop matrix-synapse postgres
docker rm -f dip-matrix dip-postgres 2>/dev/null || echo "Conteneurs déjà supprimés"

echo ""
echo "🗑️  ÉTAPE 2: SUPPRESSION DONNÉES"
echo "==============================="
# Suppression données PostgreSQL
rm -rf data/postgres
echo "✅ Données PostgreSQL supprimées"

# Suppression config Matrix (gardons seulement les certificats)
rm -rf data/matrix/homeserver.yaml data/matrix/*.key data/matrix/*.log* data/matrix/media_store 2>/dev/null || echo "Config Matrix déjà nettoyée"
echo "✅ Configuration Matrix nettoyée"

echo ""
echo "🚀 ÉTAPE 3: RECRÉATION POSTGRESQL"
echo "================================"
# Recréation PostgreSQL avec le bon mot de passe
docker-compose up -d postgres

echo "⏳ Attente PostgreSQL (20s)..."
sleep 20

# Test PostgreSQL
if docker exec dip-postgres pg_isready -U synapse >/dev/null 2>&1; then
    echo "✅ PostgreSQL opérationnel"
else
    echo "❌ PostgreSQL en échec"
    docker-compose logs postgres
    exit 1
fi

# Test connexion avec les bonnes credentials
echo "🧪 Test connexion base de données..."
if docker exec dip-postgres psql -U synapse -d synapse -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Connexion PostgreSQL OK avec password du .env"
else
    echo "❌ Connexion PostgreSQL encore en échec"
    echo "📋 Debug PostgreSQL:"
    docker exec dip-postgres psql -U postgres -c "\du" 2>/dev/null || echo "Erreur accès PostgreSQL"
    exit 1
fi

echo ""
echo "🔧 ÉTAPE 4: CONFIGURATION MATRIX PROPRE"
echo "======================================"

# Génération configuration Matrix complètement neuve
mkdir -p data/matrix
cat > data/matrix/homeserver.yaml << EOF
# Configuration Matrix Synapse pour Mission D.I.P. - RESET COMPLET
server_name: "${MATRIX_SERVER_NAME:-dip.local}"
pid_file: /data/homeserver.pid
report_stats: false
web_client_location: https://${MATRIX_SERVER_NAME:-dip.local}/element/

# Écoute HTTP
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

# Base de données - AVEC MOT DE PASSE DIRECT
database:
  name: psycopg2
  args:
    user: synapse
    password: "${POSTGRES_PASSWORD}"
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

# Logging simple
log_config: "/data/log.config"

# Médias
media_store_path: /data/media_store
uploads_path: /data/uploads
max_upload_size: 50M
max_image_pixels: 32M

# Utilisateurs
enable_registration: false
registration_shared_secret: "${REGISTRATION_SECRET}"
allow_guest_access: false

# Sécurité (pas de fédération)
send_federation: false
federation_domain_whitelist: []
trusted_key_servers: []

# Clés de signature
signing_key_path: "/data/homeserver.signing.key"

# Limites adaptées intranet
rc_message:
  per_second: 10
  burst_count: 100

rc_login:
  address:
    per_second: 1
    burst_count: 5
  account:
    per_second: 1
    burst_count: 5

# Chiffrement E2E par défaut
encryption_enabled_by_default_for_room_type: all

# Métriques
enable_metrics: true
suppress_key_server_warning: true
EOF

# Configuration logging
cat > data/matrix/log.config << 'EOF'
version: 1

formatters:
    precise:
        format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(message)s'

handlers:
    console:
        class: logging.StreamHandler
        formatter: precise

loggers:
    synapse:
        level: INFO
    
    synapse.storage.SQL:
        level: WARNING

root:
    level: INFO
    handlers: [console]
EOF

# Permissions
chmod 644 data/matrix/homeserver.yaml data/matrix/log.config
chown -R 991:991 data/matrix/ 2>/dev/null || echo "Permissions ajustées (pas root)"

echo "✅ Configuration Matrix créée avec password en dur"

echo ""
echo "🚀 ÉTAPE 5: DÉMARRAGE MATRIX"
echo "=========================="

# Génération des clés Matrix
echo "🔑 Génération clés Matrix..."
docker run --rm \
    -v "$(pwd)/data/matrix:/data" \
    -e SYNAPSE_SERVER_NAME=${MATRIX_SERVER_NAME:-dip.local} \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate || echo "Clés déjà présentes"

# Copie de notre config par-dessus
cp data/matrix/homeserver.yaml data/matrix/homeserver.yaml.backup
cat > data/matrix/homeserver.yaml << EOF
# Configuration Matrix finale - avec password interpolé
server_name: "${MATRIX_SERVER_NAME:-dip.local}"
pid_file: /data/homeserver.pid
report_stats: false

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

database:
  name: psycopg2
  args:
    user: synapse
    password: "${POSTGRES_PASSWORD}"
    database: synapse
    host: postgres
    port: 5432
    cp_min: 5
    cp_max: 10

log_config: "/data/log.config"
media_store_path: /data/media_store
uploads_path: /data/uploads
max_upload_size: 50M

enable_registration: false
registration_shared_secret: "${REGISTRATION_SECRET}"
send_federation: false
trusted_key_servers: []
signing_key_path: "/data/homeserver.signing.key"

rc_message:
  per_second: 10
  burst_count: 100

encryption_enabled_by_default_for_room_type: all
enable_metrics: true
EOF

# Démarrage Matrix
echo "🚀 Démarrage Matrix..."
docker-compose up -d matrix-synapse

echo ""
echo "⏳ ÉTAPE 6: TESTS PROGRESSIFS"
echo "============================"

# Tests de démarrage
echo "Tests de démarrage Matrix..."
for i in {1..20}; do
    echo "   Test $i/20..."
    
    # Vérifier que le conteneur tourne
    if ! docker ps --filter "name=dip-matrix" --format "{{.Status}}" | grep -q "Up"; then
        echo "   ❌ Conteneur Matrix stoppé"
        echo "   📋 Logs Matrix:"
        docker logs dip-matrix | tail -10
        break
    fi
    
    # Test API
    if curl -s --connect-timeout 3 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
        echo "   ✅ Matrix API répond !"
        MATRIX_SUCCESS=true
        break
    fi
    
    # Voir les logs toutes les 5 tentatives
    if [ $((i % 5)) -eq 0 ]; then
        echo "   📋 Logs Matrix (dernières lignes):"
        docker logs dip-matrix | tail -3
    fi
    
    sleep 3
done

echo ""
echo "🎯 RÉSULTAT FINAL"
echo "================"

if [ "$MATRIX_SUCCESS" = true ]; then
    echo "🎉 MATRIX FONCTIONNE ENFIN !"
    echo ""
    echo "✅ PostgreSQL: Recréé avec bon password"
    echo "✅ Matrix: Configuration en dur (pas de variables)"
    echo "✅ API: http://localhost:8008 accessible"
    echo ""
    echo "👤 CRÉATION ADMIN:"
    echo "docker exec -it dip-matrix register_new_matrix_user -c /data/homeserver.yaml --user admin --password '${MATRIX_ADMIN_PASSWORD}' --admin http://localhost:8008"
    echo ""
    echo "🔗 NEXT STEPS:"
    echo "1. Créer l'admin (commande ci-dessus)"
    echo "2. Démarrer Element: docker-compose up -d element"
    echo "3. Configurer nginx: docker-compose up -d nginx"
else
    echo "❌ MATRIX NE DÉMARRE TOUJOURS PAS"
    echo ""
    echo "📊 État final:"
    docker-compose ps
    echo ""
    echo "📋 Logs Matrix complets:"
    docker logs dip-matrix
    echo ""
    echo "🆘 DEBUG MANUEL:"
    echo "docker exec -it dip-matrix /bin/bash"
    echo "docker exec -it dip-postgres psql -U synapse -d synapse"
fi

echo ""
echo "💾 DONNÉES:"
echo "==========="
echo "PostgreSQL: data/postgres/ (recréé)"
echo "Matrix: data/matrix/ (config neuve)"
echo "Backup config: data/matrix/homeserver.yaml.backup"