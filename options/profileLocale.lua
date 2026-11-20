local ShadowUF = ShadowUF
local english = {
    choose = "Existing Profiles",
    choose_desc = "You can either create a new profile by entering a name in the editbox, or choose one of the already existing profiles.",
    choose_sub = "Select one of your currently available profiles.",
    copy = "Copy From",
    copy_desc = "Copy the settings from one existing profile into the currently active profile.",
    current = "Current Profile:",
    default = "Default",
    delete = "Delete a Profile",
    delete_confirm = "Are you sure you want to delete the selected profile?",
    delete_desc = "Delete existing and unused profiles from the database to save space, and cleanup the SavedVariables file.",
    delete_sub = "Deletes a profile from the database.",
    intro = "You can change the active database profile, so you can have different settings for every character.",
    name_too_long = "Profile names cannot be longer than 50 characters.",
    new = "New",
    new_sub = "Create a new empty profile.",
    profiles = "Profiles",
    profiles_sub = "Manage Profiles",
    reset = "Reset Profile",
    reset_desc = "Reset the current profile back to its default values, in case your configuration is broken, or you simply want to start over.",
    reset_sub = "Reset the current profile to the default",
}
local russian = {
    choose = "Существующие профили",
    choose_desc = "Вы можете создать новый профиль, введя название в поле ввода, или выбрать один из уже существующих профилей.",
    choose_sub = "Выбор одного из уже доступных профилей.",
    copy = "Скопировать из",
    copy_desc = "Копирование настроек из выбранного профиля в активный.",
    current = "Текущий профиль:",
    default = "По умолчанию",
    delete = "Удалить профиль",
    delete_confirm = "Вы уверены, что хотите удалить выбранный профиль?",
    delete_desc = "Удаление существующего и неиспользуемого профиля из базы данных для сохранения места, и очистка файла SavedVariables.",
    delete_sub = "Удаление профиля из базы данных.",
    intro = "Изменяя активный профиль, Вы можете задать разные настройки для каждого персонажа.",
    name_too_long = "Имена профилей не могут превышать 50 символов.",
    new = "Новый",
    new_sub = "Создание нового чистого профиля.",
    profiles = "Профили",
    profiles_sub = "Управление профилями",
    reset = "Сбросить профиль",
    reset_desc = "Сброс текущего профиля к стандартным настройкам, если Ваша конфигурация испорчена или Вы хотите настроить все заново.",
    reset_sub = "Сброс текущего профиля на стандартный",
}

-- AceDBOptions shares this tree with other addons. Localise a private copy
-- of just the SUF panel and keep the original profile operations.
local dualSpecDescription
function ShadowUF:LocalizeProfileOptions(original, locale)
    if locale ~= "enUS" and locale ~= "ruRU" then return original end
    local ru = locale == "ruRU"
    local panel = {}
    for key, value in pairs(original) do panel[key] = value end
    if original.plugins then
        panel.plugins = {}
        for key, value in pairs(original.plugins) do panel.plugins[key] = value end
    end
    local t = ru and russian or english
    panel.name, panel.desc = t.profiles, t.profiles_sub
    local fields = CopyTable(panel.args)
    panel.args = fields
    fields.desc.name = t.intro
    fields.descreset.name = t.reset_desc
    fields.reset.name, fields.reset.desc = t.reset, t.reset_sub
    fields.current.name = function(info)
        return t.current .. " " .. NORMAL_FONT_COLOR_CODE .. info.handler:GetCurrentProfile() .. FONT_COLOR_CODE_CLOSE
    end
    fields.choosedesc.name = t.choose_desc
    fields.new.name, fields.new.desc, fields.new.usage = t.new, t.new_sub, t.name_too_long
    fields.choose.name, fields.choose.desc = t.choose, t.choose_sub
    fields.copydesc.name = t.copy_desc
    fields.copyfrom.name, fields.copyfrom.desc = t.copy, t.copy_sub
    fields.deldesc.name = t.delete_desc
    fields.delete.name, fields.delete.desc, fields.delete.confirmText = t.delete, t.delete_sub, t.delete_confirm

    local dual = panel.plugins and panel.plugins["LibDualSpec-1.0"]
    if dual then
        dual = CopyTable(dual)
        panel.plugins["LibDualSpec-1.0"] = dual
        dual.new.name, dual.new.desc, dual.new.usage = t.new, t.new_sub, t.name_too_long
        dual.choose.name, dual.choose.desc = t.choose, t.choose_sub
        dual.enabled.name = ru and "Профили специализаций" or "Specialization profiles"
        dualSpecDescription = dualSpecDescription or dual.enabled.desc
        dual.enabled.desc = function(...)
            local note = dualSpecDescription(...)
            local reason = note and note:match("(\n\n.*)$") or ""
            return (ru and "Менять профиль при смене специализации." or "Switch profiles when changing specialization.") .. reason
        end
    end
    return panel
end
