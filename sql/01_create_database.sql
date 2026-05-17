-- ============================================================
-- Beleptető rendszer adatbázis létrehozása - MS SQL Server
-- PowerBuilder 12.5 kliens számára
-- ============================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'Belepteto')
BEGIN
    CREATE DATABASE Belepteto;
END
GO

USE Belepteto;
GO

-- ------------------------------------------------------------
-- Felhasználók tábla
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.felhasznalok', N'U') IS NOT NULL
    DROP TABLE dbo.felhasznalok;
GO

CREATE TABLE dbo.felhasznalok
(
    felhasznalo_id            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    felhasznalo_nev           NVARCHAR(50)  NOT NULL UNIQUE,
    jelszo_hash               VARCHAR(64)   NOT NULL,    -- SHA2_256 hex
    teljes_nev                NVARCHAR(100) NULL,
    email                     NVARCHAR(100) NULL,
    szerepkor                 NVARCHAR(20)  NOT NULL DEFAULT 'USER',
    aktiv                     BIT           NOT NULL DEFAULT 1,
    tiltott                   BIT           NOT NULL DEFAULT 0,
    sikertelen_probalkozasok  INT           NOT NULL DEFAULT 0,
    letrehozva                DATETIME      NOT NULL DEFAULT GETDATE(),
    utolso_belepes            DATETIME      NULL,
    tiltas_idopont            DATETIME      NULL
);
GO

CREATE INDEX IX_felhasznalok_nev ON dbo.felhasznalok(felhasznalo_nev);
GO

-- ------------------------------------------------------------
-- Belépési napló (audit trail)
-- ------------------------------------------------------------
IF OBJECT_ID(N'dbo.belepes_naplo', N'U') IS NOT NULL
    DROP TABLE dbo.belepes_naplo;
GO

CREATE TABLE dbo.belepes_naplo
(
    naplo_id          BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    felhasznalo_nev   NVARCHAR(50)  NOT NULL,
    esemeny           NVARCHAR(50)  NOT NULL,   -- BELEPES_OK, BELEPES_HIBAS_JELSZO, KILEPES, FIOK_TILTVA
    megjegyzes        NVARCHAR(255) NULL,
    esemeny_idopont   DATETIME      NOT NULL DEFAULT GETDATE(),
    gep_nev           NVARCHAR(100) NULL
);
GO

CREATE INDEX IX_belepes_naplo_felhasznalo ON dbo.belepes_naplo(felhasznalo_nev, esemeny_idopont DESC);
GO

-- ------------------------------------------------------------
-- Teszt adatok - admin / Admin123!
-- jelszó hash: SHA2_256('Admin123!')
-- ------------------------------------------------------------
INSERT INTO dbo.felhasznalok
       ( felhasznalo_nev, jelszo_hash, teljes_nev, email, szerepkor )
VALUES ( 'admin',
         UPPER( CONVERT( VARCHAR(64), HASHBYTES('SHA2_256', 'Admin123!'), 2 ) ),
         'Rendszergazda', 'admin@example.com', 'ADMIN' ),
       ( 'teszt',
         UPPER( CONVERT( VARCHAR(64), HASHBYTES('SHA2_256', 'Teszt123!'), 2 ) ),
         'Teszt Elemér', 'teszt@example.com', 'USER' );
GO

PRINT 'Beleptető adatbázis sikeresen létrehozva.';
PRINT 'Teszt felhasználók: admin / Admin123! és teszt / Teszt123!';
GO
