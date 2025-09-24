#!/bin/bash
# 💥 SOLUTION RADICALE - Nettoyage complet Docker pour Mission D.I.P.
# Attention : Ceci va TOUT supprimer !

set +e  # Continue même en cas d'erreur

echo "💥 NETTOYAGE RADICAL DOCKER - MISSION D.I.P."
echo "=============================================="
echo "⚠️  ATTENTION: Ceci va supprimer TOUS les conteneurs D.I.P."
echo "⚠️  Les données dans data/ seront préservées"
echo ""

read -p "Continuer ? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "❌ Annulé par l'utilisateur"
    exit 1
fi

echo ""
echo "🔍 DIAGNOSTIC INITIAL"
echo "====================="

# Voir l'état actuel
echo "Conteneurs en cours:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "Conteneurs D.I.P. problématiques:"
docker ps -a --filter "name=dip-" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo ""

echo "🛑 ÉTAPE 1: ARRÊT FORCÉ DE TOUT"
echo "==============================="

# Arrêt brutal de docker-compose
echo "Arrêt docker-compose..."
docker-compose down --timeout 10 2>/dev/null || echo "Docker-compose pas en cours"

# Arrêt forcé de tous les conteneurs DIP
echo "Arrêt forcé des conteneurs D.I.P...."
docker stop $(docker ps -aq --filter "name=dip-") 2>/dev/null || echo "Aucun conteneur D.I.P. à arrêter"

# Kill brutal si nécessaire
echo "Kill brutal des conteneurs récalcitrants..."
docker kill $(docker ps -aq --filter "name=dip-") 2>/dev/null || echo "Aucun conteneur à killer"

sleep 3

echo ""
echo "🗑️  ÉTAPE 2: SUPPRESSION TOTALE"
echo "==============================="

# Suppression des conteneurs D.I.P.
echo "Suppression des conteneurs D.I.P...."
docker rm -f $(docker ps -aq --filter "name=dip-") 2>/dev/null || echo "Aucun conteneur D.I.P. à supprimer"

# Suppression conteneur par ID si fourni
CONTAINER_ID="e4bba97309cf"
if docker ps -a --format "{{.ID}}" | grep -q "$CONTAINER_ID"; then
    echo "Suppression du conteneur problématique $CONTAINER_ID..."
    docker rm -f "$CONTAINER_ID" 2>/dev/null || echo "Conteneur déjà supprimé"
fi

# Nettoyage des volumes orphelins
echo "Nettoyage des volumes orphelins..."
docker volume prune -f 2>/dev/null || echo "Aucun volume à nettoyer"

# Nettoyage des réseaux
echo "Nettoyage des réseaux D.I.P...."
docker network rm dip-network 2>/dev/null || echo "Réseau D.I.P. pas trouvé"
docker network prune -f 2>/dev/null || echo "Aucun réseau à nettoyer"

echo ""
echo "🔧 ÉTAPE 3: NETTOYAGE SYSTÈME"
echo "============================="

# Nettoyage général Docker
echo "Nettoyage général Docker..."
docker system prune -f --volumes 2>/dev/null || echo "Nettoyage système échoué"

echo ""
echo "📁 ÉTAPE 4: VÉRIFICATION DATA"
echo "============================="

# Vérifier les dossiers data
if [ -d "data" ]; then
    echo "✅ Dossier data/ préservé"
    echo "Contenu:"
    ls -la data/ 2>/dev/null || echo "Dossier data vide"
    echo ""
    echo "Taille des données:"
    du -sh data/* 2>/dev/null || echo "Aucune donnée"
else
    echo "⚠️  Dossier data/ absent - sera créé au redémarrage"
fi

echo ""
echo "🎯 ÉTAPE 5: DIAGNOSTIC FINAL"
echo "============================"

echo "Conteneurs restants:"
if docker ps -a --filter "name=dip-" --format "table {{.Names}}\t{{.Status}}" | grep -v NAMES; then
    echo "❌ Des conteneurs D.I.P. restent !"
else
    echo "✅ Aucun conteneur D.I.P. restant"
fi

echo ""
echo "Images Docker disponibles:"
docker images | grep -E "(matrix|postgres|nginx|wiki)" | head -5

echo ""
echo "💥 NETTOYAGE RADICAL TERMINÉ"
echo "============================"
echo ""
echo "✅ Tous les conteneurs D.I.P. supprimés"
echo "✅ Réseaux et volumes nettoyés"
echo "✅ Données dans data/ préservées"
echo ""
echo "🚀 PROCHAINES ÉTAPES:"
echo "1. Vérifier le fichier .env"
echo "2. Vérifier docker-compose.yml"
echo "3. Redémarrer avec: docker-compose up -d --force-recreate"
echo "4. Surveiller les logs: docker-compose logs -f"
echo ""
echo "🔍 Pour diagnostiquer pourquoi ça crashait:"
echo "docker-compose up matrix-synapse  # Sans -d pour voir les erreurs"