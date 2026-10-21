local ESX
local QBCore

local function initFrameworkObjects()
    local fw = unblazqServerFrameworkName or 'standalone'
    if fw == 'esx' then
        pcall(function()
            ESX = exports['es_extended']:getSharedObject()
        end)
    end
    if fw == 'qb' or fw == 'qbox' then
        pcall(function()
            QBCore = exports['qb-core']:GetCoreObject()
        end)
        if not QBCore then
            pcall(function()
                QBCore = exports['qbx_core']:GetCoreObject()
            end)
        end
    end
end

local function getPlayerContext(source)
    local fw = unblazqServerFrameworkName or 'standalone'
    local data = {
        framework = fw,
        group = nil,
        jobName = nil,
        jobGrade = nil,
        qbPermission = false,
    }

    if fw == 'esx' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            if xPlayer.getGroup then
                data.group = xPlayer.getGroup()
            end
            if xPlayer.job then
                data.jobName = xPlayer.job.name
                data.jobGrade = xPlayer.job.grade
            end
        end
        return data
    end

    if (fw == 'qb' or fw == 'qbox') and QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player and Player.PlayerData then
            local pd = Player.PlayerData
            if pd.job then
                data.jobName = pd.job.name
                local g = pd.job.grade
                if type(g) == 'table' then
                    data.jobGrade = g.level
                else
                    data.jobGrade = g
                end
            end
        end
        return data
    end

    return data
end

function unblazqServerCheckPermission(source, key)
    if not ESX and not QBCore then
        initFrameworkObjects()
    end

    local rule = Config.PermissionRules and Config.PermissionRules[key]
    if rule == nil then
        return true
    end

    local data = getPlayerContext(source)
    local fw = data.framework

    if (fw == 'qb' or fw == 'qbox') and QBCore and rule.qb and rule.qb.permission then
        local ok, has = pcall(function()
            return QBCore.Functions.HasPermission(source, rule.qb.permission)
        end)
        data.qbPermission = ok and has == true
    end

    return unblazqRuleAllows(rule, data)
end

CreateThread(function()
    initFrameworkObjects()
end)

RegisterNetEvent('unblazq-contextmenu:server:perm', function(key, rid)
    local src = source
    if type(key) ~= 'string' or type(rid) ~= 'number' then
        return
    end
    local ok = unblazqServerCheckPermission(src, key)
    TriggerClientEvent('unblazq-contextmenu:client:perm', src, rid, ok)
end)

exports('ServerHasPermission', unblazqServerCheckPermission)
