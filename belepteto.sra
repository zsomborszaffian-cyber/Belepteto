$PBExportHeader$belepteto.sra
$PBExportComments$Beleptető alkalmazás fő application objektum
forward
global type belepteto from application
end type
global transaction sqlca
global dynamicdescriptionarea sqlda
global dynamicstagingarea sqlsa
global error error
global message message
end forward

global variables
// Globális változók a bejelentkezett felhasználó adataival
string  gs_felhasznalo_nev
long    gl_felhasznalo_id
string  gs_szerepkor
datetime gdt_belepes_idopont
end variables

global type belepteto from application
string appname = "belepteto"
string applicationname = "Beleptető rendszer"
end type

global belepteto belepteto

on belepteto.create
appname = "belepteto"
message = create message
sqlca = create transaction
sqlda = create dynamicdescriptionarea
sqlsa = create dynamicstagingarea
error = create error
end on

on belepteto.destroy
destroy( sqlca )
destroy( sqlda )
destroy( sqlsa )
destroy( error )
destroy( message )
end on

event open;
/*
   Az alkalmazás indítása - megnyitja a bejelentkezési ablakot.
   Az adatbáziskapcsolat beállításait a belepteto.ini fájlból olvassa.
*/
string ls_ini_file

ls_ini_file = "belepteto.ini"

// Adatbázis kapcsolat paraméterek beolvasása az INI fájlból
SQLCA.DBMS         = ProfileString( ls_ini_file, "Database", "DBMS",         "SNC SQL Native Client(OLE DB)" )
SQLCA.ServerName   = ProfileString( ls_ini_file, "Database", "ServerName",   "localhost" )
SQLCA.LogId        = ProfileString( ls_ini_file, "Database", "LogId",        "sa" )
SQLCA.LogPass      = ProfileString( ls_ini_file, "Database", "LogPassword",  "" )
SQLCA.Database     = ProfileString( ls_ini_file, "Database", "Database",     "Belepteto" )
SQLCA.AutoCommit   = False
SQLCA.DBParm       = ProfileString( ls_ini_file, "Database", "DBParm",       "Provider='SQLNCLI11',DataSource='localhost',Database='Belepteto'" )

// A bejelentkezési ablak megnyitása - itt történik a felhasználó hitelesítése
Open( w_login )
end event
