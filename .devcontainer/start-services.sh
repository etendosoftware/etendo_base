#!/bin/bash
# start-services.sh - Auto-inicia servicios al arrancar devcontainer

set -e

echo ""
echo "════════════════════════════════════════════════════"
echo "🚀 Starting Etendo Services..."
echo "════════════════════════════════════════════════════"

# Limpiar build si hay problemas de permisos
if [ -d "/workspace/build" ]; then
    echo "🧹 Cleaning build directory..."
    rm -rf /workspace/build 2>/dev/null || sudo rm -rf /workspace/build 2>/dev/null || true
fi

# Clonar plugin con setup.web si no existe
if [ ! -d "/workspace/buildSrc" ]; then
    echo "📦 Cloning gradle plugin with setup.web task..."
    git clone --depth 1 -b feature/ETP-2946-Y26 https://github.com/etendosoftware/com.etendoerp.gradleplugin.git /workspace/buildSrc
    cd /workspace/buildSrc && cp gradle.properties.template gradle.properties
    cd /workspace
    # Remover versión del plugin en build.gradle (ya viene de buildSrc)
    sed -i "s/id 'com.etendoerp.gradleplugin' version '[^']*'/id 'com.etendoerp.gradleplugin'/" /workspace/build.gradle
    echo "✅ Plugin cloned to buildSrc"
fi

# Esperar a que la BD esté lista
echo "⏳ Waiting for database..."
for i in {1..30}; do
    if pg_isready -h db -U postgres > /dev/null 2>&1; then
        echo "✅ Database ready"
        break
    fi
    sleep 1
done

# Verificar si necesita install
DB_TABLES=$(PGPASSWORD=syspass psql -h db -U postgres -d etendo -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | tr -d ' ' || echo "0")

if [ "$DB_TABLES" -lt "10" ] 2>/dev/null; then
    echo "📦 Installing database (first time)..."
    ./gradlew install --no-daemon || true
else
    echo "🔄 Database already installed, skipping install step."
fi

# Iniciar Fast Install UI en background
echo "🛠️  Starting Fast Install UI..."
nohup ./gradlew setup.web --no-daemon > /tmp/setup-web.log 2>&1 &

# Esperar a que el servidor esté listo
for i in {1..30}; do
    if curl -s http://localhost:3851 > /dev/null 2>&1; then
        echo "✅ Fast Install UI ready at http://localhost:3851"
        break
    fi
    sleep 1
done

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ Etendo Dev Environment Ready!"
echo ""
echo "   🛠️  Fast Install UI: http://localhost:3851"
echo "   🌐 Etendo ERP:       http://localhost:8080/etendo"
echo "════════════════════════════════════════════════════"
