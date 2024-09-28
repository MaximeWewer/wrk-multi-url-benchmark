# Étape 1 : Build de wrk
FROM alpine:3.20 AS builder

# Installer les dépendances nécessaires pour la compilation
RUN apk add --no-cache \
    build-base \
    openssl-dev \
    perl \
    linux-headers \
    git

# Télécharger et construire wrk
WORKDIR /tmp
RUN git clone https://github.com/wg/wrk.git && \
    cd wrk && \
    git checkout 4.2.0 && \
    make

# Étape 2 : Image minimale avec wrk
FROM alpine:3.20

# Installer les dépendances d'exécution
RUN apk add --no-cache libgcc

# Créer un volume pour charger les scripts Lua
VOLUME /data

# Définir le répertoire de travail par défaut
WORKDIR /data

# Copier le binaire wrk depuis l'image builder
COPY --from=builder /tmp/wrk/wrk /usr/local/bin/wrk

# Exécuter l'outil wrk par défaut
ENTRYPOINT ["wrk"]
