unblazq = unblazq or {}

---------------------------------------------------------------------
-- Détection (Qbox avant QB car il expose aussi qb-core)
---------------------------------------------------------------------
function unblazq.ResolveFramework()
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end

unblazqServerFrameworkName = unblazq.ResolveFramework()

exports('GetFrameworkName', function()
    return unblazqServerFrameworkName
end)

---------------------------------------------------------------------
-- Chargement de l'objet core
---------------------------------------------------------------------
local Core
if unblazqServerFrameworkName == 'esx' then
    Core = exports['es_extended']:getSharedObject()
elseif unblazqServerFrameworkName == 'qb' then
    Core = exports['qb-core']:GetCoreObject()
end

---------------------------------------------------------------------
-- Player abstraction
---------------------------------------------------------------------
local function getPlayer(src)
    local fw = unblazqServerFrameworkName
    if fw == 'esx' then return Core.GetPlayerFromId(src) end
    if fw == 'qb' then return Core.Functions.GetPlayer(src) end
    if fw == 'qbox' then return exports.qbx_core:GetPlayer(src) end
    return nil
end

function unblazq.GetPlayer(src)
    return getPlayer(src)
end

function unblazq.GetIdentifier(src)
    local fw, p = unblazqServerFrameworkName, getPlayer(src)
    if p then
        if fw == 'esx' then return p.identifier end
        return p.PlayerData.citizenid
    end
    return GetPlayerIdentifierByType(src, 'license')
end

function unblazq.GetName(src)
    local fw, p = unblazqServerFrameworkName, getPlayer(src)
    if p then
        if fw == 'esx' then return p.getName() end
        local ci = p.PlayerData.charinfo
        return ('%s %s'):format(ci.firstname, ci.lastname)
    end
    return GetPlayerName(src)
end

function unblazq.GetJob(src)
    local fw, p = unblazqServerFrameworkName, getPlayer(src)
    if not p then return nil end
    if fw == 'esx' then return p.getJob().name end
    return p.PlayerData.job.name
end

function unblazq.AddMoney(src, amount, account)
    local fw, p = unblazqServerFrameworkName, getPlayer(src)
    if not p then return false end
    if fw == 'esx' then
        p.addAccountMoney(account or 'money', amount)
    else
        p.Functions.AddMoney(account or 'cash', amount)
    end
    return true
end

function unblazq.RemoveMoney(src, amount, account)
    local fw, p = unblazqServerFrameworkName, getPlayer(src)
    if not p then return false end
    if fw == 'esx' then
        p.removeAccountMoney(account or 'money', amount)
    else
        return p.Functions.RemoveMoney(account or 'cash', amount)
    end
    return true
end

function unblazq.Notify(src, msg, nType)
    local fw = unblazqServerFrameworkName
    if fw == 'esx' then
        TriggerClientEvent('esx:showNotification', src, msg)
    elseif fw == 'qb' or fw == 'qbox' then
        TriggerClientEvent('QBCore:Notify', src, msg, nType or 'primary')
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'INFO', msg } })
    end
end

---------------------------------------------------------------------
-- Permissions (ACE en base, + groupes du framework)
---------------------------------------------------------------------
function unblazq.HasPermission(src, group)
    if src == 0 then return true end -- console
    if IsPlayerAceAllowed(src, ('command.%s'):format(group)) then return true end
    if IsPlayerAceAllowed(src, group) then return true end

    local fw, p = unblazqServerFrameworkName, getPlayer(src)
    if fw == 'esx' and p then
        return p.getGroup() == group
    elseif fw == 'qb' then
        return Core.Functions.HasPermission(src, group)
    elseif fw == 'qbox' then
        return IsPlayerAceAllowed(src, group)
    end
    return false
end

---------------------------------------------------------------------
-- Commandes universelles
---------------------------------------------------------------------
function unblazq.RegisterCommand(name, cb, opts)
    opts = opts or {}
    RegisterCommand(name, function(src, args, raw)
        if opts.group and not unblazq.HasPermission(src, opts.group) then
            return unblazq.Notify(src, 'Permission refusée.', 'error')
        end
        cb(src, args, raw)
    end, false)
end
