# Disc-ID Berechnung - Problemlösung

## Das Problem

Die App hat die MusicBrainz Disc-ID falsch berechnet:
- **Erwartet (korrekt)**: `DBnmKjD41hEJBY.GfwAB0YxOwJI-`
- **Vorher (falsch)**: `JGlmiKWbkdhpVbENfKkJNnr37e8-`

## Ursache

Die CD in diesem Fall ist eine **Multi-Session-CD** mit:
- 13 Audio-Tracks (Tracks 1-13)
- 1 Data-Track (Track 14)

Das Tool `cd-discid --musicbrainz` hat fälschlicherweise den Data-Track in die Berechnung einbezogen:
- Verwendet Track 14 (der ein Data-Track ist)
- Lead-Out bei Sektor 244407 (nach dem Data-Track)

Gemäß MusicBrainz-Spezifikation sollen **nur Audio-Tracks** für die Disc-ID verwendet werden.

## Lösung

Die App verwendet jetzt eine Prioritätsliste für TOC-Datenquellen:

### 1. Python libdiscid (Priorität 1)
```bash
python3 -c "import discid; disc = discid.read('/dev/cdrom'); ..."
```
- **Vorteil**: Ignoriert Data-Tracks automatisch und korrekt
- **Ergebnis**: 13 Tracks, Lead-Out bei 208952
- **Disc-ID**: `DBnmKjD41hEJBY.GfwAB0YxOwJI-` ✓

### 2. cdparanoia (Fallback)
```bash
cdparanoia -d /dev/cdrom -Q
```
- Zeigt nur Audio-Tracks ("audio tracks only")
- Lead-Out wird aus letztem Track + 150 berechnet
- Relative Sektoren (Start bei 0) werden in absolute umgewandelt (+150)

## Änderungen im Code

### `cd_service.dart` - `_readTOC()`
- Verwendet zuerst Python libdiscid
- Falls nicht verfügbar: Fallback auf cdparanoia
- Entfernt: Fehlerhafte Verwendung von `cd-discid --musicbrainz`

### `_parseCdparanoiaOutput()`
- Berechnet Lead-Out korrekt: `lastTrack.endSector + 150`
- Gibt firstTrack, lastTrack und leadOut zurück

### `_calculateDiscId()` - Fallback-Pfad
- Vereinfachte Logik: cdparanoia liefert immer relative Sektoren
- Immer +150 auf alle Offsets addieren (Lead-in)
- Kein komplexes Auto-Detection mehr

## Testen

```bash
# 1. Mit Python libdiscid (beste Methode)
python3 -c "import discid; disc = discid.read('/dev/cdrom'); print(disc.id)"

# 2. Mit der Test-Datei
dart test_discid.dart

# Erwartet: DBnmKjD41hEJBY.GfwAB0YxOwJI-
```

## Voraussetzungen

Für optimale Ergebnisse sollte installiert sein:
```bash
# Fedora/RHEL
sudo dnf install python3-discid

# Debian/Ubuntu  
sudo apt install python3-discid

# Arch
sudo pacman -S python-discid
```

Falls Python discid nicht verfügbar ist, funktioniert cdparanoia als Fallback.

## Referenzen

- [MusicBrainz Disc ID Calculation](https://musicbrainz.org/doc/Disc_ID_Calculation)
- [libdiscid auf GitHub](https://github.com/metabrainz/libdiscid)
- Multi-Session CDs: Data-Tracks werden ignoriert (nur Audio-Tracks zählen)
