#!/usr/bin/env bash
set -euo pipefail

# Variables (modifiables via .env)
ADMIN_USER=${ADMIN_USER:-admin}
ADMIN_PASS=${ADMIN_PASS:-AdminPass123}
MATRIX_CONTAINER=${MATRIX_CONTAINER:-dip-matrix}

echo "🚀 Déploiement de Mission D.I.P..."

# 1. Lancer tous les services
docker compose up -d --remove-orphans

# 2. Attendre que Synapse soit prêt
echo "⏳ Attente du démarrage de Synapse..."
MAX_RETRIES=30
SLEEP_INTERVAL=5
i=0
until docker exec "$MATRIX_CONTAINER" curl -sf http://localhost:8008/_matrix/client/versions > /dev/null 2>&1; do
  i=$((i+1))
  if [ $i -ge $MAX_RETRIES ]; then
    echo "❌ Erreur : Synapse n’a pas démarré dans le temps imparti."
    exit 1
  fi
  echo "   → tentative $i/$MAX_RETRIES…"
  sleep $SLEEP_INTERVAL
done
echo "✅ Synapse est prêt !"

# 3. Création de l’admin (si pas déjà présent)
echo "👤 Création de l’utilisateur admin '${ADMIN_USER}'..."
docker exec "$MATRIX_CONTAINER" register_new_matrix_user \
  -u "${ADMIN_USER}" \
  -p "${ADMIN_PASS}" \
  -a \
  -c /data/homeserver.yaml \
  http://localhost:8008 || true

echo "⚠️ Compte admin :"
echo "   ➜ Identifiant : ${ADMIN_USER}"
echo "   ➜ Mot de passe : ${ADMIN_PASS}"
echo "   ➜ Change-le immédiatement après le premier login."

echo "🎉 Déploiement terminé."
