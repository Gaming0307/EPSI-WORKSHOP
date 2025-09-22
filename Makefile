# 🛡️ Makefile Intranet D.I.P.

.PHONY: help start stop restart logs status clean setup test backup

# 📋 Aide par défaut
help:
	@echo "🛡️  Intranet D.I.P. - Commandes disponibles:"
	@echo ""
	@echo "  🚀 start      - Démarrer tous les services"
	@echo "  ⏹️  stop       - Arrêter tous les services" 
	@echo "  🔄 restart    - Redémarrer tous les services"
	@echo "  📊 logs       - Voir les logs en temps réel"
	@echo "  ✅ status     - État des services"
	@echo "  🧹 clean      - Nettoyer les données (ATTENTION!)"
	@echo "  🔧 setup      - Configuration initiale"
	@echo "  🧪 test       - Lancer les tests"
	@echo "  💾 backup     - Créer une sauvegarde"

# 🚀 Démarrer les services
start:
	@echo "🚀 Démarrage des services D.I.P..."
	docker-compose up -d
	@echo "✅ Services démarrés!"
	@echo "🌐 Accès: https://localhost"

# ⏹️ Arrêter les services
stop:
	@echo "⏹️ Arrêt des services..."
	docker-compose down

# 🔄 Redémarrer
restart: stop start

# 📊 Logs en temps réel
logs:
	docker-compose logs -f

# ✅ État des services
status:
	docker-compose ps

# 🧹 Nettoyage complet (ATTENTION!)
clean:
	@echo "⚠️  ATTENTION: Cela va supprimer TOUTES les données!"
	@read -p "Êtes-vous sûr? (oui/non): " confirm && [ "$$confirm" = "oui" ]
	docker-compose down -v
	sudo rm -rf data/
	@echo "🧹 Nettoyage terminé"

# 🔧 Configuration initiale
setup:
	@echo "🔧 Configuration initiale..."
	./scripts/install/01-system-setup.sh
	cp .env.example .env
	@echo "✅ Veuillez éditer le fichier .env avant de démarrer!"

# 🧪 Tests
test:
	@echo "🧪 Lancement des tests..."
	./scripts/testing/test-connectivity.sh
	./scripts/testing/test-encryption.sh

# 💾 Sauvegarde
backup:
	@echo "💾 Création sauvegarde..."
	./backups/scripts/backup.sh
