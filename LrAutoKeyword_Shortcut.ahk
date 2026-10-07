#Requires AutoHotkey v2.0
#Warn VarUnset, Off
#SingleInstance Force

; ============================================================
; LrAutoKeyword — Raccourci clavier pour Lightroom Classic
; Raccourci : Ctrl+Alt+T
; ============================================================

#HotIf WinActive("ahk_exe lightroom.exe")

; --- Ctrl+Alt+T : navigation clavier (fallback) ---
^!t:: {
    Send "!b"
    Sleep 500
    Loop 30 {
        Send "{Down}"
        Sleep 30
    }
    Sleep 200
    Send "{Right}"
    Sleep 400
    Send "{Down}"
    Sleep 150
    Send "{Enter}"
}

; --- Ctrl+Alt+; : lancer tag---
^!;:: {
    CoordMode "Mouse", "Screen"
    MouseClick "left", 400, 50      ; Bibliothèque
    Sleep 400
    MouseClick "left", 800, 1160     ; Module externe - Extras
    Sleep 400
    MouseClick "left", 1100, 1200     ; Auto-Tag avec Claude
}

; --- Ctrl+Alt+! : parametres  ---
^!!::{
    CoordMode "Mouse", "Screen"
    MouseClick "left", 400, 50      ; Bibliothèque
    Sleep 400
    MouseClick "left", 800, 1160     ; Module externe - Extras
    Sleep 400
    MouseClick "left", 1100, 1240     ; Auto-Tag avec Claude
}

#HotIf

; ============================================================
; Défilement automatique : Ctrl+Alt+D
; Premier appui  → démarre (flèche bas toutes les 0.5s)
; Second appui   → arrête
; ============================================================

global scrolling := false

^!d:: {
    global scrolling
    scrolling := !scrolling

    if scrolling {
        SetTimer(ScrollDown, 500)
    } else {
        SetTimer(ScrollDown, 0)
    }
}

ScrollDown() {
    Send "{Down}"
}
