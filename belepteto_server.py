#!/usr/bin/env python3
"""
Beleptető rendszer - futtatható referencia-implementáció.

A PowerBuilder 12.5 alkalmazás logikájának 1:1 megfelelője Python stdlib-bel
és SQLite-tal. Cél: a w_login.srw / w_main.srw viselkedését kipróbálni
Windows + PowerBuilder + MS SQL Server telepítés nélkül.

Indítás:
    python3 belepteto_server.py

Majd nyisd meg böngészőben: http://localhost:8080
Teszt fiókok: admin / Admin123!   és   teszt / Teszt123!
"""

import hashlib
import http.server
import json
import os
import secrets
import socketserver
import sqlite3
import threading
from datetime import datetime
from http import HTTPStatus
from urllib.parse import urlparse

DB_PATH = os.path.join(os.path.dirname(__file__), "belepteto.sqlite")
HTML_PATH = os.path.join(os.path.dirname(__file__), "belepteto_preview.html")
PORT = int(os.environ.get("PORT", "8080"))
MAX_PROBALKOZAS = 3

# Egyszerű in-memory session tár - process élettartamára
SESSIONS = {}
SESSION_LOCK = threading.Lock()


def jelszo_hash(jelszo: str) -> str:
    """SHA-256 hex uppercase - ugyanaz mint az MS SQL HASHBYTES('SHA2_256', ...)."""
    return hashlib.sha256(jelszo.encode("utf-8")).hexdigest().upper()


def db_connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def db_init() -> None:
    """Létrehozza a táblákat és beszúrja a teszt felhasználókat, ha még nincsenek."""
    with db_connect() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS felhasznalok (
                felhasznalo_id           INTEGER PRIMARY KEY AUTOINCREMENT,
                felhasznalo_nev          TEXT NOT NULL UNIQUE,
                jelszo_hash              TEXT NOT NULL,
                teljes_nev               TEXT,
                email                    TEXT,
                szerepkor                TEXT NOT NULL DEFAULT 'USER',
                aktiv                    INTEGER NOT NULL DEFAULT 1,
                tiltott                  INTEGER NOT NULL DEFAULT 0,
                sikertelen_probalkozasok INTEGER NOT NULL DEFAULT 0,
                letrehozva               TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                utolso_belepes           TEXT,
                tiltas_idopont           TEXT
            );

            CREATE TABLE IF NOT EXISTS belepes_naplo (
                naplo_id        INTEGER PRIMARY KEY AUTOINCREMENT,
                felhasznalo_nev TEXT NOT NULL,
                esemeny         TEXT NOT NULL,
                megjegyzes      TEXT,
                esemeny_idopont TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                gep_nev         TEXT
            );

            CREATE INDEX IF NOT EXISTS ix_naplo_felh
                ON belepes_naplo(felhasznalo_nev, esemeny_idopont DESC);
            """
        )

        cur = conn.execute("SELECT COUNT(*) AS c FROM felhasznalok")
        if cur.fetchone()["c"] == 0:
            conn.executemany(
                "INSERT INTO felhasznalok (felhasznalo_nev, jelszo_hash, teljes_nev, email, szerepkor) "
                "VALUES (?, ?, ?, ?, ?)",
                [
                    ("admin", jelszo_hash("Admin123!"), "Rendszergazda", "admin@example.com", "ADMIN"),
                    ("teszt", jelszo_hash("Teszt123!"), "Teszt Elemér", "teszt@example.com", "USER"),
                ],
            )


def naplozas(felhasznalo: str, esemeny: str, megjegyzes: str, gep_nev: str = "") -> None:
    with db_connect() as conn:
        conn.execute(
            "INSERT INTO belepes_naplo (felhasznalo_nev, esemeny, megjegyzes, gep_nev) "
            "VALUES (?, ?, ?, ?)",
            (felhasznalo, esemeny, megjegyzes, gep_nev),
        )


def hitelesites(felhasznalo: str, jelszo: str, gep_nev: str) -> dict:
    """A wf_hitelesites PowerBuilder függvény megfelelője."""
    with db_connect() as conn:
        row = conn.execute(
            "SELECT felhasznalo_id, jelszo_hash, teljes_nev, szerepkor, aktiv, tiltott, sikertelen_probalkozasok "
            "FROM felhasznalok WHERE felhasznalo_nev = ?",
            (felhasznalo,),
        ).fetchone()

    if row is None:
        naplozas(felhasznalo, "BELEPES_HIBAS_FELHASZNALO", "Ismeretlen felhasználónév", gep_nev)
        return {"ok": False, "kod": 0, "uzenet": "Hibás felhasználónév vagy jelszó!"}

    if row["tiltott"] == 1 or row["aktiv"] == 0:
        naplozas(felhasznalo, "BELEPES_TILTOTT", "Tiltott fiók próbálkozott bejelentkezni", gep_nev)
        return {
            "ok": False,
            "kod": -2,
            "uzenet": "A felhasználói fiók le van tiltva! Kérjük, vegye fel a kapcsolatot a rendszergazdával.",
        }

    if row["jelszo_hash"].upper() != jelszo_hash(jelszo):
        uj_szam = row["sikertelen_probalkozasok"] + 1
        tiltani = uj_szam >= MAX_PROBALKOZAS

        with db_connect() as conn:
            if tiltani:
                conn.execute(
                    "UPDATE felhasznalok SET sikertelen_probalkozasok = ?, tiltott = 1, tiltas_idopont = ? "
                    "WHERE felhasznalo_id = ?",
                    (uj_szam, datetime.now().isoformat(timespec="seconds"), row["felhasznalo_id"]),
                )
            else:
                conn.execute(
                    "UPDATE felhasznalok SET sikertelen_probalkozasok = ? WHERE felhasznalo_id = ?",
                    (uj_szam, row["felhasznalo_id"]),
                )

        naplozas(
            felhasznalo,
            "BELEPES_HIBAS_JELSZO",
            f"Hibás jelszó próbálkozás #{uj_szam}",
            gep_nev,
        )

        if tiltani:
            naplozas(
                felhasznalo,
                "FIOK_TILTVA",
                f"Automatikus tiltás {MAX_PROBALKOZAS} sikertelen próbálkozás után",
                gep_nev,
            )
            return {
                "ok": False,
                "kod": -2,
                "uzenet": (
                    "Túl sok sikertelen bejelentkezési próbálkozás! "
                    "A felhasználói fiók letiltásra került."
                ),
            }

        return {
            "ok": False,
            "kod": 0,
            "uzenet": "Hibás felhasználónév vagy jelszó!",
            "hatra": MAX_PROBALKOZAS - uj_szam,
        }

    # Sikeres
    most = datetime.now().isoformat(timespec="seconds")
    with db_connect() as conn:
        conn.execute(
            "UPDATE felhasznalok SET utolso_belepes = ?, sikertelen_probalkozasok = 0 "
            "WHERE felhasznalo_id = ?",
            (most, row["felhasznalo_id"]),
        )
    naplozas(felhasznalo, "BELEPES_OK", "Sikeres bejelentkezés", gep_nev)

    return {
        "ok": True,
        "kod": 1,
        "felhasznalo": felhasznalo,
        "teljes_nev": row["teljes_nev"],
        "szerepkor": row["szerepkor"],
        "belepes_idopont": most,
    }


def session_create(adat: dict) -> str:
    token = secrets.token_urlsafe(24)
    with SESSION_LOCK:
        SESSIONS[token] = adat
    return token


def session_get(token: str) -> dict | None:
    with SESSION_LOCK:
        return SESSIONS.get(token)


def session_drop(token: str) -> dict | None:
    with SESSION_LOCK:
        return SESSIONS.pop(token, None)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):  # csendesebb log
        print(f"[{self.log_date_time_string()}] {self.address_string()} - {format % args}")

    # ---- segédfüggvények ----
    def _send_json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return {}

    def _token(self) -> str | None:
        cookie = self.headers.get("Cookie", "")
        for part in cookie.split(";"):
            k, _, v = part.strip().partition("=")
            if k == "belepteto_sid":
                return v
        return None

    # ---- GET ----
    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            self._serve_html()
        elif path == "/api/me":
            token = self._token()
            adat = session_get(token) if token else None
            if adat:
                self._send_json(HTTPStatus.OK, {"bejelentkezve": True, **adat})
            else:
                self._send_json(HTTPStatus.OK, {"bejelentkezve": False})
        elif path == "/api/naplo":
            token = self._token()
            if not session_get(token):
                self._send_json(HTTPStatus.UNAUTHORIZED, {"hiba": "Nincs bejelentkezve"})
                return
            with db_connect() as conn:
                rows = conn.execute(
                    "SELECT felhasznalo_nev, esemeny, megjegyzes, esemeny_idopont, gep_nev "
                    "FROM belepes_naplo ORDER BY naplo_id DESC LIMIT 50"
                ).fetchall()
            self._send_json(HTTPStatus.OK, {"naplo": [dict(r) for r in rows]})
        else:
            self.send_error(HTTPStatus.NOT_FOUND, "Nincs ilyen útvonal")

    # ---- POST ----
    def do_POST(self):
        path = urlparse(self.path).path
        if path == "/api/login":
            data = self._read_json()
            felh = (data.get("felhasznalo") or "").strip()
            jelszo = data.get("jelszo") or ""
            if not felh or not jelszo:
                self._send_json(HTTPStatus.BAD_REQUEST, {"ok": False, "uzenet": "Hiányzó felhasználónév vagy jelszó."})
                return
            gep = self.headers.get("User-Agent", "")[:80]
            eredmeny = hitelesites(felh, jelszo, gep)
            if eredmeny.get("ok"):
                token = session_create(
                    {
                        "felhasznalo": eredmeny["felhasznalo"],
                        "teljes_nev": eredmeny["teljes_nev"],
                        "szerepkor": eredmeny["szerepkor"],
                        "belepes_idopont": eredmeny["belepes_idopont"],
                    }
                )
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header(
                    "Set-Cookie",
                    f"belepteto_sid={token}; Path=/; HttpOnly; SameSite=Lax",
                )
                body = json.dumps(eredmeny, ensure_ascii=False).encode("utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            else:
                self._send_json(HTTPStatus.OK, eredmeny)
        elif path == "/api/logout":
            token = self._token()
            adat = session_drop(token) if token else None
            if adat:
                naplozas(adat["felhasznalo"], "KILEPES", "Felhasználó kijelentkezett",
                         self.headers.get("User-Agent", "")[:80])
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Set-Cookie", "belepteto_sid=; Path=/; Max-Age=0")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        elif path == "/api/reset":
            # Fejlesztői segéd: feloldja az összes tiltást, nullázza a próbálkozásokat.
            with db_connect() as conn:
                conn.execute("UPDATE felhasznalok SET tiltott = 0, sikertelen_probalkozasok = 0, tiltas_idopont = NULL")
            self._send_json(HTTPStatus.OK, {"ok": True, "uzenet": "Minden fiók feloldva."})
        else:
            self.send_error(HTTPStatus.NOT_FOUND, "Nincs ilyen útvonal")

    def _serve_html(self) -> None:
        try:
            with open(HTML_PATH, "rb") as f:
                body = f.read()
        except FileNotFoundError:
            self.send_error(HTTPStatus.NOT_FOUND, "HTML hiányzik")
            return
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> None:
    db_init()
    print(f"Beleptető szerver indul: http://localhost:{PORT}")
    print(f"Adatbázis: {DB_PATH}")
    print("Teszt fiókok:  admin / Admin123!   és   teszt / Teszt123!")
    print("Leállítás: Ctrl+C")
    with ThreadingServer(("0.0.0.0", PORT), Handler) as srv:
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            print("\nLeállítva.")


if __name__ == "__main__":
    main()
