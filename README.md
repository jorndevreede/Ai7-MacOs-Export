# AI07 macOS Export

Native macOS-prototype dat opnames van een AI07/MindRec-recorder via Bluetooth LE downloadt, de originele AAC bewaart en echte MP3-bestanden maakt. Geen MindRec-account nodig tijdens de export.

## Status

Getest op Apple Silicon, macOS 15.6.1, één AI07 met MindRec-firmware V1.0.0, op 11 oktober 2026. Alle 11 niet-lege opnames zijn volledig over BLE geëxporteerd. Dit bewijst geen compatibiliteit met alle apparaten die als AI07 worden verkocht.

## Gebruik

Zet de recorder aan, sluit MindRec op telefoon en Mac af, open de app en geef zo nodig macOS Bluetooth-toestemming. Kies **Opnames ophalen**, daarna **Alles naar MP3**. **Toon MP3’s** opent de uitvoermap. Sluit de app als je MindRec weer wilt gebruiken.

Opnames blijven op de recorder staan. De app bewaart originele AAC-bestanden, controleert de exacte bytegrootte, converteert lokaal met FFmpeg, decodeert de MP3 ter controle en bewaart SHA-256-controlewaarden. Een herhaalde export slaat identieke, gecontroleerde bestanden over. Bestaande bestanden zonder passend controlelog worden niet overschreven.

## Bouwen en configureren

Vereist macOS, Xcode Command Line Tools en FFmpeg met libmp3lame op `/opt/homebrew/bin/ffmpeg`. Vervang `YOUR_AI07_SERIAL` in `AI07Export.m` door het A/N-nummer op je eigen recorder (driemaal kort drukken toont de identificatie). Voer daarna `sh build.sh` uit. De app komt in `dist/AI07 Export.app`.

De broncode in deze repository is ontdaan van persoonlijke apparaatidentificatie. De reeds geteste lokale app heeft de juiste identificatie al ingesteld. De build is lokaal ad-hoc ondertekend, niet genotariseerd. De uitvoermap staat naast de app: plaats die daarom in een beschrijfbare map.

## Bestanden

- `AI07Export.m`: volledige Cocoa/CoreBluetooth-app.
- `Info.plist`: appmetadata en Bluetooth-toelichting.
- `build.sh`: reproduceerbare lokale build.
- `PROTOCOL.md`: waargenomen protocol en referenties.
- `VALIDATION.md`: uitgevoerde praktijktests en beperkingen.

## Grenzen

Geen WiFi-overdracht of automatische StenoAI-import. De app gebruikt een reeds aanwezige lokale FFmpeg-installatie. Grote downloads worden in het geheugen gebufferd. Bij een omzetfout kunnen tijdelijke bestanden voor onderzoek blijven staan. Een onderbroken download begint opnieuw; voltooide exports blijven behouden. USB-mountproblemen worden niet door deze app opgelost.

Drie keer drukken toont volgens de meegeleverde handleiding MAC/A/N; dit is geen beschreven USB-schakelaar. Pocket Libre gebruikt een ander protocol en is geen rechtstreeks compatibele oplossing voor het geteste apparaat.

Er staan geen audio-opnames, transcripties, accountgegevens, persoonlijke apparaatcodes of software van MindRec in deze repository. Alle code hier is lokaal voor dit prototype geschreven; protocolgedrag is met de eigen recorder getest.
