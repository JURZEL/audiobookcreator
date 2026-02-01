<!-- markdownlint-disable MD022 MD032 MD026 MD031 MD040 -->
# CD Ripper Pro - Modernes Flutter Frontend für cdparanoia

Ein elegantes, modernes Flutter-Frontend für cdparanoia zum Rippen und Konvertieren von Audio-CDs mit umfangreichen Metadaten-Features.

## Features

### 🎵 CD-Funktionen
- **Automatisches CD-Scanning**: Erkennt eingelegte CDs und liest alle Informationen aus
- **Detaillierte CD-Informationen**:
  - Anzahl der Tracks
  - Länge jedes Tracks und der gesamten CD
  - Eindeutige Disc-ID (MusicBrainz)
  - FreeDB-ID
  - Sektor-Informationen
  - Geräte-Pfad

### 🎨 Elegantes UI-Design
- **Glassmorphismus-Effekte**: Moderne transparente UI-Elemente mit Blur-Effekt
- **Animierte Hintergründe**: Sanfte Gradient-Animationen
- **Material 3 Design**: Modernste Flutter-Designsprache
- **Dunkles Theme**: Augenschonendes Design mit leuchtenden Akzenten
- **Responsive Layout**: Passt sich verschiedenen Bildschirmgrößen an
- **Sidebar-Navigation**: Elegante Seitenleiste mit Menü und Einstellungen

### 🔍 MusicBrainz Integration
- **Automatische Metadaten-Suche**: Per Disc-ID direkt vom Hauptbildschirm
- **Cover-Art Download**: Automatischer Download von Album-Covern
- **Google Cover-Fallback**: Öffnet Google-Bildsuche, wenn kein Cover gefunden wird
- **Track-Informationen**: Titel, Künstler, ISRC-Codes
- **Album-Details**: Label, Katalognummer, Barcode, Veröffentlichungsjahr
- **Mehrfach-Ergebnisse**: Dialog zur Auswahl bei mehreren Treffern

### ✏️ Metadaten-Editor
- **Vollständige Bearbeitung**: Alle CD- und Track-Metadaten editierbar
- **MusicBrainz-Suche integriert**: Direkte Übernahme von Online-Daten
- **Track-spezifische Metadaten**: Individuelle Titel und Künstler pro Track

### ⚙️ Einstellungen & System-Check
- **Dependency-Überprüfung**: Automatische Erkennung von cdparanoia, ffmpeg und cd-discid
- **Versions-Anzeige**: Zeigt installierte Versionen aller Abhängigkeiten
- **Installations-Hilfe**: Anweisungen für Ubuntu/Debian, Fedora/RHEL und Arch Linux
- **CD-Geräte-Erkennung**: Liste aller verfügbaren CD-Laufwerke
- **System-Status**: Visueller Indikator für vollständige/fehlende Installation

### 💾 Export & Konvertierung
- **Viele Formate unterstützt**:
  - FLAC (verlustfrei)
  - MP3 (VBR/CBR)
  - AAC
  - Opus
  - OGG Vorbis
  - WAV (unkomprimiert)
  - ALAC (Apple Lossless)
  - APE (Monkey's Audio)

- **Qualitäts-Einstellungen**:
  - VBR/CBR für MP3
  - Kompression für FLAC
  - Bitrate-Auswahl für alle Formate

- **Progress-Tracking**: Echtzeit-Fortschritt für jeden Track
- **Batch-Export**: Mehrere Tracks gleichzeitig
- **Automatische Metadaten**: ID3-Tags werden automatisch eingefügt

## Systemvoraussetzungen

### Linux (empfohlen)
- Flutter 3.10.7 oder höher
- cdparanoia
- ffmpeg
- cd-discid (optional, für CD-Identifikation)

### Installation der Abhängigkeiten

#### Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install cdparanoia ffmpeg cd-discid
```

#### Fedora/RHEL:
```bash
# RPM Fusion Free Repository aktivieren (für ffmpeg)
sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm

# Pakete installieren
sudo dnf install cdparanoia ffmpeg cd-discid
```

#### Arch Linux:
```bash
sudo pacman -S cdparanoia ffmpeg libcdio
```

## Installation

1. **Flutter-Abhängigkeiten installieren**:
   ```bash
   flutter pub get
   ```

2. **App ausführen**:
   ```bash
   flutter run -d linux
   ```

## Verwendung

### 1. CD einlegen
Legen Sie eine Audio-CD in Ihr CD-Laufwerk ein. Die App erkennt die CD automatisch.

### 2. CD-Informationen anzeigen
Die App zeigt automatisch:
- Album-Cover (falls verfügbar)
- Anzahl der Tracks
- Gesamtdauer
- Disc-ID und andere technische Informationen

### 3. Metadaten abrufen
**Direkt vom Hauptbildschirm:**
- Klicken Sie auf "Metadaten abrufen" im CD-Info-Bereich
- Die App sucht automatisch per Disc-ID bei MusicBrainz
- Bei mehreren Treffern wählen Sie das richtige Album aus
- Cover-Art wird automatisch geladen
- Falls kein Cover gefunden wird, öffnet sich Google-Bildsuche

**Über den Metadaten-Editor:**
- Klicken Sie auf "Metadaten bearbeiten"
- Nutzen Sie "Nach Disc-ID suchen" für automatische Erkennung
- Oder suchen Sie manuell nach Künstler und Album
- Wählen Sie das richtige Album aus den Ergebnissen
- Die Metadaten werden automatisch übernommen

### 4. Tracks auswählen und exportieren
- Tippen Sie auf einzelne Tracks zum Auswählen
- Wählen Sie das gewünschte Audio-Format
- Passen Sie die Qualitäts-Einstellungen an
- Starten Sie den Export

### 5. System-Check in Einstellungen
- Öffnen Sie die Einstellungen über die Sidebar (unten)
- Überprüfen Sie, ob alle Abhängigkeiten installiert sind
- Folgen Sie den Installations-Anweisungen bei fehlenden Tools
- Prüfen Sie, welche CD-Laufwerke erkannt werden

## Architektur

### Projekt-Struktur
```
lib/
├── main.dart                    # App-Einstiegspunkt
├── models/
│   └── cd_info.dart            # Datenmodelle
├── services/
│   ├── cd_service.dart         # cdparanoia Integration
│   ├── musicbrainz_service.dart # MusicBrainz API
│   └── ffmpeg_service.dart     # Audio-Konvertierung
├── providers/
│   └── app_providers.dart      # Riverpod State Management
├── screens/
│   ├── cd_info_screen.dart     # Haupt-CD-Ansicht
│   ├── metadata_editor_screen.dart # Metadaten-Editor
│   ├── export_screen.dart      # Export & Konvertierung
│   └── settings_screen.dart    # System-Check & Einstellungen
├── widgets/
│   ├── glass_widgets.dart      # UI-Komponenten
│   └── app_drawer.dart         # Sidebar-Navigation
└── theme/
    └── app_theme.dart          # Design-System
```

### Technologie-Stack
- **Flutter**: UI-Framework
- **Riverpod**: State Management
- **cdparanoia**: CD-Ripping
- **FFmpeg**: Audio-Konvertierung
- **MusicBrainz API**: Metadaten-Abruf

## Lizenz

Dieses Projekt nutzt verschiedene Open-Source-Tools:
- cdparanoia (GPL)
- FFmpeg (GPL/LGPL)
- MusicBrainz API (CC0)

