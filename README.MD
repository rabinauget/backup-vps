# Sauvegarde VPS Debian

Ce script permet d’effectuer une sauvegarde complète de votre VPS Debian, incluant vos fichiers système, configurations et bases de données.  
Il est conçu pour être simple à utiliser et compatible avec la plupart des environnements Debian.

---

## 📦 Installation

Téléchargez le script et rendez-le exécutable :

```bash
wget -O /usr/local/bin/vps-debian-backup.sh https://raw.githubusercontent.com/rabinauget/backup-vps/main/vps-debian-backup.sh
chmod +x /usr/local/bin/vps-debian-backup.sh
/usr/local/bin/backup-vps-complet.sh
nohup /usr/local/bin/backup-vps-complet.sh &
