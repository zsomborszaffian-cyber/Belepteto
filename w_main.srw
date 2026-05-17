$PBExportHeader$w_main.srw
$PBExportComments$Sikeres bejelentkezés utáni fő ablak
forward
global type w_main from window
end type
type st_udvozles from statictext within w_main
end type
type st_info from statictext within w_main
end type
type cb_kilepes from commandbutton within w_main
end type
end forward

global type w_main from window
integer width = 2400
integer height = 1600
boolean titlebar = true
string title = "Beleptető rendszer - Főablak"
boolean controlmenu = true
boolean minbox = true
boolean maxbox = true
boolean resizable = true
windowtype windowtype = main!
long backcolor = 67108864
boolean center = true
st_udvozles st_udvozles
st_info st_info
cb_kilepes cb_kilepes
end type
global w_main w_main

on w_main.create
this.st_udvozles = create st_udvozles
this.st_info     = create st_info
this.cb_kilepes  = create cb_kilepes
this.Control[] = { this.st_udvozles, this.st_info, this.cb_kilepes }
end on

on w_main.destroy
destroy( this.st_udvozles )
destroy( this.st_info )
destroy( this.cb_kilepes )
end on

event open;
st_udvozles.Text = "Üdvözöljük, " + gs_felhasznalo_nev + "!"
st_info.Text = "Szerepkör: " + gs_szerepkor + &
    "~r~nBelépés időpontja: " + String( gdt_belepes_idopont, "yyyy.mm.dd hh:mm:ss" )
end event

event close;
// Naplózzuk a kijelentkezést és bontjuk az adatbáziskapcsolatot
INSERT INTO belepes_naplo
       ( felhasznalo_nev, esemeny, megjegyzes, esemeny_idopont, gep_nev )
VALUES ( :gs_felhasznalo_nev, 'KILEPES', 'Felhasználó kijelentkezett', GETDATE(), HOST_NAME() )
USING SQLCA;
COMMIT USING SQLCA;

DISCONNECT USING SQLCA;
end event

type st_udvozles from statictext within w_main
integer x = 96
integer y = 96
integer width = 2160
integer height = 128
boolean bringtotop = true
integer textsize = -16
integer weight = 700
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
long textcolor = 33554432
long backcolor = 67108864
boolean enabled = false
alignment alignment = center!
boolean focusrectangle = false
end type

type st_info from statictext within w_main
integer x = 96
integer y = 288
integer width = 2160
integer height = 256
boolean bringtotop = true
integer textsize = -10
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

type cb_kilepes from commandbutton within w_main
integer x = 960
integer y = 1280
integer width = 466
integer height = 128
integer taborder = 10
boolean bringtotop = true
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
string facename = "Arial"
string text = "Kilépés"
end type

event clicked;
If MessageBox( "Kilépés", "Biztosan ki szeretne lépni az alkalmazásból?", &
    Question!, YesNo!, 2 ) = 1 Then
    Close( Parent )
End If
end event
