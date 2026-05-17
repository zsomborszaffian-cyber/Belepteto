# Beleptető rendszer — PowerBuilder 12.5 + MS SQL Server

Egyszerű, mégis teljes értékű beléptető (login) alkalmazás PowerBuilder 12.5 Classic környezetben, Microsoft SQL Server adatbázishoz.

## Funkciók

- Felhasználónév + jelszó alapú bejelentkezés
- Jelszavak SHA-256 hash-elve tárolva (MS SQL `HASHBYTES` függvény)
- 3 sikertelen próbálkozás után automatikus fióktiltás
- Teljes körű audit napló (`belepes_naplo` tábla)
- Szerepkörök (ADMIN / USER)
- Adatbázis-kapcsolat paraméterek INI fájlból
- Magyar nyelvű felület és üzenetek

## Projektfájlok

| Fájl | Leírás |
|------|--------|
| `belepteto.pbw` | PowerBuilder workspace |
| `belepteto.pbt` | Target fájl |
| `belepteto.sra` | Application objektum + globális változók + DB csatlakozás |
| `w_login.srw` | Bejelentkezési ablak (hitelesítés, naplózás, tiltás) |
| `w_main.srw` | Sikeres belépés utáni fő ablak |
| `belepteto.ini` | Adatbázis-kapcsolat konfigurációja |
| `sql/01_create_database.sql` | Adatbázis-séma + teszt adatok |

## Telepítés

1. Futtasd a `sql/01_create_database.sql` szkriptet az MS SQL Serveren (SQL Server Management Studio vagy `sqlcmd`).
2. Nyisd meg a `belepteto.pbw` workspace-t PowerBuilder 12.5 Classic-ban.
3. Állítsd be a `belepteto.ini` `[Database]` szekciójában a szerver nevét és a hitelesítést.
4. Build / Deploy → futtasd az alkalmazást.

## Teszt felhasználók

| Felhasználó | Jelszó | Szerepkör |
|-------------|--------|-----------|
| `admin` | `Admin123!` | ADMIN |
| `teszt` | `Teszt123!` | USER |

## Biztonsági megjegyzés

Éles használat előtt mindenképp:
- Cseréld le a teszt jelszavakat.
- Használj Windows hitelesítést (`Integrated Security=SSPI`) SQL Server login helyett.
- Titkosítsd az `belepteto.ini` jelszó mezejét, vagy tárolj `Trusted_Connection=yes` beállítást.
- Adj jogosultságot a `felhasznalok` és `belepes_naplo` táblákra csak a szükséges szerepkörnek.
