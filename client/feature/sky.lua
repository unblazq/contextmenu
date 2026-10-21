local V = exports['unblazq-contextmenu']

local permEpoch = -1
local permCache = {}

local function unblazqPerm(key)
    local e = _G.__unblazq_CTX_PERM_EPOCH or 0
    if e ~= permEpoch then
        permEpoch = e
        permCache = {}
    end
    if permCache[key] ~= nil then
        return permCache[key]
    end
    local v = exports['unblazq-contextmenu']:HasPermission(key)
    permCache[key] = v
    return v
end

local TIME_PRESETS = {
    { 0, 'Minuit', 'moon' },
    { 5, 'Aube', 'sun' },
    { 8, 'Matin', 'sun' },
    { 12, 'Midi', 'sun' },
    { 17, 'Après-midi', 'sun' },
    { 20, 'Crépuscule', 'moon' },
    { 23, 'Nuit', 'moon' },
}

local WEATHER_PRESETS = {
    { 'CLEAR', 'Clair', 'sun' },
    { 'EXTRASUNNY', 'Très ensoleillé', 'sun' },
    { 'CLOUDS', 'Nuageux', 'cloud' },
    { 'OVERCAST', 'Couvert', 'cloudSun' },
    { 'RAIN', 'Pluie', 'cloudRain' },
    { 'THUNDER', 'Orage', 'zap' },
    { 'FOGGY', 'Brouillard', 'cloud' },
    { 'SMOG', 'Smog', 'cloud' },
    { 'SNOW', 'Neige', 'snowflake' },
    { 'BLIZZARD', 'Blizzard', 'snowflake' },
    { 'XMAS', 'Neige (fêtes)', 'snowflake' },
}

V:unblazqRegister(function(_, hitSomething, _, _, _)
    if hitSomething then
        return
    end
    if not unblazqPerm('unblazq.admin_sky') then
        return
    end

    local subTime = select(1, V:unblazqAddSubmenu(0, 'Heure', 'clock', nil))
    for _, row in ipairs(TIME_PRESETS) do
        local hour = row[1]
        local label = row[2]
        local icon = row[3]
        local id = V:unblazqAddItem(subTime, label, nil, icon, nil)
        V:unblazqOnActivate(id, function()
            NetworkOverrideClockTime(hour, 0, 0)
        end)
    end

    local subWeather = select(1, V:unblazqAddSubmenu(0, 'Météo', 'cloudSun', nil))
    for _, row in ipairs(WEATHER_PRESETS) do
        local weatherName = row[1]
        local label = row[2]
        local icon = row[3]
        local wid = V:unblazqAddItem(subWeather, label, nil, icon, nil)
        V:unblazqOnActivate(wid, function()
            SetWeatherTypeNowPersist(weatherName)
        end)
    end

    local resetId = V:unblazqAddItem(0, 'Météo par défaut (clair)', nil, 'sun', nil)
    V:unblazqOnActivate(resetId, function()
        SetWeatherTypeNowPersist('CLEAR')
    end)
end)
