$PBExportHeader$w_login.srw
$PBExportComments$Bejelentkezési ablak MS SQL adatbázishoz
forward
global type w_login from window
end type
type st_cim from statictext within w_login
end type
type st_felhasznalo from statictext within w_login
end type
type st_jelszo from statictext within w_login
end type
type sle_felhasznalo from singlelineedit within w_login
end type
type sle_jelszo from singlelineedit within w_login
end type
type cb_belepes from commandbutton within w_login
end type
type cb_megse from commandbutton within w_login
end type
type st_status from statictext within w_login
end type
end forward

global type w_login from window
integer width = 1829
integer height = 1180
boolean titlebar = true
string title = "Belepteto rendszer - Bejelentkezes"
boolean controlmenu = true
windowtype windowtype = response!
long backcolor = 67108864
string icon = "AppIcon!"
boolean center = true
st_cim st_cim
st_felhasznalo st_felhasznalo
st_jelszo st_jelszo
sle_felhasznalo sle_felhasznalo
sle_jelszo sle_jelszo
cb_belepes cb_belepes
cb_megse cb_megse
st_status st_status
end type
global w_login w_login

type variables
// Sikertelen próbálkozások számlálója - 3 után tiltjuk a felhasználót
integer ii_sikertelen_probalkozas = 0
integer ii_max_probalkozas = 3
end variables

forward prototypes
public function string wf_jelszo_hash( string as_jelszo )
public function integer wf_hitelesites( string as_felhasznalo, string as_jelszo, ref string as_hibauzenet )
public subroutine wf_naplozas( string as_felhasznalo, string as_esemeny, string as_megjegyzes )
end prototypes

public function string wf_jelszo_hash( string as_jelszo );
/*
   Egyszerű SHA-256 hash az MS SQL HASHBYTES függvényével.
   A jelszót nem clear-textben tároljuk az adatbázisban.
   Visszatérési érték: hexadecimális hash string nagybetűkkel.
*/
string ls_hash

// Az MS SQL HASHBYTES segítségével kiszámoljuk a hash-t a szerver oldalon
SELECT UPPER( CONVERT( VARCHAR(64), HASHBYTES('SHA2_256', :as_jelszo), 2 ) )
  INTO :ls_hash
  FROM dual_tabla
 USING SQLCA;

If SQLCA.SQLCode <> 0 Then
    // Ha a dual_tabla nincs, akkor sima SELECT
    SELECT UPPER( CONVERT( VARCHAR(64), HASHBYTES('SHA2_256', :as_jelszo), 2 ) )
      INTO :ls_hash
      USING SQLCA;
End If

Return ls_hash
end function

public function integer wf_hitelesites( string as_felhasznalo, string as_jelszo, ref string as_hibauzenet );
/*
   Felhasználó hitelesítése az adatbázis ellenében.
   Visszatérési értékek:
      1 = sikeres bejelentkezés
      0 = hibás felhasználónév vagy jelszó
     -1 = adatbázis hiba
     -2 = a felhasználó tiltva van
*/
string  ls_hash_db, ls_hash_input, ls_szerepkor
long    ll_id
integer li_aktiv, li_tiltott

ls_hash_input = wf_jelszo_hash( as_jelszo )

If SQLCA.SQLCode <> 0 Then
    as_hibauzenet = "Adatbázis hiba a jelszó hash számításnál: " + SQLCA.SQLErrText
    Return -1
End If

SELECT felhasznalo_id, jelszo_hash, szerepkor, aktiv, tiltott
  INTO :ll_id, :ls_hash_db, :ls_szerepkor, :li_aktiv, :li_tiltott
  FROM felhasznalok
 WHERE felhasznalo_nev = :as_felhasznalo
 USING SQLCA;

If SQLCA.SQLCode = 100 Then
    // Nincs ilyen felhasználó
    as_hibauzenet = "Hibás felhasználónév vagy jelszó!"
    Return 0
End If

If SQLCA.SQLCode < 0 Then
    as_hibauzenet = "Adatbázis hiba: " + SQLCA.SQLErrText
    Return -1
End If

If li_tiltott = 1 Or li_aktiv = 0 Then
    as_hibauzenet = "A felhasználói fiók le van tiltva! Kérjük, vegye fel a kapcsolatot a rendszergazdával."
    Return -2
End If

If Upper( ls_hash_db ) <> Upper( ls_hash_input ) Then
    as_hibauzenet = "Hibás felhasználónév vagy jelszó!"
    Return 0
End If

// Sikeres - eltároljuk a felhasználó adatait a globális változókban
gs_felhasznalo_nev   = as_felhasznalo
gl_felhasznalo_id    = ll_id
gs_szerepkor         = ls_szerepkor
gdt_belepes_idopont  = DateTime( Today(), Now() )

// Utolsó bejelentkezés frissítése
UPDATE felhasznalok
   SET utolso_belepes = GETDATE(),
       sikertelen_probalkozasok = 0
 WHERE felhasznalo_id = :ll_id
 USING SQLCA;
COMMIT USING SQLCA;

Return 1
end function

public subroutine wf_naplozas( string as_felhasznalo, string as_esemeny, string as_megjegyzes );
/*
   Audit napló bejegyzés beszúrása.
   Minden bejelentkezési próbálkozást naplózunk - sikereset és sikertelent egyaránt.
*/
INSERT INTO belepes_naplo
       ( felhasznalo_nev, esemeny, megjegyzes, esemeny_idopont, gep_nev )
VALUES ( :as_felhasznalo, :as_esemeny, :as_megjegyzes, GETDATE(), HOST_NAME() )
USING SQLCA;

If SQLCA.SQLCode = 0 Then
    COMMIT USING SQLCA;
Else
    ROLLBACK USING SQLCA;
End If
end subroutine

on w_login.create
this.st_cim          = create st_cim
this.st_felhasznalo  = create st_felhasznalo
this.st_jelszo       = create st_jelszo
this.sle_felhasznalo = create sle_felhasznalo
this.sle_jelszo      = create sle_jelszo
this.cb_belepes      = create cb_belepes
this.cb_megse        = create cb_megse
this.st_status       = create st_status
this.Control[] = { this.st_cim, this.st_felhasznalo, this.st_jelszo, &
                   this.sle_felhasznalo, this.sle_jelszo, &
                   this.cb_belepes, this.cb_megse, this.st_status }
end on

on w_login.destroy
destroy( this.st_cim )
destroy( this.st_felhasznalo )
destroy( this.st_jelszo )
destroy( this.sle_felhasznalo )
destroy( this.sle_jelszo )
destroy( this.cb_belepes )
destroy( this.cb_megse )
destroy( this.st_status )
end on

event open;
/*
   Az ablak megnyitásakor csatlakozunk az adatbázishoz.
*/
CONNECT USING SQLCA;

If SQLCA.SQLCode <> 0 Then
    MessageBox( "Adatbázis hiba", &
        "Nem sikerült csatlakozni az adatbázishoz!~r~n~r~n" + &
        "Hibakód: " + String( SQLCA.SQLDBCode ) + "~r~n" + &
        "Üzenet: " + SQLCA.SQLErrText, &
        StopSign! )
    Close( this )
    Return
End If

sle_felhasznalo.SetFocus()
end event

event close;
/*
   Az ablak bezárásakor lezárjuk az adatbáziskapcsolatot,
   ha nem sikerült bejelentkezni.
*/
If IsNull( gs_felhasznalo_nev ) Or gs_felhasznalo_nev = "" Then
    DISCONNECT USING SQLCA;
End If
end event

type st_cim from statictext within w_login
integer x = 64
integer y = 48
integer width = 1696
integer height = 96
boolean bringtotop = true
integer textsize = -14
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
long textcolor = 33554432
long backcolor = 67108864
boolean enabled = false
string text = "Beleptető rendszer - kérjük, jelentkezzen be"
alignment alignment = center!
boolean focusrectangle = false
end type

type st_felhasznalo from statictext within w_login
integer x = 128
integer y = 256
integer width = 466
integer height = 80
boolean bringtotop = true
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
long textcolor = 33554432
long backcolor = 67108864
boolean enabled = false
string text = "Felhasználónév:"
boolean focusrectangle = false
end type

type st_jelszo from statictext within w_login
integer x = 128
integer y = 400
integer width = 466
integer height = 80
boolean bringtotop = true
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
long textcolor = 33554432
long backcolor = 67108864
boolean enabled = false
string text = "Jelszó:"
boolean focusrectangle = false
end type

type sle_felhasznalo from singlelineedit within w_login
integer x = 640
integer y = 240
integer width = 1056
integer height = 96
integer taborder = 10
boolean bringtotop = true
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
long textcolor = 33554432
integer limit = 50
borderstyle borderstyle = stylelowered!
end type

type sle_jelszo from singlelineedit within w_login
integer x = 640
integer y = 384
integer width = 1056
integer height = 96
integer taborder = 20
boolean bringtotop = true
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
long textcolor = 33554432
boolean password = true
integer limit = 50
borderstyle borderstyle = stylelowered!
end type

event ue_enter;
// Enter billentyűre a beléptetés gombot szimuláljuk
cb_belepes.TriggerEvent( Clicked! )
end event

event key;
If key = KeyEnter! Then
    Parent.cb_belepes.TriggerEvent( Clicked! )
End If
end event

type cb_belepes from commandbutton within w_login
integer x = 640
integer y = 624
integer width = 466
integer height = 128
integer taborder = 30
boolean bringtotop = true
integer textsize = -10
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
string text = "Beléptetés"
boolean default = true
end type

event clicked;
/*
   Beléptetés gomb kezelője:
     1. ellenőrzi a beviteli mezőket
     2. meghívja a hitelesítést
     3. naplózza az eseményt
     4. siker esetén megnyitja a fő ablakot
*/
string ls_felhasznalo, ls_jelszo, ls_hibauzenet
integer li_eredmeny

ls_felhasznalo = Trim( sle_felhasznalo.Text )
ls_jelszo      = sle_jelszo.Text

If ls_felhasznalo = "" Then
    MessageBox( "Hiányzó adat", "Kérjük, adja meg a felhasználónevet!", Information! )
    sle_felhasznalo.SetFocus()
    Return
End If

If ls_jelszo = "" Then
    MessageBox( "Hiányzó adat", "Kérjük, adja meg a jelszót!", Information! )
    sle_jelszo.SetFocus()
    Return
End If

// Gomb tiltása amíg a hitelesítés folyik (gyors duplaklikk ellen)
this.Enabled = False
SetPointer( HourGlass! )

li_eredmeny = Parent.wf_hitelesites( ls_felhasznalo, ls_jelszo, ls_hibauzenet )

SetPointer( Arrow! )
this.Enabled = True

Choose Case li_eredmeny
Case 1
    Parent.wf_naplozas( ls_felhasznalo, "BELEPES_OK", "Sikeres bejelentkezés" )
    // Sikeres bejelentkezés - megnyitjuk a fő alkalmazást
    Close( Parent )
    Open( w_main )
Case 0
    Parent.ii_sikertelen_probalkozas ++
    Parent.wf_naplozas( ls_felhasznalo, "BELEPES_HIBAS_JELSZO", &
        "Hibás jelszó próbálkozás #" + String( Parent.ii_sikertelen_probalkozas ) )

    If Parent.ii_sikertelen_probalkozas >= Parent.ii_max_probalkozas Then
        // Túl sok sikertelen próbálkozás - tiltjuk a fiókot
        UPDATE felhasznalok
           SET tiltott = 1,
               tiltas_idopont = GETDATE()
         WHERE felhasznalo_nev = :ls_felhasznalo
         USING SQLCA;
        COMMIT USING SQLCA;

        Parent.wf_naplozas( ls_felhasznalo, "FIOK_TILTVA", &
            "Automatikus tiltás " + String( Parent.ii_max_probalkozas ) + " sikertelen próbálkozás után" )

        MessageBox( "Fiók letiltva", &
            "Túl sok sikertelen bejelentkezési próbálkozás!~r~n" + &
            "A felhasználói fiók letiltásra került.~r~n" + &
            "Kérjük, vegye fel a kapcsolatot a rendszergazdával.", StopSign! )
        Close( Parent )
    Else
        st_status.Text = ls_hibauzenet + " (" + &
            String( Parent.ii_max_probalkozas - Parent.ii_sikertelen_probalkozas ) + &
            " próbálkozás maradt)"
        st_status.TextColor = RGB( 200, 0, 0 )
        sle_jelszo.Text = ""
        sle_jelszo.SetFocus()
    End If
Case -1
    MessageBox( "Adatbázis hiba", ls_hibauzenet, StopSign! )
Case -2
    Parent.wf_naplozas( ls_felhasznalo, "BELEPES_TILTOTT", "Tiltott fiók próbálkozott bejelentkezni" )
    MessageBox( "Fiók letiltva", ls_hibauzenet, StopSign! )
End Choose
end event

type cb_megse from commandbutton within w_login
integer x = 1184
integer y = 624
integer width = 466
integer height = 128
integer taborder = 40
boolean bringtotop = true
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
string text = "Mégse"
boolean cancel = true
end type

event clicked;
// A felhasználó megszakította a bejelentkezést - kilépünk az alkalmazásból
Close( Parent )
Halt Close
end event

type st_status from statictext within w_login
integer x = 64
integer y = 832
integer width = 1696
integer height = 96
boolean bringtotop = true
integer textsize = -9
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
long textcolor = 33554432
long backcolor = 67108864
boolean enabled = false
alignment alignment = center!
boolean focusrectangle = false
end type
