#!/bin/bash
# backup-vps-complet-ultra-secure.sh
# Script de sauvegarde complète du système avec gestion avancée des bases de données

HOSTNAME=$(hostname)
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/${HOSTNAME}-full-backup-${DATE}.tar.gz"
EXCLUDE_FILE="/tmp/exclude-list-${DATE}.txt"
DB_BACKUP_DIR="/tmp/db-backups-${DATE}"
LOG_FILE="/var/log/backup-vps-${DATE}.log"

# Fonction de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction de gestion d'erreur
error_exit() {
    log "❌ ERREUR: $1"
    exit 1
}

# Début du script
log "🚀 DÉBUT DE LA SAUVEGARDE ULTRA-SÉCURISÉE"
log "📍 Hostname: $HOSTNAME"
log "📅 Date: $DATE"

# Vérification des privilèges
if [[ $EUID -ne 0 ]]; then
    error_exit "Ce script doit être exécuté en tant que root"
fi

# Vérification de l'espace disque
AVAILABLE_SPACE=$(df /tmp | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then  # Moins de 1GB libre
    error_exit "Espace disque insuffisant dans /tmp (min. 1GB requis)"
fi

log "📋 Création de la liste d'exclusions..."
cat > "$EXCLUDE_FILE" << 'EOF'
/proc/*
/sys/*
/dev/*
/run/*
/tmp/*
/var/tmp/*
/var/run/*
/var/lock/*
/mnt/*
/media/*
/sysroot/*
/var/cache/apt/archives/*.deb
/var/cache/apt/*.bin
/home/*/.cache/*
/var/log/*.gz
/var/log/*.old
/var/log/*.1
/.cache/*
/swapfile
/var/swap
EOF

# 🗃️ PHASE 1: SAUVEGARDE AVANCÉE DES BASES DE DONNÉES
log "🗃️  PHASE 1: SAUVEGARDE AVANCÉE DES BASES DE DONNÉES"
mkdir -p "$DB_BACKUP_DIR"

# Fonction pour arrêter et redémarrer les services
stop_database_services() {
    log "🛑 Arrêt temporaire des services de base de données..."
    
    # MySQL/MariaDB
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        log "⏸️  Arrêt de MySQL/MariaDB..."
        systemctl stop mysql 2>/dev/null || systemctl stop mariadb 2>/dev/null
        MYSQL_STOPPED=true
    fi
    
    # PostgreSQL
    if systemctl is-active --quiet postgresql; then
        log "⏸️  Arrêt de PostgreSQL..."
        systemctl stop postgresql
        POSTGRES_STOPPED=true
    fi
    
    # MongoDB
    if systemctl is-active --quiet mongod; then
        log "⏸️  Arrêt de MongoDB..."
        systemctl stop mongod
        MONGODB_STOPPED=true
    fi
    
    # Redis
    if systemctl is-active --quiet redis-server; then
        log "⏸️  Arrêt de Redis..."
        systemctl stop redis-server
        REDIS_STOPPED=true
    fi
}

start_database_services() {
    log "🔁 Redémarrage des services de base de données..."
    
    [ "$MYSQL_STOPPED" = "true" ] && { systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null; log "✅ MySQL/MariaDB redémarré"; }
    [ "$POSTGRES_STOPPED" = "true" ] && { systemctl start postgresql; log "✅ PostgreSQL redémarré"; }
    [ "$MONGODB_STOPPED" = "true" ] && { systemctl start mongod; log "✅ MongoDB redémarré"; }
    [ "$REDIS_STOPPED" = "true" ] && { systemctl start redis-server; log "✅ Redis redémarré"; }
}

# Arrêt des services DB pour cohérence des fichiers
stop_database_services

# MySQL/MariaDB - Sauvegarde des fichiers binaires + Export SQL
if command -v mysqldump &> /dev/null || [ -d /var/lib/mysql ]; then
    log "💾 Sauvegarde MySQL/MariaDB..."
    
    # Export SQL de toutes les bases
    if command -v mysqldump &> /dev/null; then
        mysqldump --all-databases --single-transaction --routines --events > "$DB_BACKUP_DIR/mysql-all-databases.sql" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "✅ Export SQL MySQL réussi ($(du -h "$DB_BACKUP_DIR/mysql-all-databases.sql" | cut -f1))"
        else
            log "⚠️  Export SQL MySQL échoué, tentative alternative..."
            # Tentative avec authentification
            mysqldump -u root -p"$(grep -oP 'password\s*=\s*\K[^ ]+' /etc/mysql/debian.cnf 2>/dev/null | head -1)" --all-databases > "$DB_BACKUP_DIR/mysql-all-databases.sql" 2>/dev/null || true
        fi
    fi
    
    # Sauvegarde des fichiers de données brutes (si services arrêtés)
    if [ -d /var/lib/mysql ]; then
        tar -czf "$DB_BACKUP_DIR/mysql-data-files.tar.gz" -C /var/lib/mysql . 2>/dev/null && \
        log "✅ Fichiers de données MySQL sauvegardés"
    fi
fi

# PostgreSQL - Sauvegarde des fichiers binaires + Export SQL
if command -v pg_dumpall &> /dev/null || [ -d /var/lib/postgresql ]; then
    log "🐘 Sauvegarde PostgreSQL..."
    
    # Export SQL de toutes les bases
    if command -v pg_dumpall &> /dev/null; then
        sudo -u postgres pg_dumpall > "$DB_BACKUP_DIR/postgresql-all-databases.sql" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "✅ Export SQL PostgreSQL réussi"
        else
            log "⚠️  Export SQL PostgreSQL échoué"
        fi
    fi
    
    # Sauvegarde des fichiers de données brutes
    if [ -d /var/lib/postgresql ]; then
        tar -czf "$DB_BACKUP_DIR/postgresql-data-files.tar.gz" -C /var/lib/postgresql . 2>/dev/null && \
        log "✅ Fichiers de données PostgreSQL sauvegardés"
    fi
fi

# MongoDB
if command -v mongodump &> /dev/null || [ -d /var/lib/mongodb ]; then
    log "🍃 Sauvegarde MongoDB..."
    
    if command -v mongodump &> /dev/null; then
        mongodump --out "$DB_BACKUP_DIR/mongodb-backup" 2>/dev/null && \
        log "✅ Dump MongoDB réussi"
    fi
    
    if [ -d /var/lib/mongodb ]; then
        tar -czf "$DB_BACKUP_DIR/mongodb-data-files.tar.gz" -C /var/lib/mongodb . 2>/dev/null && \
        log "✅ Fichiers de données MongoDB sauvegardés"
    fi
fi

# Redis
if command -v redis-cli &> /dev/null && systemctl is-active --quiet redis-server; then
    log "🔴 Sauvegarde Redis..."
    redis-cli SAVE 2>/dev/null
    if [ -f /var/lib/redis/dump.rdb ]; then
        cp /var/lib/redis/dump.rdb "$DB_BACKUP_DIR/redis-dump.rdb" 2>/dev/null && \
        log "✅ Dump Redis sauvegardé"
    fi
fi

# Redémarrage des services DB
start_database_services

# 📦 PHASE 2: SAUVEGARDE DU SYSTÈME COMPLET
log "📦 PHASE 2: SAUVEGARDE DU SYSTÈME COMPLET"

# Informations système
log "💻 Informations système:"
uname -a >> "$DB_BACKUP_DIR/system-info.txt"
df -h >> "$DB_BACKUP_DIR/disk-usage.txt"
dpkg --get-selections > "$DB_BACKUP_DIR/installed-packages.txt"

log "🚀 Création de l'archive système complète..."
if tar -czpf "$BACKUP_FILE" \
    --exclude-from="$EXCLUDE_FILE" \
    --exclude="$BACKUP_FILE" \
    --exclude="$DB_BACKUP_DIR" \
    --exclude="/var/lib/docker/*" \
    --exclude="/snap/*" \
    --exclude="/home/*/.cache/*" \
    --one-file-system \
    / "$DB_BACKUP_DIR" 2>> "$LOG_FILE"
then
    log "✅ Archive créée avec succès: $BACKUP_FILE"
    log "📊 Taille finale: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    error_exit "Échec de la création de l'archive"
fi

# 🔍 VÉRIFICATION DE L'ARCHIVE
log "🔍 Vérification de l'archive..."
if tar -tzf "$BACKUP_FILE" > /dev/null 2>&1; then
    log "✅ Archive vérifiée et valide"
    
    # Afficher le contenu important
    log "📁 Contenu critique de l'archive:"
    tar -tzf "$BACKUP_FILE" | grep -E "(etc/|home/|var/www/|db-backups)" | head -15 | while read line; do
        log "   📄 $line"
    done
else
    error_exit "Archive corrompue ou invalide"
fi

# 🎯 PRÉPARATION POUR TRANSFERT
log "🎯 Préparation pour transfert..."
FINAL_BACKUP_NAME="${HOSTNAME}-backup-${DATE}.tar.gz"
mv "$BACKUP_FILE" "/tmp/${FINAL_BACKUP_NAME}"

# Calcul MD5 pour vérification d'intégrité
md5sum "/tmp/${FINAL_BACKUP_NAME}" > "/tmp/${FINAL_BACKUP_NAME}.md5"
log "🔢 Checksum MD5: $(cat "/tmp/${FINAL_BACKUP_NAME}.md5")"

# 📊 RAPPORT FINAL
log "=========================================="
log "🎉 SAUVEGARDE TERMINÉE AVEC SUCCÈS!"
log "📍 Fichier de backup: /tmp/${FINAL_BACKUP_NAME}"
log "📊 Taille: $(du -h "/tmp/${FINAL_BACKUP_NAME}" | cut -f1)"
log "📋 Logs détaillés: $LOG_FILE"
log "🔢 Checksum: $(cat "/tmp/${FINAL_BACKUP_NAME}.md5" | cut -d' ' -f1)"
log "=========================================="

# Affichage des instructions de transfert
echo ""
echo "📤 POUR TRANSFÉRER LE BACKUP:"
echo "scp /tmp/${FINAL_BACKUP_NAME} user@remote-server:/backup/path/"
echo "curl -T /tmp/${FINAL_BACKUP_NAME} ftp://ftp-server/path/ --user user:pass"
echo ""
echo "🔍 POUR VÉRIFIER LE CONTENU:"
echo "tar -tzf /tmp/${FINAL_BACKUP_NAME} | grep -E 'etc/|home/|db-backups'"

# 🧹 NETTOYAGE (optionnel - décommentez si voulu)
# log "🧹 Nettoyage des fichiers temporaires..."
# rm -rf "$EXCLUDE_FILE" "$DB_BACKUP_DIR"

exit 0
