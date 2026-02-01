import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  // Korrekte Daten von libdiscid (nur Audio-Tracks)
  final data = "1 13 208952 150 15205 30947 46145 60542 79092 94757 108545 125540 146267 163055 177547 194932";
  final parts = data.split(' ');
  
  final firstTrack = int.parse(parts[0]);
  final lastTrack = int.parse(parts[1]);
  final leadOut = int.parse(parts[2]);
  
  final offsets = <int>[];
  for (int i = 3; i < parts.length; i++) {
    offsets.add(int.parse(parts[i]));
  }
  
  print('First Track: $firstTrack');
  print('Last Track: $lastTrack');
  print('Lead-Out: $leadOut');
  print('Offsets: $offsets');
  print('Anzahl Offsets: ${offsets.length}');
  
  // MusicBrainz Disc ID Berechnung
  final buffer = StringBuffer();
  buffer.write(firstTrack.toRadixString(16).toUpperCase().padLeft(2, '0'));
  buffer.write(lastTrack.toRadixString(16).toUpperCase().padLeft(2, '0'));
  
  // 100 Offsets: Zuerst Lead-Out, dann die Track-Offsets
  buffer.write(leadOut.toRadixString(16).toUpperCase().padLeft(8, '0'));
  for (var i = 0; i < 99; i++) {
    final offset = i < offsets.length ? offsets[i] : 0;
    buffer.write(offset.toRadixString(16).toUpperCase().padLeft(8, '0'));
  }
  
  final hexString = buffer.toString();
  print('\nHex String (first 100 chars): ${hexString.substring(0, 100)}');
  print('Hex String length: ${hexString.length}');
  
  // SHA-1 Hash
  final bytes = utf8.encode(hexString);
  final sha = sha1.convert(bytes);
  print('\nSHA-1: ${sha.toString()}');
  print('SHA-1 bytes: ${sha.bytes}');
  
  // Standard Base64
  final base64Standard = base64.encode(sha.bytes);
  print('\nBase64 (Standard): $base64Standard');
  
  // MusicBrainz Base64 (+ → ., / → _, = → -)
  final discId = base64Standard
      .replaceAll('+', '.')
      .replaceAll('/', '_')
      .replaceAll('=', '-');
  
  print('DiscID (MusicBrainz): $discId');
  print('\nErwartet: DBnmKjD41hEJBY.GfwAB0YxOwJI-');
  print('Match: ${discId == "DBnmKjD41hEJBY.GfwAB0YxOwJI-"}');
}
