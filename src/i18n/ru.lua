local localization = { -- provided by Scope
    JUMP_FAILED_UNHANDLED = "Перемещение прервано, неизвестная ошибка: %d, %s",

    STATUS_TEXT_READY = "Подготовка к перемещению",
    STATUS_TEXT_JUMP_REQUESTED = "Перемещение запрошено",
    STATUS_TEXT_JUMP_STARTED = "Перемещение в процессе (осталось <<1>> сек.)",
    STATUS_TEXT_JUMP_REQUEST_FAILED = "Перемещение провалено",
    STATUS_TEXT_NO_JUMP_TARGETS = "Подходящих игроков не найдено\nОжидание новых целей",

    DIALOG_TITLE = "Перемещение - <<1>>",

    INVALID_TARGET_ZONE = "Цель не может быть достигнута через перемещение",

    AUTOCOMPLETE_ZONE_LABEL_TEMPLATE = "<<1>> -|caaaaaa <<2[нет игроков/$d игрок/$d игроков]>>",

    SLASH_COMMAND_DESCRIPTION = "Перемещение к выбранной цели",
}
ZO_ShallowTableCopy(localization, EasyTravel.Localization)
