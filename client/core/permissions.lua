local FW

local permPending = {}

RegisterNetEvent('unblazq-contextmenu:client:perm', function(rid, ok)
    if type(rid) == 'number' then
        permPending[rid] = ok
    end
end)

local function getFwTable()
    if not FW then
        FW = exports['unblazq-contextmenu']:GetFramework()
    end
    return FW
end

local function clientContext()
    local f = getFwTable()
    local name = f.GetName and f.GetName() or 'standalone'
    local pd = f.GetPlayerData and f.GetPlayerData() or nil
    local data = {
        framework = name,
        group = nil,
        jobName = nil,
        jobGrade = nil,
        qbPermission = false,
    }
    if not pd then
        return data
    end
    if name == 'esx' then
        data.group = pd.group
        if pd.job then
            data.jobName = pd.job.name
            data.jobGrade = pd.job.grade
        end
    elseif name == 'qb' or name == 'qbox' then
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

function unblazqClientCheckPermission(key)
    local rule = Config.PermissionRules and Config.PermissionRules[key]
    if rule == nil then
        return true
    end
    local data = clientContext()
    if (data.framework == 'qb' or data.framework == 'qbox') and rule.qb and rule.qb.permission then
        data.qbPermission = false
    end
    return unblazqRuleAllows(rule, data)
end

function unblazqHasPermission(key)
    if type(key) ~= 'string' then
        return false
    end
    if Config.PermissionMode == 'client' then
        return unblazqClientCheckPermission(key)
    end

    local rid = math.random(1, 2147483646)
    permPending[rid] = nil
    TriggerServerEvent('unblazq-contextmenu:server:perm', key, rid)
    local t = GetGameTimer() + 4000
    while permPending[rid] == nil and GetGameTimer() < t do
        Wait(25)
    end
    local v = permPending[rid]
    permPending[rid] = nil
    return v == true
end

exports('HasPermission', unblazqHasPermission)
exports('ClientCheckPermission', unblazqClientCheckPermission)
