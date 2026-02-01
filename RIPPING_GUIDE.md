<!-- markdownlint-disable MD022 MD032 MD031 MD040 -->
# Ripping-Funktion - Dokumentation

## Übersicht

Die Ripping-Funktion ermöglicht das professionelle Rippen von Audio-CDs mit umfassenden Konfigurationsmöglichkeiten. Sie unterstützt alle gängigen Audio-Formate und bietet flexible Dateinamen-Vorlagen mit Platzhaltern.

## Features

### 📀 Format-Unterstützung

Die Ripping-Funktion unterstützt folgende Audio-Formate:

- **FLAC** - Verlustfreie Kompression (Empfohlen für Archivierung)
- **MP3** - VBR/CBR mit variabler Qualität
- **AAC** - Advanced Audio Coding (96-320 kbps)
- **Opus** - Moderner Codec (64-256 kbps)
- **OGG Vorbis** - Open-Source-Format (Q0-Q10)
- **WAV** - Unkomprimiert
- **ALAC** - Apple Lossless
- **APE** - Monkey's Audio

### 🎯 Track-Auswahl

- Einzelne Tracks selektiv auswählen
- Alle Tracks auf einmal auswählen/abwählen
- Anzeige von Track-Titel und Dauer
- Zähler für ausgewählte Tracks

### 📁 Ausgabe-Konfiguration

- **Ordner-Auswahl**: Frei wählbares Ausgabeverzeichnis
- **Dateinamen-Vorlagen**: Flexible Benennung mit Platzhaltern
- **Vordefinierte Templates**: 9 vorgefertigte Vorlagen für verschiedene Anwendungsfälle

### 🏷️ Dateinamen-Platzhalter

#### Basis-Metadaten
- `%TrackNumber` - Track-Nummer mit führenden Nullen (01, 02, ...)
- `%Title` - Track-Titel
- `%Artist` - Track-Künstler
- `%Album` - Album-Titel
- `%AlbumArtist` - Album-Künstler
- `%Year` - Erscheinungsjahr
- `%Genre` - Genre
- `%CD` - Disc-Nummer (bei Multi-Disc-Sets)

#### Erweiterte Metadaten (Audiobooks/Hörspiele)
- `%Author` - Autor (für Audiobooks)
- `%Narrator` - Sprecher/Erzähler
- `%Series` - Reihe/Serie
- `%SeriesPart` - Teil der Reihe

### 📋 Vordefinierte Dateinamen-Vorlagen

1. **Standard**: `%TrackNumber - %Title`
   - Beispiel: `01 - Introduction.flac`

2. **Musik Standard**: `%TrackNumber - %Artist - %Title`
   - Beispiel: `01 - The Beatles - Yesterday.flac`

3. **Album-Ordner**: `%Album/%TrackNumber - %Title`
   - Beispiel: `Abbey Road/01 - Come Together.flac`

4. **Künstler-Album**: `%Artist - %Album/%TrackNumber - %Title`
   - Beispiel: `The Beatles - Abbey Road/01 - Come Together.flac`

5. **Audiobook Standard**: `%TrackNumber - %Title`
   - Beispiel: `01 - Kapitel 1.flac`

6. **Audiobook mit Autor**: `%Author - %Album/%TrackNumber - %Title`
   - Beispiel: `Stephen King - The Shining/01 - Part One.flac`

7. **Audiobook mit Sprecher**: `%Narrator - %Album/%TrackNumber - %Title`
   - Beispiel: `Frank Muller - The Shining/01 - Part One.flac`

8. **Hörbuch Reihe**: `%Author/%Series %SeriesPart - %Album/%TrackNumber - %Title`
   - Beispiel: `J.K. Rowling/Harry Potter 1 - Philosopher's Stone/01 - Chapter 1.flac`

9. **Multi-Disc**: `CD%CD/%TrackNumber - %Title`
   - Beispiel: `CD1/01 - Track One.flac`

### ⚙️ Format-spezifische Optionen

#### MP3
- **Modus**: VBR (Variable Bitrate) oder CBR (Constant Bitrate)
- **VBR Qualität**: V0 bis V9
  - V0: ~245 kbps (höchste Qualität)
  - V2: ~190 kbps (empfohlen)
  - V5: ~130 kbps
  - V9: ~65 kbps (niedrigste Qualität)

#### FLAC
- **Kompression**: Level 0-8
  - Level 0: Schnell, größere Dateien
  - Level 5: Standard (empfohlen)
  - Level 8: Langsam, kleinste Dateien
- Hinweis: Alle Levels sind verlustfrei

#### AAC
- **Bitrate**: 96, 128, 160, 192, 256, 320 kbps
- Empfohlen: 192 kbps

#### Opus
- **Bitrate**: 64, 96, 128, 160, 192, 256 kbps
- Empfohlen: 128 kbps

#### OGG Vorbis
- **Qualität**: Q0-Q10
  - Q3: ~112 kbps
  - Q6: ~192 kbps (empfohlen)
  - Q10: ~500 kbps

### 🎨 Zusätzliche Optionen

- **Cover-Art einbetten**: Album-Cover direkt in Audio-Dateien einbetten
- **Playlist erstellen**: M3U-Playlist-Datei für alle gerippten Tracks

## Erweiterte Metadaten

### Für Musik
- Künstler
- Album-Titel
- Jahr
- Genre
- Label
- Katalognummer
- Barcode

### Für Audiobooks/Hörspiele
- **Autor**: Der Verfasser des Werks
- **Sprecher**: Erzähler oder Vorleser
- **Verlag**: Publisher des Audiobooks
- **Reihe**: Serie/Reihen-Name
- **Reihenteil**: Nummer in der Reihe
- **Beschreibung**: Inhaltsangabe
- **Sprache**: Sprache des Audiobooks (z.B. "de", "en")
- **Copyright**: Copyright-Informationen
- **Kommentar**: Zusätzliche Notizen

## Verwendung

### 1. CD Rippen-Button

Klicken Sie auf den großen "CD rippen"-Button auf dem Hauptbildschirm.

### 2. Format wählen

Wählen Sie das gewünschte Audio-Format aus den 8 verfügbaren Optionen.

### 3. Tracks auswählen

- Markieren Sie die Tracks, die Sie rippen möchten
- Verwenden Sie "Alle auswählen" für alle Tracks
- Die Auswahl wird live aktualisiert

### 4. Ausgabe-Ordner festlegen

- Klicken Sie auf "Wählen", um einen Ordner auszuwählen
- Standard: `~/Music/CD_Rips`

### 5. Dateinamen-Vorlage anpassen

- Wählen Sie eine vordefinierte Vorlage oder
- Erstellen Sie eine eigene mit Platzhaltern
- Nutzen Sie die Platzhalter-Liste zum Einfügen
- Die Vorschau zeigt das Ergebnis

### 6. Format-Optionen einstellen

Passen Sie qualitätsspezifische Einstellungen an:
- MP3: VBR/CBR und Qualität
- FLAC: Kompression
- AAC/Opus: Bitrate
- OGG: Qualitätsstufe

### 7. Zusatzoptionen aktivieren

- Cover-Art einbetten (empfohlen)
- Playlist erstellen (optional)

### 8. Ripping starten

Klicken Sie auf "Ripping starten" - die Tracks werden verarbeitet.

## Best Practices

### Für Musik-CDs
```
Format: FLAC (Level 5)
Template: Künstler - Album
Beispiel: The Beatles - Abbey Road/01 - Come Together.flac
```

### Für Audiobooks
```
Format: MP3 (VBR V2) oder AAC (192 kbps)
Template: Audiobook mit Autor
Beispiel: Stephen King - The Shining/01 - Part One.mp3
```

### Für Hörspiel-Reihen
```
Format: MP3 (VBR V2)
Template: Hörbuch Reihe
Beispiel: J.K. Rowling/Harry Potter 1/01 - Chapter 1.mp3
```

### Für Multi-Disc-Sets
```
Format: FLAC (Level 5)
Template: Multi-Disc
Disc-Nummer in Metadaten setzen
Beispiel: The Wall/CD1/01 - In The Flesh.flac
```

## Technische Details

### Dateinamen-Sanierung
- Ungültige Zeichen (`<>:"/\|?*`) werden durch `_` ersetzt
- Mehrfache Leerzeichen werden entfernt
- Dateinamen werden getrimmt

### Format-Defaults
- **MP3**: VBR V2 (~190 kbps)
- **FLAC**: Kompression Level 5
- **AAC**: 192 kbps
- **Opus**: 128 kbps
- **OGG**: Q6 (~192 kbps)

### Metadaten-Einbettung
Alle Metadaten werden automatisch in die Audio-Dateien eingebettet:
- ID3v2.4 für MP3
- Vorbis Comments für FLAC/OGG/Opus
- iTunes-Tags für AAC/ALAC

## Troubleshooting

### Problem: Ordner kann nicht ausgewählt werden
**Lösung**: Stellen Sie sicher, dass Sie Schreibrechte im Zielverzeichnis haben.

### Problem: Bestimmte Platzhalter werden nicht ersetzt
**Lösung**: Prüfen Sie, ob die entsprechenden Metadaten gesetzt sind. Fehlende Metadaten werden durch Standardwerte ersetzt.

### Problem: Cover wird nicht eingebettet
**Lösung**: Stellen Sie sicher, dass Cover-Art heruntergeladen wurde (MusicBrainz). Format muss Cover-Einbettung unterstützen (alle außer WAV).

### Problem: Dateiname zu lang
**Lösung**: Verwenden Sie kürzere Templates oder kürzen Sie die Metadaten.
