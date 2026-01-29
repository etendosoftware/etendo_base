#!/bin/bash
# setup-quick.sh - Setup rápido para imagen pre-built
# Solo configura credenciales, NO compila (ya está en la imagen)

set -e

echo "════════════════════════════════════════════════════"
echo "🚀 Quick Setup for Pre-built Image"
echo "════════════════════════════════════════════════════"

# Verificar si gradle.properties existe
if [ -f "gradle.properties" ]; then
    echo "✅ gradle.properties already exists"
else
    echo "📝 Creating gradle.properties..."
    cat <<EOF > gradle.properties
bbdd.rdbms=POSTGRESQL
bbdd.driver=org.postgresql.Driver
bbdd.url=jdbc:postgresql://db:5432
bbdd.sid=etendo
bbdd.systemUser=postgres
bbdd.systemPassword=syspass
bbdd.user=tad
bbdd.password=tad
githubUser=${GITHUB_USER:-}
githubToken=${GITHUB_TOKEN:-}
nexusUser=${NEXUS_USER:-}
nexusPassword=${NEXUS_PASSWORD:-}
EOF
    echo "✅ gradle.properties created"
fi

# Verificar conexión a BD
echo "🔍 Checking database connection..."
for i in {1..30}; do
    if pg_isready -h db -U postgres > /dev/null 2>&1; then
        echo "✅ Database is ready"
        break
    fi
    echo "   Waiting for database... ($i/30)"
    sleep 1
done

# Verificar si Etendo está instalado
DB_TABLES=$(PGPASSWORD=syspass psql -h db -U postgres -d etendo -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | tr -d ' ' || echo "0")

if [ "$DB_TABLES" -gt "10" ] 2>/dev/null; then
    echo "✅ Etendo database already installed ($DB_TABLES tables)"
else
    echo "⚠️  Database empty - run './gradlew install' to install Etendo"
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ Quick setup complete!"
echo ""
echo "Next steps:"
echo "  1. ./gradlew install    # Install database (first time only)"
echo "  2. ./gradlew setup.web  # Start Fast Install UI"
echo "  3. Open http://localhost:3851"
echo "════════════════════════════════════════════════════"
