#!/bin/bash
# Diagnostic Matrix pour Mission D.I.P.

echo "🔍 DIAGNOSTIC MATRIX - MISSION D.I.P."
echo "===================================="

# === ÉTAT DES CONTENEURS ===
echo ""
echo "📊 ÉTAT DES CONTENEURS:"
echo "======================"
docker-compose ps
echo ""

# === TEST CONNEXION DIRECTE ===
echo "🌐 TEST CONNEXION MATRIX:"
echo "========================"
if curl -s --connect-timeout 5 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
    echo "✅ Matrix API accessible"
    curl -s http://localhost:8008/_matrix/client/versions | head -3
else
    echo "❌ Matrix API inaccessible"
    echo "   Port 8008 fermé ou service non démarré"
fi
echo ""

# === LOGS MATRIX (20 dernières lignes) ===
echo "📋 LOGS MATRIX (20 dernières lignes):"
echo "===================================="
docker-compose logs --tail=20 matrix-synapse
echo ""

# === PROCESSUS DANS MATRIX ===
echo "⚙️  PROCESSUS DANS LE CONTENEUR MATRIX:"
echo "======================================"
if docker exec dip-matrix ps aux 2>/dev/null; then
    echo "✅ Conteneur accessible"
else
    echo "❌ Impossible d'accéder au conteneur Matrix"
fi
echo ""

# === TEST BASE DE DONNÉES ===
echo "🗄️  TEST BASE DE DONNÉES:"
echo "======================="
if docker exec dip-postgres pg_isready -U synapse 2>/dev/null; then
    echo "✅ PostgreSQL accessible"
    echo "   Connexion DB OK"
else
    echo "❌ PostgreSQL inaccessible"
    echo "   Problème de connexion DB"
fi
echo ""

# === FICHIERS CONFIGURATION ===
echo "📄 FICHIERS CONFIGURATION:"
echo "=========================="
if docker exec dip-matrix ls -la /data/ 2>/dev/null; then
    echo ""
    echo "Config homeserver:"
    docker exec dip-matrix head -10 /data/homeserver.yaml 2>/dev/null || echo "❌ homeserver.yaml inaccessible"
else
    echo "❌ Impossible d'accéder aux fichiers de configuration"
fi
echo ""

# === PORTS UTILISÉS ===
echo "🚪 PORTS UTILISÉS:"
echo "================="
echo "Ports Docker:"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "(dip-|PORTS)"
echo ""
echo "Ports système (8008):"
netstat -tlnp 2>/dev/null | grep :8008 || ss -tlnp 2>/dev/null | grep :8008 || echo "Port 8008 libre"
echo ""

# === ESPACE DISQUE ===
echo "💾 ESPACE DISQUE:"
echo "================"
echo "Dossier data/:"
du -sh data/* 2>/dev/null || echo "Dossier data vide"
echo ""
echo "Espace libre:"
df -h . | tail -1
echo ""

# === DIAGNOSTIC FINAL ===
echo "🎯 DIAGNOSTIC FINAL:"
echo "=================="

# Vérifier si Matrix démarre
if docker-compose logs matrix-synapse 2>/dev/null | grep -q "Synapse now listening on"; then
    echo "✅ Matrix a démarré au moins une fois"
else
    echo "❌ Matrix n'a jamais démarré correctement"
fi

# Vérifier les erreurs communes
if docker-compose logs matrix-synapse 2>/dev/null | grep -qi "error"; then
    echo "❌ Erreurs détectées dans les logs"
    echo "   Principales erreurs:"
    docker-compose logs matrix-synapse 2>/dev/null | grep -i error | tail -3
else
    echo "✅ Aucune erreur évidente dans les logs"
fi

echo ""
echo "🔧 SOLUTIONS RECOMMANDÉES:"
echo "========================"

# Analyser le problème probable
if ! curl -s --connect-timeout 2 http://localhost:8008/_matrix/client/versions >/dev/null 2>&1; then
    if docker-compose ps matrix-synapse | grep -q "Up"; then
        echo "1. 🟡 Conteneur UP mais service DOWN"
        echo "   → Problème de configuration Matrix"
        echo "   → Solution: Vérifier homeserver.yaml"
        echo "   → Commande: docker-compose restart matrix-synapse"
    else
        echo "1. 🔴 Conteneur DOWN"
        echo "   → Crash au démarrage"
        echo "   → Solution: Analyser les logs complètes"
        echo "   → Commande: docker-compose logs matrix-synapse"
    fi
else
    echo "1. ✅ Matrix fonctionne maintenant !"
fi

echo ""
echo "📝 COMMANDES DE DEBUG:"
echo "====================="
echo "• Logs complets Matrix: docker-compose logs matrix-synapse"
echo "• Redémarrer Matrix: docker-compose restart matrix-synapse"
echo "• Shell Matrix: docker exec -it dip-matrix /bin/bash"
echo "• Test DB: docker exec dip-postgres psql -U synapse -d synapse -c 'SELECT 1;'"
echo "• Recréer Matrix: docker-compose up --force-recreate -d matrix-synapse"