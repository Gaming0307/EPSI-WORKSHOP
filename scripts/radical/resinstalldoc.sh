#!/bin/bash
# Redémarrage propre après nettoyage radical

set -e

echo "🚀 REDÉMARRAGE PROPRE - MISSION D.I.P."
echo "======================================"

# Vérification environnement
if [ ! -f ".env" ]; then
    echo "❌ Fichier .env manquant !"
    exit 1
fi

source .env
echo "✅ Variables d'environnement chargées"

# Recréation des dossiers
echo "📁 Recréation de la structure..."
mkdir -p data/{matrix,postgres,postgres2,wiki} security/ssl
chmod -R 755 data/
echo "✅ Structure créée"

# Test PostgreSQL SEUL d'abord
echo ""
echo "🔍 TEST 1: PostgreSQL seul"
echo "=========================="
docker-compose up -d postgres
echo "⏳ Attente PostgreSQL (15s)..."
sleep 15

if docker exec dip-postgres pg_isready -U synapse 2>/dev/null; then
    echo "✅ PostgreSQL fonctionne"
    docker-compose logs postgres | tail -5
else
    echo "❌ PostgreSQL en échec"
    docker-compose logs postgres
    echo ""
    echo "🔧 SOLUTION: Vérifier POSTGRES_PASSWORD dans .env"
    exit 1
fi

echo ""
echo "🔍 TEST 2: Matrix Synapse seul"
echo "=============================="

# Génération config Matrix si nécessaire
if [ ! -f "data/matrix/homeserver.yaml" ]; then
    echo "🔧 Génération configuration Matrix..."
    docker run --rm \
        -v "$(pwd)/data/matrix:/data" \
        -e SYNAPSE_SERVER_NAME=${MATRIX_SERVER_NAME:-dip.local} \
        matrixdotorg/synapse:latest generate
    echo "✅ Configuration générée"
fi

# Test Matrix
docker-compose up -d matrix-synapse
echo "⏳ Attente Matrix (20s)..."
sleep 20

# Vérification Matrix
if curl -s -f http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
    echo "✅ Matrix Synapse fonctionne"
else
    echo "❌ Matrix Synapse en échec"
    echo ""
    echo "📋 LOGS MATRIX:"
    docker-compose logs matrix-synapse | tail -20
    echo ""
    echo "🔧 SOLUTIONS POSSIBLES:"
    echo "1. Problème de configuration homeserver.yaml"
    echo "2. Problème de connexion base de données"
    echo "3. Problème de permissions sur data/matrix"
    echo ""
    echo "🧪 DIAGNOSTIC:"
    echo "docker exec -it dip-matrix ls -la /data"
    echo "docker exec -it dip-postgres psql -U synapse -d synapse -c '\\dt'"
    exit 1
fi

echo ""
echo "🔍 TEST 3: Services complets"
echo "============================"

# Démarrage de tout
docker-compose up -d

echo "⏳ Attente services complets (30s)..."
sleep 30

# Vérification finale
echo ""
echo "📊 ÉTAT FINAL:"
docker-compose ps

echo ""
echo "🧪 TESTS DE CONNECTIVITÉ:"

# Test Matrix
if curl -s -f http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
    echo "✅ Matrix API: http://localhost:8008"
else
    echo "❌ Matrix API inaccessible"
fi

# Test Wiki
if curl -s -f http://localhost:3003 >/dev/null 2>&1; then
    echo "✅ Wiki.js: http://localhost:3003"
else
    echo "⚠️  Wiki.js pas encore prêt (normal)"
fi

# Test bases de données
if docker exec dip-postgres pg_isready -U synapse >/dev/null 2>&1; then
    echo "✅ PostgreSQL Matrix OK"
else
    echo "❌ PostgreSQL Matrix KO"
fi

if docker exec dip-postgres2 pg_isready -U wiki >/dev/null 2>&1; then
    echo "✅ PostgreSQL Wiki OK"
else
    echo "❌ PostgreSQL Wiki KO"
fi

echo ""
echo "🎉 REDÉMARRAGE TERMINÉ !"
echo "======================="
echo ""
echo "🔗 Accès directs:"
echo "   • Matrix API: http://localhost:8008"
echo "   • Wiki.js: http://localhost:3003"
echo ""
echo "📝 Prochaines étapes:"
echo "1. Créer utilisateur admin Matrix"
echo "2. Configurer Element Web"
echo "3. Configurer Nginx reverse proxy"
echo ""
echo "🆘 En cas de problème:"
echo "   • Logs: docker-compose logs [service]"
echo "   • État: docker-compose ps"
echo "   • Restart: docker-compose restart [service]"