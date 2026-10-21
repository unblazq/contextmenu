local OPENING_COOLDOWN_MS = 250

local KEYS = {
    holdForCursor = 19,
    interact = 25,
    activateItem = 24,
}

local DISABLED_WHILE_ALT = {
    1, 2, 16, 17, 24, 25, 68, 69, 70, 91, 92, 106, 114, 140, 141, 142, 257, 263, 264, 330, 331, 347,
}

local MENU_ALT_CHECK_GRACE_MS = 50

local unblazqMenuOpen = false
local unblazqOpeningCooldownUntil = 0
local unblazqMenuOpenedAt = 0
local unblazqMenuRequireAltHold = true

local unblazqFuncTable = {}
local unblazqAlternateFuncs = {}

local unblazqMenus = {}
local unblazqItemMeta = {}
local unblazqNextItemId = 0
local unblazqNextSubMenuId = 1
local unblazqScreenOverride = nil
local unblazqAltWasDown = false

local function unblazqAllocateItemId()
    unblazqNextItemId = unblazqNextItemId + 1
    return unblazqNextItemId
end

local function unblazqAllocateSubMenuId()
    local id = unblazqNextSubMenuId
    unblazqNextSubMenuId = unblazqNextSubMenuId + 1
    return id
end

local function unblazqGetMenu(menuId)
    if menuId == nil or menuId == 0 then
        return unblazqMenus[0]
    end
    return unblazqMenus[menuId]
end

local function unblazqResetBuild()
    for k in pairs(unblazqMenus) do
        unblazqMenus[k] = nil
    end
    unblazqMenus[0] = { items = {} }
    unblazqItemMeta = {}
    unblazqNextItemId = 0
    unblazqNextSubMenuId = 1
    unblazqScreenOverride = nil
end

function unblazqSetMenuScreenFromWorld(worldPosition)
    if not worldPosition then
        return
    end
    local x = worldPosition.x
    local y = worldPosition.y
    local z = worldPosition.z
    if not x or not y or not z then
        return
    end
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x + 0.0, y + 0.0, z + 0.0)
    if onScreen then
        unblazqScreenOverride = { x = sx, y = sy }
    end
end

local function unblazqSendCloseNui()
    if not unblazqMenuOpen then
        return
    end
    SendNUIMessage({ action = 'unblazq:close' })
    SetNuiFocus(false, false)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(false)
    end
    unblazqMenuOpen = false
    unblazqAltWasDown = IsControlPressed(0, KEYS.holdForCursor) or IsDisabledControlPressed(0, KEYS.holdForCursor)
end

local function unblazqSendOpen(menuPayload, position, requireAltHold)
    local cx, cy = unblazqGetCursorScreenPosition()
    SendNUIMessage({
        action = 'unblazq:open',
        menu = menuPayload,
        position = {
            x = position.x ~= nil and position.x or cx,
            y = position.y ~= nil and position.y or cy,
        },
    })
    SetNuiFocus(true, true)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(true)
    end
    unblazqMenuOpen = true
    unblazqMenuOpenedAt = GetGameTimer()
    unblazqMenuRequireAltHold = requireAltHold ~= false
end

local function unblazqSerializeItems(menuId)
    local menu = unblazqMenus[menuId]
    if not menu then
        return {}
    end
    local out = {}
    for _, it in ipairs(menu.items) do
        local meta = unblazqItemMeta[it.id] or {}
        if it.type == 'separator' then
            out[#out + 1] = { id = it.id, type = 'separator' }
        elseif it.type == 'text' then
            local textRow = {
                id = it.id,
                type = 'text',
                title = it.title,
            }
            if it.iconStart then
                textRow.iconStart = it.iconStart
            end
            out[#out + 1] = textRow
        elseif it.type == 'checkbox' then
            out[#out + 1] = {
                id = it.id,
                type = 'checkbox',
                title = it.title,
                checked = (meta.checked == true or meta.checked == 1),
                enabled = meta.enabled ~= false,
            }
        elseif it.type == 'submenu' then
            local sub = {
                id = it.id,
                type = 'submenu',
                title = it.title,
                enabled = meta.enabled ~= false,
                submenu = { items = unblazqSerializeItems(it.submenuId) },
            }
            if meta.iconStart then
                sub.iconStart = meta.iconStart
            end
            if meta.iconCenter then
                sub.iconCenter = meta.iconCenter
            end
            if it.scrollMax then
                sub.scrollMax = it.scrollMax
            end
            if it.pageSize then
                sub.pageSize = it.pageSize
            end
            out[#out + 1] = sub
        else
            local itemRow = {
                id = it.id,
                type = 'item',
                title = it.title,
                enabled = meta.enabled ~= false,
                rightText = meta.rightText,
                closeOnActivate = meta.closeOnActivate,
            }
            if meta.iconStart then
                itemRow.iconStart = meta.iconStart
            end
            if meta.iconCenter then
                itemRow.iconCenter = meta.iconCenter
            end
            out[#out + 1] = itemRow
        end
    end
    return out
end

local function unblazqRunInteract(screenPosition, hitSomething, worldPosition, hitEntity, normalDirection, rayDebugAtClick)
    if GetGameTimer() < unblazqOpeningCooldownUntil then
        return
    end
    unblazqOpeningCooldownUntil = GetGameTimer() + OPENING_COOLDOWN_MS

    _G.__unblazq_CTX_PERM_EPOCH = (_G.__unblazq_CTX_PERM_EPOCH or 0) + 1

    unblazqResetBuild()

    local toRemove = {}
    for i, fn in ipairs(unblazqFuncTable) do
        local ok, err = pcall(fn, screenPosition, hitSomething, worldPosition, hitEntity, normalDirection)
        if not ok then
            toRemove[#toRemove + 1] = i
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(unblazqFuncTable, toRemove[i])
    end

    local rootItems = unblazqSerializeItems(0)
    if #rootItems == 0 then
        return
    end

    local pos = unblazqScreenOverride or { x = screenPosition.x, y = screenPosition.y }
    unblazqSendOpen({ items = rootItems }, pos)
end

local function unblazqInitPool()
    CreateThread(function()
        while true do
            if IsPauseMenuActive() and unblazqMenuOpen then
                unblazqSendCloseNui()
                Wait(250)
            elseif unblazqMenuOpen then
                for _, c in ipairs(DISABLED_WHILE_ALT) do
                    DisableControlAction(0, c, true)
                end
                Wait(0)
            else
                Wait(250)
            end
        end
    end)

    CreateThread(function()
        while true do
            if unblazqMenuOpen then
                Wait(250)
            else
                local altDown = IsControlPressed(0, KEYS.holdForCursor) or IsDisabledControlPressed(0, KEYS.holdForCursor)
                if altDown then
                    if not unblazqAltWasDown then
                        SetCursorLocation(0.5, 0.5)
                    end
                    unblazqAltWasDown = true
                    SetMouseCursorActiveThisFrame()
                    DisableControlAction(0, 24, true)
                    DisableControlAction(0, 25, true)

                    local screenPosition = unblazqGetCursorScreenPosition()
                    local hitSomething, worldPosition, normalDirection, hitEntity = unblazqScreenToWorld(screenPosition, 10000.0)
                    local rayDebugAtClick = unblazqLastRayDebug

                    if
                        IsDisabledControlJustPressed(0, KEYS.interact)
                        or IsDisabledControlJustPressed(0, KEYS.activateItem)
                    then
                        CreateThread(function()
                            unblazqRunInteract(screenPosition, hitSomething, worldPosition, hitEntity, normalDirection, rayDebugAtClick)
                        end)
                    end

                    for _, alt in ipairs(unblazqAlternateFuncs) do
                        if IsControlJustPressed(0, alt.key) or IsDisabledControlJustPressed(0, alt.key) then
                            CreateThread(function()
                                alt.Func(screenPosition, hitSomething, worldPosition, hitEntity, normalDirection)
                            end)
                        end
                    end

                    for _, c in ipairs(DISABLED_WHILE_ALT) do
                        DisableControlAction(0, c, true)
                    end
                    Wait(0)
                else
                    unblazqAltWasDown = false
                    Wait(50)
                end
            end
        end
    end)

    CreateThread(function()
        while true do
            if unblazqMenuOpen and unblazqMenuRequireAltHold and GetGameTimer() >= unblazqMenuOpenedAt + MENU_ALT_CHECK_GRACE_MS then
                local altDown = IsControlPressed(0, KEYS.holdForCursor) or IsDisabledControlPressed(0, KEYS.holdForCursor)
                if not altDown then
                    unblazqSendCloseNui()
                end
                Wait(0)
            elseif unblazqMenuOpen then
                Wait(250)
            else
                Wait(250)
            end
        end
    end)
end

local unblazqPoolStarted = false

local function unblazqEnsurePool()
    if not unblazqPoolStarted then
        unblazqPoolStarted = true
        unblazqInitPool()
    end
end

function unblazqRegister(func)
    unblazqFuncTable[#unblazqFuncTable + 1] = func
    unblazqEnsurePool()
    return #unblazqFuncTable
end

function unblazqAddSeparator(menuId)
    local id = unblazqAllocateItemId()
    unblazqItemMeta[id] = {}
    table.insert(unblazqGetMenu(menuId).items, { id = id, type = 'separator' })
    return id
end

function unblazqAddTextItem(menuId, title, iconStart)
    local id = unblazqAllocateItemId()
    unblazqItemMeta[id] = {}
    table.insert(unblazqGetMenu(menuId).items, {
        id = id,
        type = 'text',
        title = title,
        iconStart = iconStart,
    })
    return id
end

function unblazqAddItem(menuId, title, func, iconStart, iconCenter)
    local id = unblazqAllocateItemId()
    unblazqItemMeta[id] = {
        OnActivate = func,
        enabled = true,
        closeOnActivate = true,
        iconStart = iconStart,
        iconCenter = iconCenter,
    }
    table.insert(unblazqGetMenu(menuId).items, { id = id, type = 'item', title = title })
    return id
end

function unblazqAddItems(list)
    local ids = {}
    for _, row in ipairs(list) do
        ids[#ids + 1] = unblazqAddItem(row[1], row[2], row[3])
    end
    return ids
end

function unblazqAddSpriteItem(menuId, textureDict, textureName)
    local id = unblazqAddItem(menuId, textureName or 'Sprite', nil)
    unblazqItemMeta[id].sprite = { dict = textureDict, name = textureName }
    return id
end

function unblazqAddCheckboxItem(menuId, title, checked, kvpKey)
    local id = unblazqAllocateItemId()
    local on = (checked == true or checked == 1)
    unblazqItemMeta[id] = {
        checked = on,
        kvpKey = kvpKey,
        OnValueChanged = nil,
        enabled = true,
    }
    table.insert(unblazqGetMenu(menuId).items, {
        id = id,
        type = 'checkbox',
        title = title,
    })
    return id
end

function unblazqAddSubmenu(parentMenuId, title, iconStart, iconCenter)
    local subMenuId = unblazqAllocateSubMenuId()
    unblazqMenus[subMenuId] = { items = {} }
    local itemId = unblazqAllocateItemId()
    unblazqItemMeta[itemId] = {
        enabled = true,
        closeOnActivate = false,
        iconStart = iconStart,
        iconCenter = iconCenter,
    }
    table.insert(unblazqGetMenu(parentMenuId).items, {
        id = itemId,
        type = 'submenu',
        title = title,
        submenuId = subMenuId,
    })
    return subMenuId, itemId
end

function unblazqAddScrollSubmenu(parentMenuId, title, maxItems)
    local subMenuId, itemId = unblazqAddSubmenu(parentMenuId, title)
    unblazqMenus[subMenuId].scrollMax = maxItems
    for _, row in ipairs(unblazqGetMenu(parentMenuId).items) do
        if row.id == itemId and row.type == 'submenu' then
            row.scrollMax = maxItems
            break
        end
    end
    return subMenuId, itemId
end

function unblazqAddPageSubmenu(parentMenuId, title, maxItems)
    local subMenuId, itemId = unblazqAddSubmenu(parentMenuId, title)
    unblazqMenus[subMenuId].pageSize = maxItems
    for _, row in ipairs(unblazqGetMenu(parentMenuId).items) do
        if row.id == itemId and row.type == 'submenu' then
            row.pageSize = maxItems
            break
        end
    end
    return subMenuId, itemId
end

function unblazqOnActivate(itemId, func)
    assert(itemId and unblazqItemMeta[itemId], 'unblazqOnActivate: itemId invalide')
    assert(func, 'unblazqOnActivate: func requis')
    unblazqItemMeta[itemId].OnActivate = func
end

function unblazqOnRelease(itemId, func)
    assert(itemId and unblazqItemMeta[itemId], 'unblazqOnRelease: itemId invalide')
    assert(func, 'unblazqOnRelease: func requis')
    unblazqItemMeta[itemId].OnRelease = func
end

function unblazqOnValueChanged(itemId, func)
    assert(itemId and unblazqItemMeta[itemId], 'unblazqOnValueChanged: itemId invalide')
    assert(func, 'unblazqOnValueChanged: func requis')
    unblazqItemMeta[itemId].OnValueChanged = func
end

function unblazqEnabled(itemId, enabled)
    assert(itemId and unblazqItemMeta[itemId], 'unblazqEnabled: itemId invalide')
    unblazqItemMeta[itemId].enabled = enabled ~= false
end

function unblazqCloseOnActivate(itemId, closeOnActivate)
    assert(itemId and unblazqItemMeta[itemId], 'unblazqCloseOnActivate: itemId invalide')
    unblazqItemMeta[itemId].closeOnActivate = closeOnActivate == true
end

function unblazqRightText(itemId, text)
    assert(itemId and unblazqItemMeta[itemId], 'unblazqRightText: itemId invalide')
    if text then
        unblazqItemMeta[itemId].rightText = text
    else
        return unblazqItemMeta[itemId].rightText
    end
end

function unblazqAddAlternateFunction(key, func)
    unblazqAlternateFuncs[#unblazqAlternateFuncs + 1] = { key = key, Func = func }
    unblazqEnsurePool()
end

function unblazqIsMenuOpen()
    return unblazqMenuOpen
end

function unblazqCloseMenu()
    unblazqSendCloseNui()
end

function unblazqOpenMenu(menuTable, position)
    if unblazqMenuOpen then
        unblazqSendCloseNui()
    end
    unblazqItemMeta = {}
    unblazqSendOpen(menuTable or { items = {} }, position or {}, false)
end

RegisterNUICallback('unblazq:ready', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('unblazq:close', function(_, cb)
    unblazqSendCloseNui()
    cb({ ok = true })
end)

RegisterNUICallback('unblazq:select', function(data, cb)
    local itemId = data and data.id
    if itemId then
        itemId = tonumber(itemId) or itemId
        local meta = unblazqItemMeta[itemId]
        if meta and meta.enabled ~= false then
            if meta.OnActivate then
                meta.OnActivate()
            end
            local close = meta.closeOnActivate
            if close == nil then
                close = true
            end
            if close then
                unblazqSendCloseNui()
            end
        else
            unblazqSendCloseNui()
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('unblazq:checkbox', function(data, cb)
    local itemId = data and data.id
    local checked = data and data.checked
    if itemId then
        itemId = tonumber(itemId) or itemId
        local meta = unblazqItemMeta[itemId]
        if meta then
            local on = (checked == true or checked == 1)
            meta.checked = on
            if meta.kvpKey and type(meta.kvpKey) == 'string' and meta.kvpKey ~= '' then
                SetResourceKvp(meta.kvpKey, on and '1' or '0')
            end
            if meta.OnValueChanged then
                meta.OnValueChanged(on)
            end
        end
    end
    cb({ ok = true })
end)

exports('unblazqSetMenuScreenFromWorld', unblazqSetMenuScreenFromWorld)
exports('unblazqRegister', unblazqRegister)
exports('unblazqAddSeparator', unblazqAddSeparator)
exports('unblazqAddTextItem', unblazqAddTextItem)
exports('unblazqAddItem', unblazqAddItem)
exports('unblazqAddItems', unblazqAddItems)
exports('unblazqAddSpriteItem', unblazqAddSpriteItem)
exports('unblazqAddCheckboxItem', unblazqAddCheckboxItem)
exports('unblazqAddSubmenu', unblazqAddSubmenu)
exports('unblazqAddScrollSubmenu', unblazqAddScrollSubmenu)
exports('unblazqAddPageSubmenu', unblazqAddPageSubmenu)
exports('unblazqOnActivate', unblazqOnActivate)
exports('unblazqOnRelease', unblazqOnRelease)
exports('unblazqOnValueChanged', unblazqOnValueChanged)
exports('unblazqEnabled', unblazqEnabled)
exports('unblazqCloseOnActivate', unblazqCloseOnActivate)
exports('unblazqRightText', unblazqRightText)
exports('unblazqAddAlternateFunction', unblazqAddAlternateFunction)
exports('unblazqIsMenuOpen', unblazqIsMenuOpen)
exports('unblazqCloseMenu', unblazqCloseMenu)
exports('unblazqOpenMenu', unblazqOpenMenu)
exports('OpenMenu', unblazqOpenMenu)
exports('OpenSelfMenu', unblazqOpenMenu)
exports('Open', unblazqOpenMenu)
exports('IsOpen', unblazqIsMenuOpen)
exports('CloseMenu', unblazqCloseMenu)
