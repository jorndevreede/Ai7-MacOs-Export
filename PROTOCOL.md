# AI07 BLE-protocol


Advertisement service A0A0; GATT D0D0; schrijf naar D0D1. Meldingen op D0D3 bevatten commando-antwoorden; D0D4 bevat onbewerkte audiobytes. D0D2 wordt ook aangemeld, zonder opnamecommando’s te versturen.

Uitgaand frame: CA AC, commando, payloadlengte, payload. Antwoord: AC CA, commando, payloadlengte, payload.

- 01 zonder payload: apparaatinfo.
- 02 zonder payload: bestandslijst. Recordpayload: status 00, 14 ASCII-cijfers (identificatie), 4 bytes grootte big-endian, 4 bytes duur big-endian, 1 byte type. Einde: payload 02.
- 08: 14 ASCII-cijfers plus vier nulbytes (offset). Startantwoord: 00 plus 4-byte grootte. Audio op D0D4. Einde: antwoordpayload 02. Exacte bytecontrole voor opslaan.

Alleen bovenstaande lees-/downloadfuncties worden gebruikt. Geen firmwarewijziging, reset- of opnamecommando’s. Versie 0.2 voegt expliciet bevestigde verwijdering toe: wire 0x0a, payload exact de 14 ASCII-cijfers van het bestands-ID. Het commando wordt niet blind herhaald; alleen afwezigheid in een verse complete lijst bevestigt verwijderen. De knop stuurt niets voordat de gebruiker bevestigt.

Broncode: `Sources/`.

## Referenties

- MindRec: https://apps.apple.com/us/app/mindrec/id6748944493
- Vadiutor: https://play.google.com/store/apps/details?id=com.aifuture.vadiutor
- Pocket Libre: https://github.com/shahcolate/pocket-libre
- Meegeleverde handleiding en screenshots; live tests op deze Mac op 11 oktober 2026.
