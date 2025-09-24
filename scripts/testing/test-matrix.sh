#!/bin/bash
# Tests Matrix - Mission D.I.P.

echo "🧪 === TESTS MATRIX SYNAPSE ==="

# Test 1: API disponible
echo "Test 1: API Matrix disponible"
if curl -f http://localhost:8008/_matrix/client/versions > /dev/null 2>&1; then
    echo "✅ API Matrix OK"
else
    echo "❌ API Matrix indisponible"
    exit 1
fi

# Test 2: Element Web accessible
echo "Test 2: Element Web accessible"
if curl -f http://localhost:8080 > /dev/null 2>&1; then
    echo "✅ Element Web OK"
else
    echo "❌ Element Web indisponible"
    exit 1
fi

# Test 3: Base de données connectée
echo "Test 3: Connexion base de données"
if docker exec dip-postgres pg_isready -U synapse_user > /dev/null 2>&1; then
    echo "✅ PostgreSQL OK"
else
    echo "❌ Problème PostgreSQL"
    exit 1
fi

# Test 4: Certificats TLS
echo "Test 4: Certificats TLS"
if [ -f "./security/ssl/matrix.crt" ]; then
    echo "✅ Certificats présents"
else
    echo "⚠️  Certificats TLS à générer"
fi

echo ""
echo "🎯 Résumé des tests Matrix:"
echo "   - API fonctionnelle"
echo "   - Interface Element accessible"  
echo "   - Base de données opérationnelle"
echo ""
echo "📝 Prochaine étape: Créer des utilisateurs de test"