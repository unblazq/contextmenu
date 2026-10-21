local function started(name)
    return GetResourceState(name) == 'started'
end

local FW = {
    name = 'standalone',
    ready = false,
}

local ESX
local QBCore

local function tryEsx()
    local ok, obj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if ok and obj then
        ESX = obj
        FW.name = 'esx'
        return true
    end
    return false
end

local function tryQbPair(explicit)
    local ok, obj = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok and obj then
        QBCore = obj
        if explicit == 'qbox' or started('qbx_core') then
            FW.name = 'qbox'
        else
            FW.name = 'qb'
        end
        return true
    end
    ok, obj = pcall(function()
        return exports['qbx_core']:GetCoreObject()
    end)
    if ok and obj then
        QBCore = obj
        FW.name = 'qbox'
        return true
    end
    return false
end

function FW.Init()
    local requested = unblazq.ResolveFramework()
    FW.name = requested
    FW.ready = false

    if requested == 'standalone' or requested == 'unknown' then
        FW.ready = true
        return
    end

    if requested == 'esx' then
        if tryEsx() then
            FW.ready = true
        else
            FW.name = 'standalone'
            FW.ready = true
        end
        return
    end

    if requested == 'qb' or requested == 'qbox' then
        if tryQbPair(requested) then
            FW.ready = true
        else
            FW.name = 'standalone'
            FW.ready = true
        end
        return
    end

    if requested == 'ox' then
        FW.name = 'ox'
        FW.ready = started('ox_core')
        return
    end

    if requested == 'nd' then
        FW.name = 'nd'
        FW.ready = started('nd_core')
        return
    end
end

function FW.GetPlayerData()
    if FW.name == 'esx' and ESX then
        if ESX.GetPlayerData then
            return ESX.GetPlayerData()
        end
        return ESX.PlayerData
    end
    if (FW.name == 'qb' or FW.name == 'qbox') and QBCore and QBCore.Functions then
        return QBCore.Functions.GetPlayerData()
    end
    return nil
end

function FW.GetJobName()
    local pd = FW.GetPlayerData()
    if not pd or not pd.job then
        return nil
    end
    return pd.job.name
end

function FW.GetJobGrade()
    local pd = FW.GetPlayerData()
    if not pd or not pd.job then
        return nil
    end
    if FW.name == 'esx' then
        return pd.job.grade
    end
    if FW.name == 'qb' or FW.name == 'qbox' then
        local g = pd.job.grade
        if type(g) == 'table' then
            return g.level
        end
        return g
    end
    return nil
end

function FW.IsPlayerLoaded()
    if not FW.ready then
        return false
    end
    if FW.name == 'standalone' or FW.name == 'ox' or FW.name == 'nd' then
        return true
    end
    local pd = FW.GetPlayerData()
    if not pd then
        return false
    end
    if FW.name == 'esx' then
        return pd.identifier ~= nil or pd.citizenid ~= nil
    end
    if FW.name == 'qb' or FW.name == 'qbox' then
        return pd.citizenid ~= nil or pd.license ~= nil or pd.charinfo ~= nil
    end
    return true
end

function FW.GetName()
    return FW.name
end

CreateThread(function()
    FW.Init()
    TriggerEvent('unblazq-contextmenu:client:frameworkReady', FW.name, FW)
end)

RegisterNetEvent('esx:playerLoaded', function()
    if FW.name == 'esx' then
        FW.ready = true
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if FW.name == 'qb' or FW.name == 'qbox' then
        FW.ready = true
    end
end)

exports('GetFramework', function()
    return FW
end)
exports('GetFrameworkName', function()
    return FW.name
end)
exports('GetPlayerData', FW.GetPlayerData)
exports('GetJobName', FW.GetJobName)
exports('GetJobGrade', FW.GetJobGrade)
exports('IsPlayerLoaded', FW.IsPlayerLoaded)
exports('Framework', function()
    return FW
end)
