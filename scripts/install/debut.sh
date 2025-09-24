#!/bin/bash
set -e

echo "🚀 Déploiement de Mission D.I.P..."

# 1. Lancer les services
docker compose up -d

# 2. Attendre que Synapse soit prêt
echo "⏳ Attente que Matrix Synapse soit prêt..."
until docker exec dip-matrix curl -s http://localhost:8008/_matrix/client/versions > /dev/null 2>&1; do
  echo "   ➜ Synapse pas encore prêt, nouvelle tentative dans 5s..."
  sleep 5
done
echo "✅ Synapse est prêt !"

# 3. Créer un compte admin si nécessaire
echo "👤 Création du compte admin de test..."
docker exec dip-matrix register_new_matrix_user \
  -u admin \
  -p AdminPass123 \
  -a \
  -c /data/homeserver.yaml \
  http://localhost:8008 || true

echo "⚠️ Compte admin :"
echo "   ➜ Identifiant : admin"
echo "   ➜ Mot de passe : AdminPass123"
echo "   ➜ Pense à le changer immédiatement !"

echo "🎉 Déploiement terminé."
