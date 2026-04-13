# Ny Mappe (7) — Kodesignering & Release

## Nye funksjoner (v3.4)

### Global hurtigtast
- **⌥Space** (Option + Space) viser/skjuler panelet fra hvilken som helst app
- Bare bygg på nytt med `./build.sh` så funker det

### Build-moduser

| Kommando | Hva den gjør |
|----------|-------------|
| `./build.sh` | Bygg + installer lokalt (som før) |
| `./build.sh --sign` | Bygg + kodesigner + installer |
| `./build.sh --release` | Bygg + kodesigner + notariser + lager `.dmg` |

---

## Slik setter du opp kodesignering

### Steg 1: Opprett sertifikat

1. Åpne **Xcode** → Settings → Accounts
2. Klikk ditt team → **Manage Certificates**
3. Trykk `+` → velg **"Developer ID Application"**

### Steg 2: Finn signeringsnavnet ditt

Kjør i Terminal:

```bash
security find-identity -v -p codesigning
```

Du får noe som:

```
"Developer ID Application: Victoria Haugnes (ABC123XYZ)"
```

Kopier hele denne strengen.

### Steg 3: Lag app-spesifikt passord

1. Gå til [appleid.apple.com](https://appleid.apple.com)
2. Logg inn → **Logg inn og sikkerhet** → **Appspesifikke passord**
3. Trykk `+` og lag et nytt passord (f.eks. kall det "notarytool")
4. Kopier passordet (format: `xxxx-xxxx-xxxx-xxxx`)

### Steg 4: Finn Team ID

- Gå til [developer.apple.com/account](https://developer.apple.com/account) → **Membership Details**
- Kopier din **Team ID** (10 tegn, f.eks. `ABC123XYZ`)

---

## Kjør release-build

Sett miljøvariabler og kjør:

```bash
export SIGNING_IDENTITY="Developer ID Application: Victoria Haugnes (ABC123XYZ)"
export APPLE_ID="din@email.com"
export TEAM_ID="ABC123XYZ"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"

./build.sh --release
```

Da skjer dette automatisk:

1. Bygger universal binary (Intel + Apple Silicon)
2. Kodesignerer `.app`-en
3. Lager `NyMappe7-v3.4.dmg`
4. Sender til Apple for notarisering (tar 1-5 min)
5. Stapler notariseringskvittering til DMG-en

Resultat: En `.dmg` som hvem som helst kan åpne **uten** "ukjent utvikler"-advarselen.

---

## Tips

- Du kan også lagre variablene i en `.env`-fil og source den: `source .env && ./build.sh --release`
- For lokal testing holder det med `./build.sh` (ingen signering nødvendig)
- `./build.sh --sign` er nyttig hvis du bare vil teste signeringen uten å lage DMG
