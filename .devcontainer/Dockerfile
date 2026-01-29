FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Instalar herramientas necesarias
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Configurar directorio de trabajo
WORKDIR /workspace

# Mantener el contenedor activo
CMD ["sleep", "infinity"]
