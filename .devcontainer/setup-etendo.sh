#!/bin/bash

# Configurar las propiedades de Etendo para el entorno SaaS
cat <<EOF > gradle.properties
bbdd.rdbms=POSTGRESQL
bbdd.driver=org.postgresql.Driver
bbdd.url=jdbc:postgresql://db:5432
bbdd.sid=etendo
bbdd.systemUser=postgres
bbdd.systemPassword=syspass
bbdd.user=tad
bbdd.password=tad
githubUser=${GITHUB_USER}
githubToken=${GITHUB_TOKEN}
nexusUser=${NEXUS_USER}
nexusPassword=${NEXUS_PASSWORD}
EOF

# Modificar build.gradle para usar core en JARs
cat <<'EOF' > build.gradle
plugins {
    id 'java'
    id 'war'
    id 'groovy'
    id 'maven-publish'
    id 'com.etendoerp.gradleplugin' version '2.2.1'
    id 'com.etendoerp.testing.gradleplugin' version '2.1.0'
}

etendo {
    coreVersion = "[25.1.0,26.1.0)"
}

dependencies {
    // Etendo Core in JAR format
    implementation('com.etendoerp.platform:etendo-core:[25.1.0,26.1.0)')
    implementation('com.etendoerp:dependencymanager:[3.0.0,4.0.0)')
}
EOF

# Crear directorios necesarios
mkdir -p lib config

# Limpiar build anterior si existe
rm -rf build .gradle

# Ejecutar setup
./gradlew setup

# Verificar si la base de datos ya tiene tablas (instalación previa)
DB_EXISTS=$(PGPASSWORD=syspass psql -h db -U postgres -d etendo -tc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | tr -d ' ')

if [ "$DB_EXISTS" -gt "0" ] 2>/dev/null; then
    echo "Base de datos ya instalada, omitiendo install..."
else
    echo "Instalando base de datos..."
    ./gradlew install
fi

./gradlew smartbuild

# Generar WAR y copiarlo
./gradlew antWar

echo "Deploy completado. Accede a http://localhost:8080/etendo"