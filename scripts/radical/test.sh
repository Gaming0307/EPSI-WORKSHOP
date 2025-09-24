#!/bin/bash
# Correction password Matrix - Mission D.I.P.

set -e

echo "🔧 CORRECTION PASSWORD MATRIX - MISSION D.I.P."
echo "=============================================="

# Chargement variables
source .env
echo "✅ Password PostgreSQL: ${POSTGRES_PASSWORD:0:8}***"

echo ""
echo "🔍 DIAGNOSTIC:"
echo "=============="

# Test PostgreSQL direct
echo "Test connexion PostgreSQL avec password du .env:"
if docker exec dip-postgres psql -U synapse -d synapse -c "SELECT version();" 2>/dev/null | head -3; then
    echo "✅ PostgreSQL accessible avec ce password"
else
    echo "❌ PostgreSQL inaccessible - Problème plus profond"
    exit 1
fi

echo ""
echo "🔧 CORRECTION HOMESERVER.YAML:"
echo "=============================="

# Sauvegarde
cp data/matrix/homeserver.yaml data/matrix/homeserver.yaml.bak
echo "✅ Sauvegarde créée: homeserver.yaml.bak"

# Création config avec password EN DUR
cat > data/matrix/homeserver.yaml << EOF
# Configuration Matrix Synapse - Mission D.I.P.
# PASSWORD EN DUR (pas de variables)

server_name: "dip.local"
pid_file: /data/homeserver.pid
report_stats: false

# Listeners
listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses: ['0.0.0.0']
    resources:
      - names: [client, federation]
        compress: false

# Database avec PASSWORD EN DUR
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

# Logging
log_config: "/data/log.config"

# Media
media_store_path: /data/media_store
uploads_path: /data/uploads
max_upload_size: 50M

# Security
enable_registration: false
registration_shared_secret: "${REGISTRATION_SECRET}"
send_federation: false
trusted_key_servers: []

# Signing
signing_key_path: "/data/homeserver.signing.key"

# Rate limiting
rc_message:
  per_second: 10
  burst_count: 100

rc_login:
  address:
    per_second: 1
    burst_count: 5

# Encryption
encryption_enabled_by_default_for_room_type: all
enable_metrics: true
suppress_key_server_warning: true
EOF

echo "✅ Configuration créée avec password en dur"

# Permissions
chmod 644 data/matrix/homeserver.yaml
chown -R 991:991 data/matrix/ 2>/dev/null || echo "Permissions ajustées"

echo ""
echo "🚀 REDÉMARRAGE MATRIX:"
echo "===================="

# Arrêt Matrix
docker-compose stop matrix-synapse

# Suppression ancien conteneur
docker rm -f dip-matrix 2>/dev/null || echo "Conteneur déjà supprimé"

# Redémarrage Matrix
docker-compose up -d matrix-synapse

echo "⏳ Test Matrix (30 secondes)..."
sleep 5

# Tests progressifs
for i in {1..10}; do
    echo "Test $i/10..."
    
    if curl -s --connect-timeout 3 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
        echo "🎉 MATRIX FONCTIONNE ENFIN !"
        echo ""
        echo "✅ Password corrigé dans homeserver.yaml"
        echo "✅ API Matrix accessible: http://localhost:8008"
        echo ""
        echo "👤 Créer utilisateur admin:"
        echo "docker exec -it dip-matrix register_new_matrix_user -c /data/homeserver.yaml --user admin --password '${MATRIX_ADMIN_PASSWORD}' --admin http://localhost:8008"
        echo ""
        echo "📋 Vérification:"
        echo "curl http://localhost:8008/_matrix/client/versions"
        exit 0
    fi
    
    if [ $i -eq 5 ]; then
        echo "📋 Logs Matrix à mi-parcours:"
        docker logs dip-matrix 2>/dev/null | tail -5
    fi
    
    sleep 3
done

echo ""
echo "❌ MATRIX NE RÉPOND TOUJOURS PAS"
echo ""
echo "📋 Logs Matrix complets:"
docker logs dip-matrix 2>/dev/null | tail -20

echo ""
echo "🔍 DIAGNOSTIC FINAL:"
echo "=================="
echo "• PostgreSQL: $(docker exec dip-postgres pg_isready -U synapse 2>/dev/null && echo 'UP' || echo 'DOWN')"
echo "• Matrix container: $(docker ps --filter 'name=dip-matrix' --format '{{.Status}}' | head -1)"
echo ""
echo "🆘 DEBUG MANUEL:"
echo "1. docker logs dip-matrix"
echo "2. docker exec -it dip-matrix cat /data/homeserver.yaml | grep password"
echo "3. docker exec -it dip-postgres psql -U synapse -d synapse -c 'SELECT 1;'"