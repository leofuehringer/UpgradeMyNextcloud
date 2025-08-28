#!/bin/bash

# Überprüfen, ob das Skript mit sudo oder als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
    echo "Bitte führe dieses Skript mit sudo aus: sudo $0 <pfad>"
    exit 1
fi

# Überprüfen der Argumente
if [ $# -ne 1 ]; then
    echo "Verwendung: $0 <pfad>   also z.B. ./update_nextcloud.sh /var/www/aes"
    exit 1
fi

# Argumente zuweisen
pfad=$1

# Definiere die Major-Releases
neue_versionen=("28.0.21" "29.0.16" "30.0.13")

# Auflisten der Major-Releases
echo "Verfügbare Major-Releases:"
for version in "${neue_versionen[@]}"; do
    echo " - $version"
done

echo "Hinweis: Wenn ein Release fehlt, ergänze es bitte auf GitHub."

# Bestätigungsabfrage für die Installation
read -p "Möchten Sie die Installation mit den angegebenen Major-Releases fortsetzen? (y/n): " -n 1 -r
echo  # Neue Zeile

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation abgebrochen."
    exit 0
fi

# Überprüfen, ob der angegebene Pfad existiert
if [ ! -d "$pfad" ]; then
    echo "Fehler: Der angegebene Pfad '$pfad' existiert nicht."
    exit 1
fi

# Überprüfen, ob der Ordner "nextcloud" im angegebenen Pfad vorhanden ist
if [ ! -d "$pfad/nextcloud" ]; then
    echo "Fehler: Der Ordner 'nextcloud' existiert nicht im Pfad '$pfad'."
    exit 1
fi

# Alte Version aus der version.php auslesen
alte_version=$(grep "\$OC_VersionString" "$pfad/nextcloud/version.php" | awk -F"'" '{print $2}')

# Überprüfen, ob die alte Version erfolgreich ausgelesen wurde
if [ -z "$alte_version" ]; then
    echo "Fehler: Konnte die alte Version aus der Datei version.php nicht auslesen."
    exit 1
fi

echo "Aktuelle Version: $alte_version"

# Nächstes Major-Release finden
next_release=""
for version in "${neue_versionen[@]}"; do
    if [[ "$version" > "$alte_version" ]]; then
        next_release="$version"
        break
    fi
done

# Überprüfen, ob ein nächstes Release vorhanden ist
if [ -z "$next_release" ]; then
    echo "Es sind keine neuen Major-Releases verfügbar."
    exit 0
fi

# Vorschlag zur Installation des nächsten Releases
echo "Das nächste Major-Release zur Installation ist: $next_release"
read -p "Möchten Sie das Update auf Version $next_release durchführen? (y/n): " -n 1 -r
echo  # Neue Zeile

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update abgebrochen."
    exit 0
fi

# URL für das Herunterladen der neuen Version
url="https://download.nextcloud.com/server/releases/nextcloud-${next_release}.tar.bz2"

echo "Deaktiviere Moodle-Cronjob für www-data..."
crontab -u www-data -l | sed '/cron\.php/s/^/#/' | crontab -u www-data -

echo "Stoppe Apache2..."
systemctl stop apache2

echo "Wechsle in das Verzeichnis: $pfad"
cd "$pfad" || { echo "Verzeichnis $pfad konnte nicht gefunden werden."; exit 1; }

echo "Aktiviere Wartungsmodus..."
sudo -u www-data php8.2 "$pfad/nextcloud/occ" maintenance:mode --on

echo "Sichere alte Nextcloud-Version..."
mv nextcloud "nextcloud-${alte_version}.bak"

echo "Lade neue Version von Nextcloud herunter..."
wget "$url"

echo "Entpacke die neue Version..."
tar -xjf "nextcloud-${next_release}.tar.bz2"

echo "Kopiere Konfiguration und Daten..."
cp "nextcloud-${alte_version}.bak/config/config.php" nextcloud/config/
mv "nextcloud-${alte_version}.bak/data/" nextcloud/

# Fehlende App-Ordner kopieren
zielverzeichnis="nextcloud/apps"
quelleverzeichnis="nextcloud-${alte_version}.bak/apps"

echo "Kopiere fehlende App-Ordner..."
for ordnername in "$quelleverzeichnis"/*; do  # Schleife über alle Ordner im Quellverzeichnis
    if [ -d "$ordnername" ]; then  # Überprüfen, ob es sich um einen Ordner handelt
        ordnername=$(basename "$ordnername")  # Extrahieren des Ordnernamens
        ziel_pfad="$zielverzeichnis/$ordnername"  # Pfad zum Zielordner
        if [ ! -d "$ziel_pfad" ]; then  # Überprüfen, ob der Zielordner nicht existiert
            cp -r "$quelleverzeichnis/$ordnername" "$zielverzeichnis"  # Kopieren des Ordners zum Zielverzeichnis
            echo "Ordner $ordnername wurde kopiert."
        fi
    fi
done

echo "Setze Berechtigungen für Nextcloud..."
chown -R www-data:www-data nextcloud
find nextcloud/ -type d -exec chmod 750 {} \;
find nextcloud/ -type f -exec chmod 640 {} \;

echo "Führe Upgrade durch..."
sudo -u www-data php8.2 "$pfad/nextcloud/occ" upgrade

echo "Deaktiviere Wartungsmodus..."
sudo -u www-data php8.2 "$pfad/nextcloud/occ" maintenance:mode --off

echo "Aktiviere Moodle-Cronjob für www-data..."
crontab -u www-data -l | sed '/cron\.php/s/^#//' | crontab -u www-data -

echo "Lösche die heruntergeladene bz2-Datei..."
rm "nextcloud-${next_release}.tar.bz2"

echo "Starte Apache2..."
systemctl start apache2

echo "Nextcloud wurde erfolgreich von Version $alte_version auf $next_release aktualisiert."

# tmux-Session beenden
echo "Beende die tmux-Session..."
exit 0
