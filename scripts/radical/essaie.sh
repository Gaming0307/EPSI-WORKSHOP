# 1. Vérifier le mot de passe dans .env
grep POSTGRES_PASSWORD .env

# 2. Tester si PostgreSQL fonctionne avec ce mot de passe
docker exec dip-postgres psql -U synapse -d synapse -c "SELECT 1;"

# 3. Si ça échoue, reset PostgreSQL complet
docker-compose stop postgres matrix-synapse
docker rm -f dip-postgres
rm -rf data/postgres
docker-compose up -d postgres
sleep 15
docker-compose up --force-recreate -d matrix-synapse