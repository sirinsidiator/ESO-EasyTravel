local localization = {
    JUMP_FAILED_UNHANDLED = "Sprung wurde unterbrochen, unbehandeltes Resultat: %d, %s",

    STATUS_TEXT_READY = "Vorbereitung auf Sprung",
    STATUS_TEXT_JUMP_REQUESTED = "Sprung angefordert",
    STATUS_TEXT_JUMP_STARTED = "Sprung läuft (<<1>> Sekunden verbleibend)",
    STATUS_TEXT_JUMP_REQUEST_FAILED = "Sprung fehlgeschlagen",
    STATUS_TEXT_NO_JUMP_TARGETS = "Keine passenden Spieler gefunden\nWarte auf neue Ziele",

    JUMP_FAILED_GENERIC = "Ihr könnt momentan nicht reisen.",
    JUMP_FAILED_SPRINTING = "Ihr könnt nicht reisen während ihr rennt.",

    DIALOG_TITLE = "Reise nach <<1>>",

    INVALID_TARGET_ZONE = "Ziel kann nicht durch einen Sprung erreicht werden",

    AUTOCOMPLETE_ZONE_LABEL_TEMPLATE = "<<1>> -|caaaaaa <<2[keine Spieler/$d Spieler/$d Spieler]>>",
    AUTOCOMPLETE_LOCKED_HOME_LABEL_TEMPLATE = "<<1>> -|caaaaaa <<2>> (Vorschau)",

    SLASH_COMMAND_DESCRIPTION = "Reise zum ausgewählten Ziel",
}
ZO_ShallowTableCopy(localization, EasyTravel.Localization)
