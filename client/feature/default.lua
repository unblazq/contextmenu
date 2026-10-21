local V = exports['unblazq-contextmenu']

local KVP_GROUND = {
    idMarkers = 'unblazq_ground_id_markers',
    blips = 'unblazq_ground_blips',
    nomsJoueurs = 'unblazq_ground_noms_joueurs',
}

local function unblazqKvpGetBool(key, default)
    local s = GetResourceKvpString(key)
    if s == nil or s == '' then
        return default
    end
    return s == '1' or s == 'true'
end

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

V:unblazqRegister(function(_, hitSomething, worldPosition, hitEntity, _)
    if not hitSomething then
        return
    end
    if hitEntity and hitEntity ~= 0 and DoesEntityExist(hitEntity) then
        if IsEntityAPed(hitEntity) or IsEntityAVehicle(hitEntity) then
            return
        end
    end
    if worldPosition then
        exports['unblazq-contextmenu']:unblazqSetMenuScreenFromWorld(worldPosition)
    end
    if unblazqPerm('unblazq.admin_ground') then
        local placerId = V:unblazqAddItem(0, 'Placer', nil, 'mapPin', nil)
        V:unblazqOnActivate(placerId, function() end)
        local subDbgId = select(1, V:unblazqAddSubmenu(0, 'Outils de debug', 'settings', nil))
        local subDebuggerId = select(1, V:unblazqAddSubmenu(subDbgId, 'Debugger', 'settings', nil))
        V:unblazqAddItem(subDebuggerId, 'État debugger', function() end)
        local trashId = V:unblazqAddItem(subDbgId, 'Nettoyer la rue', nil, 'trash2', nil)
        V:unblazqOnActivate(trashId, function() end)
        local cbIdMarkers = V:unblazqAddCheckboxItem(subDbgId, 'Id markers', unblazqKvpGetBool(KVP_GROUND.idMarkers, false), KVP_GROUND.idMarkers)
        V:unblazqOnValueChanged(cbIdMarkers, function() end)
        local cbBlips = V:unblazqAddCheckboxItem(subDbgId, 'Blips', unblazqKvpGetBool(KVP_GROUND.blips, false), KVP_GROUND.blips)
        V:unblazqOnValueChanged(cbBlips, function() end)
        local cbNoms = V:unblazqAddCheckboxItem(subDbgId, 'Noms joueurs', unblazqKvpGetBool(KVP_GROUND.nomsJoueurs, false), KVP_GROUND.nomsJoueurs)
        V:unblazqOnValueChanged(cbNoms, function() end)
    end
    local msgId = V:unblazqAddItem(0, 'Afficher un message ici', nil, 'messageSquare', nil)
    V:unblazqOnActivate(msgId, function() end)
end)

V:unblazqRegister(function(_, hitSomething, _, hitEntity, _)
    if not hitSomething or not hitEntity or hitEntity == 0 or not DoesEntityExist(hitEntity) then
        return
    end
    if not IsEntityAPed(hitEntity) then
        return
    end

    if not unblazqPerm('unblazq.admin_ped') then
        return
    end

    local ped = hitEntity
    local del = V:unblazqAddItem(0, 'Supprimer le ped', nil)
    V:unblazqOnActivate(del, function()
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end)
end)

V:unblazqRegister(function(_, hitSomething, _, hitEntity, _)
    if not hitSomething or not hitEntity or hitEntity == 0 or not DoesEntityExist(hitEntity) then
        return
    end
    if not IsEntityAVehicle(hitEntity) then
        return
    end

    local vehicle = hitEntity

    local function doorToggle(doorIndex)
        return function()
            if not DoesEntityExist(vehicle) then
                return
            end
            if GetVehicleDoorAngleRatio(vehicle, doorIndex) < 0.1 then
                SetVehicleDoorOpen(vehicle, doorIndex, false, false)
            else
                SetVehicleDoorShut(vehicle, doorIndex, false)
            end
        end
    end

    local seats = V:unblazqAddItem(0, 'Sièges', nil, 'armchair', nil)
    V:unblazqOnActivate(seats, function()
        if not DoesEntityExist(vehicle) then
            return
        end
        local ped = PlayerPedId()
        if not IsPedInVehicle(ped, vehicle, false) then
            TaskWarpPedIntoVehicle(ped, vehicle, -1)
        end
    end)

    local engine = V:unblazqAddItem(0, 'Eteindre le moteur', nil, 'power', nil)
    V:unblazqOnActivate(engine, function()
        if DoesEntityExist(vehicle) then
            SetVehicleEngineOn(vehicle, false, true, true)
        end
    end)

    local glove = V:unblazqAddItem(0, 'Ouvrir la boîte à gant', nil, 'package', nil)
    V:unblazqOnActivate(glove, function()
        if not DoesEntityExist(vehicle) then
            return
        end
    end)

    local music = V:unblazqAddItem(0, 'Mettre de la musique', nil, 'music', nil)
    V:unblazqEnabled(music, false)

    local subWin = select(1, V:unblazqAddSubmenu(0, 'Gestion des fenêtres', 'layoutGrid', nil))
    local allWin = V:unblazqAddItem(subWin, 'Toutes', nil)
    V:unblazqOnActivate(allWin, function()
        if not DoesEntityExist(vehicle) then
            return
        end
        for w = 0, 3 do
            RollDownWindow(vehicle, w)
        end
    end)
    for w = 0, 3 do
        local winItem = V:unblazqAddItem(subWin, ('Fenêtre %s'):format(w + 1), nil)
        V:unblazqOnActivate(winItem, function()
            if DoesEntityExist(vehicle) then
                RollDownWindow(vehicle, w)
            end
        end)
    end

    local subDoors = select(1, V:unblazqAddSubmenu(0, 'Gestion des portières', 'doorClosed', nil))
    local allDoors = V:unblazqAddItem(subDoors, 'Toutes', nil)
    V:unblazqOnActivate(allDoors, function()
        if not DoesEntityExist(vehicle) then
            return
        end
        for d = 0, 5 do
            if GetVehicleDoorAngleRatio(vehicle, d) < 0.1 then
                SetVehicleDoorOpen(vehicle, d, false, false)
            else
                SetVehicleDoorShut(vehicle, d, false)
            end
        end
    end)

    local doorCount = GetNumberOfVehicleDoors(vehicle) or 0
    if doorCount > 0 then
        for i = 1, doorCount do
            local doorIndex = i - 1
            local doorItem = V:unblazqAddItem(subDoors, ('Porte %s'):format(i), nil)
            V:unblazqOnActivate(doorItem, doorToggle(doorIndex))
        end
    end

    local capot = V:unblazqAddItem(subDoors, 'Capot', nil)
    V:unblazqOnActivate(capot, doorToggle(4))

    local coffre = V:unblazqAddItem(subDoors, 'Coffre', nil)
    V:unblazqOnActivate(coffre, doorToggle(5))

    if unblazqPerm('unblazq.admin_vehicle') then
        local subAdmin = select(1, V:unblazqAddSubmenu(0, 'Actions (Admin)', 'shield', nil))
        V:unblazqAddItem(subAdmin, 'Action rapide', function() end)

        local subInfo = select(1, V:unblazqAddSubmenu(0, 'Informations (Admin)', 'info', nil))
        V:unblazqAddItem(subInfo, 'Modèle / plaque', function() end)
    end

    if unblazqPerm('unblazq.admin_debug') then
        local subDbg = select(1, V:unblazqAddSubmenu(0, 'Outils de debug', 'settings', nil))
        V:unblazqAddItem(subDbg, 'Coords véhicule', function() end)
    end
end)

V:unblazqRegister(function(_, hitSomething, _, hitEntity, _)
    if not hitSomething or not hitEntity or hitEntity == 0 then
        return
    end
    if hitEntity ~= PlayerPedId() then
        return
    end

    V:unblazqAddItem(0, "Déplacer l'animation", nil)
    V:unblazqAddTextItem(0, 'La personne (...)', 'messageSquare')
    V:unblazqAddItem(0, "Rejouer l'animation", nil)

    local subId = select(1, V:unblazqAddSubmenu(0, 'Gestion perso', nil, 'gamepad2'))
    V:unblazqAddItem(subId, 'Nettoyer les vêtements', function() end)
    V:unblazqAddItem(subId, 'Faire saigner', function() end)

    if unblazqPerm('unblazq.admin_debug') then
        local subDbg = select(1, V:unblazqAddSubmenu(0, 'Outils de debug', 'settings', nil))
        V:unblazqAddItem(subDbg, 'Afficher coords', function() end)
    end
end)

RegisterCommand('unblazq_menu_dev', function()
    if V:unblazqIsMenuOpen() then
        V:unblazqCloseMenu()
        return
    end
    V:unblazqOpenMenu({
        items = {
            { id = 1, type = 'text', title = 'Menu test (dev)' },
            { id = 2, type = 'separator' },
            { id = 3, type = 'item', title = 'Action simple', enabled = true },
            {
                id = 4,
                type = 'checkbox',
                title = 'Option',
                checked = false,
                enabled = true,
            },
        },
    }, {})
end, false)
