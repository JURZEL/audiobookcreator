#!/bin/bash

# CD Ripper Pro - Start Script

echo "=========================================="
echo "  CD Ripper Pro - Flutter Frontend"
echo "=========================================="
echo ""

# Prüfe ob cdparanoia installiert ist
if ! command -v cdparanoia &> /dev/null; then
    echo "⚠️  WARNUNG: cdparanoia ist nicht installiert!"
    echo "   Installieren Sie es mit:"
    echo "   Ubuntu/Debian: sudo apt-get install cdparanoia"
    echo "   Fedora/RHEL: sudo dnf install cdparanoia"
    echo "   Arch Linux: sudo pacman -S cdparanoia"
    echo ""
fi

# Prüfe ob ffmpeg installiert ist
if ! command -v ffmpeg &> /dev/null; then
    echo "⚠️  WARNUNG: ffmpeg ist nicht installiert!"
    echo "   Installieren Sie es mit:"
    echo "   Ubuntu/Debian: sudo apt-get install ffmpeg"
    echo "   Fedora/RHEL: sudo dnf install ffmpeg"
    echo "   Arch Linux: sudo pacman -S ffmpeg"
    echo ""
fi

# Prüfe ob Flutter installiert ist
if ! command -v flutter &> /dev/null; then
    echo "❌ FEHLER: Flutter ist nicht installiert!"
    echo "   Installieren Sie Flutter von: https://flutter.dev"
    exit 1
fi

echo "✅ Starte CD Ripper Pro..."
echo ""

# Starte die Flutter-App
flutter run -d linux

