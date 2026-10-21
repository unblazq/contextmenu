unblazq = unblazq or {}

local function started(name)
    return GetResourceState(name) == 'started'
end

function unblazq.ResolveFramework()
    local mode = Config and Config.Framework or 'auto'
    if type(mode) ~= 'string' then
        return 'standalone'
    end
    mode = mode:lower()
    if mode ~= 'auto' then
        return mode
    end
    if started('qb-core') then
        return 'qb'
    end
    if started('qbx_core') then
        return 'qbox'
    end
    if started('es_extended') then
        return 'esx'
    end
    if started('ox_core') then
        return 'ox'
    end
    if started('nd_core') then
        return 'nd'
    end
    return 'standalone'
end
