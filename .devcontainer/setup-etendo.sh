#!/bin/bash
set -e

# =============================================================================
# Etendo DevContainer Setup Script
# =============================================================================
# Supports two modes:
#   - Standard: Uses plugin from Maven (default)
#   - Fast Install: Uses buildSrc symlink to plugin repo for development
#
# Set FAST_INSTALL_MODE=true to enable Fast Install mode
# =============================================================================

echo "=============================================="
echo "  Etendo DevContainer Setup"
echo "=============================================="

# Check if Fast Install mode is enabled
FAST_INSTALL_MODE="${FAST_INSTALL_MODE:-false}"

if [ "$FAST_INSTALL_MODE" = "true" ]; then
    echo "  Mode: Fast Install (buildSrc)"
else
    echo "  Mode: Standard (Maven plugin)"
fi
echo "=============================================="
echo ""

# Create gradle.properties with DB config and credentials
echo "Creating gradle.properties..."
cat <<EOF > gradle.properties
# Database configuration
bbdd.rdbms=POSTGRESQL
bbdd.driver=org.postgresql.Driver
bbdd.url=jdbc:postgresql://db:5432
bbdd.sid=etendo
bbdd.systemUser=postgres
bbdd.systemPassword=syspass
bbdd.user=tad
bbdd.password=tad

# Credentials from environment
githubUser=${GITHUB_USER}
githubToken=${GITHUB_TOKEN}
nexusUser=${NEXUS_USER}
nexusPassword=${NEXUS_PASSWORD}

# Context
context.name=etendo
EOF

if [ "$FAST_INSTALL_MODE" = "true" ]; then
    # ==========================================================================
    # Fast Install Mode - Use buildSrc for plugin development
    # ==========================================================================
    echo "Setting up Fast Install mode with buildSrc..."

    # Check if plugin repo exists (should be mounted or cloned)
    PLUGIN_DIR="/workspace/com.etendoerp.gradleplugin"
    if [ ! -d "$PLUGIN_DIR" ]; then
        echo "Cloning gradle plugin repository..."
        git clone -b feature/ETP-2946-Y26 git@github.com:etendosoftware/com.etendoerp.gradleplugin.git "$PLUGIN_DIR"
    fi

    # Create buildSrc symlink
    if [ -d "buildSrc" ] || [ -L "buildSrc" ]; then
        rm -rf buildSrc
    fi
    ln -s "$PLUGIN_DIR" buildSrc
    echo "buildSrc -> $PLUGIN_DIR"

    # Setup plugin gradle.properties
    if [ -f "$PLUGIN_DIR/gradle.properties.template" ]; then
        cp "$PLUGIN_DIR/gradle.properties.template" "$PLUGIN_DIR/gradle.properties"
        sed -i "s/^nexusUser=.*/nexusUser=${NEXUS_USER}/" "$PLUGIN_DIR/gradle.properties"
        sed -i "s/^nexusPassword=.*/nexusPassword=${NEXUS_PASSWORD}/" "$PLUGIN_DIR/gradle.properties"
        sed -i "s/^githubUser=.*/githubUser=${GITHUB_USER}/" "$PLUGIN_DIR/gradle.properties"
        sed -i "s/^githubToken=.*/githubToken=${GITHUB_TOKEN}/" "$PLUGIN_DIR/gradle.properties"
        sed -i "s/^etendoCoreVersion=.*/etendoCoreVersion=25.1.0/" "$PLUGIN_DIR/gradle.properties"
    fi

    # Remove plugin version from build.gradle (using buildSrc)
    if grep -q "version '[0-9]" build.gradle 2>/dev/null; then
        sed -i "s/id 'com.etendoerp.gradleplugin' version '[^']*'/id 'com.etendoerp.gradleplugin'/g" build.gradle
    fi

    # Add Docker resources to gradle.properties
    cat <<EOF >> gradle.properties

# Docker resources
docker_com.etendoerp.docker_db=true
docker_com.etendoerp.tomcat=true
EOF

    echo "Fast Install mode configured!"

else
    # ==========================================================================
    # Standard Mode - Use plugin from Maven
    # ==========================================================================
    echo "Setting up Standard mode with Maven plugin..."

    cat <<'EOF' > build.gradle
plugins {
    id 'java'
    id 'war'
    id 'groovy'
    id 'maven-publish'
    id 'com.etendoerp.gradleplugin' version '2.2.1'
}

etendo {
    coreVersion = "[25.1.0,26.1.0)"
}

dependencies {
    implementation('com.etendoerp.platform:etendo-core:[25.1.0,26.1.0)')
    implementation('com.etendoerp:dependencymanager:[3.0.0,4.0.0)')
}
EOF
fi

# Create necessary directories
mkdir -p lib config

# Clean previous build if exists
rm -rf build .gradle

# Run setup
echo "Running gradle setup..."
./gradlew setup

# Check if database already has tables (previous installation)
DB_EXISTS=$(PGPASSWORD=syspass psql -h db -U postgres -d etendo -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | tr -d ' ')

if [ "$DB_EXISTS" -gt "0" ] 2>/dev/null; then
    echo "Database already installed, running update.database + smartbuild..."
    ./gradlew update.database
    ./gradlew smartbuild
else
    echo "Installing database..."
    ./gradlew install
    ./gradlew smartbuild
fi

# Generate WAR and deploy
./gradlew antWar

echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "Access Etendo at: http://localhost:8080/etendo"
echo "Credentials: admin / admin"
echo ""
if [ "$FAST_INSTALL_MODE" = "true" ]; then
    echo "Fast Install UI: ./gradlew setup.web"
    echo "Then open: http://localhost:3851"
fi
echo "=============================================="
