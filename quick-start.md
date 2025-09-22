# 🚀 Guide de Démarrage Ultra-Rapide

## ⚡ Installation Express (5 minutes)

```bash
# 1. Cloner et entrer dans le projet
git clone /chemin/vers/intranet-dip
cd intranet-dip

# 2. Copier et configurer les variables
cp .env.example .env
# Éditez .env avec vos mots de passe !

# 3. Générer les certificats SSL
./security/ssl/generate-certs.sh

# 4. Démarrer tous les services
docker-compose up -d

# 5. Attendre que tout démarre (2-3 minutes)
docker-compose logs -f

# 6. Créer le premier utilisateur admin
./scripts/install/04-post-install.sh
```

## 🎯 Accès aux Services

| Service | URL | Description |
|---------|-----|-------------|
| 🏠 Accueil | https://localhost | Page d'accueil |
| 💬 Matrix | https://localhost/element | Messagerie |
| 📚 Wiki | https://localhost/wiki | Documentation |
| 🗣️ Forum | https://localhost/forum | Discussions |

## 🆘 Dépannage Express

```bash
# Voir les logs de tous les services
docker-compose logs

# Redémarrer un service spécifique
docker-compose restart matrix-synapse

# Vérifier l'état des services
docker-compose ps

# Arrêter tout
docker-compose down

# Tout supprimer et recommencer
docker-compose down -v
```

## 📞 Support

- 📖 Documentation complète: `docs/`
- 🐛 Problèmes: Voir `docs/admin/troubleshooting.md`
- 💡 Idées d'amélioration: Forum interne une fois déployé
