Équipe : 2 développeurs (Dev1, Dev2) + 2 ingénieurs IT (IT1, IT2)

Objectif

Déployer en 4 jours un intranet autonome, chiffré, open source, comprenant :

Messagerie sécurisée (Matrix Synapse + Element)

Wiki collaboratif (Wiki.js)

Forum/annonces (Discourse)

Accessible par navigateur depuis un réseau local fermé.

Répartition des rôles
Rôle	Missions clés
Dev1	Déploiement & configuration des applis (Docker Compose, tests API).
Dev2	Intégration front minimal (branding, config UI), doc utilisateur.
IT1	Installation OS, réseau local (Wi-Fi/Ethernet isolé), sécurité (pare-feu, TLS).
IT2	Sauvegardes, monitoring basique, doc technique & scripts automatisés.
Architecture rapide

Serveur : Debian/Ubuntu minimal.

Conteneurs : Docker + Docker Compose.

Sécurité : TLS auto-signé, pare-feu UFW, chiffrement disque (optionnel selon temps).

Accès : Wi-Fi dédié ou VLAN.

Planning collaboratif (24 h 30)
Jour 1 – 6 h

IT1 & IT2 (3 h chacun)

Installation Debian/Ubuntu, MAJ système.

Configuration réseau intranet (DHCP/point d’accès).

Mise en place SSH, pare-feu UFW.

Dev1 & Dev2 (en parallèle, 3 h chacun)

Préparer docker-compose.yml pour Matrix, Wiki.js, Discourse.

Créer dépôt Git interne (scripts, doc).

Jour 2 – 6 h

IT1/IT2 : Génération certificats TLS, test réseau.

Dev1 : Déploiement Matrix Synapse + Element, premier test E2E.

Dev2 : Interface de login simple, préparation doc utilisateur (messagerie).

Jour 3 – 6 h

IT1 : Sauvegarde basique (rsync, snapshot disque).

Dev1 : Déploiement Wiki.js + Postgres.

Dev2 : Déploiement Discourse, configuration catégories.

IT2 : Monitoring basique (logs, alertes).

Jour 4 – 6 h 30

Équipe complète :

Tests de charge (5–10 connexions simultanées).

Vérification chiffrement E2E et permissions.

Rédaction finale : guide admin & guide utilisateur.

Démonstration interne.

Livrables

Serveur prêt avec messagerie, wiki, forum.

Documentation

Guide admin (installation, sauvegarde).

Guide utilisateur (connexion, messagerie, wiki, forum).

Scripts d’installation : fichier docker-compose.yml unique + script réseau.

Indicateurs de succès

Services accessibles depuis tout poste du réseau local via HTTPS.

Messagerie chiffrée fonctionnelle entre au moins 4 utilisateurs.

Wiki & forum supportant ≥20 connexions simultanées.

Conseils pour maximiser le temps

Téléchargez à l’avance les images Docker pour éviter la dépendance Internet.

Automatisez (bash/Ansible) dès le Jour 1.

Réunions flash (15 min) au début et fin de chaque jour pour synchroniser.