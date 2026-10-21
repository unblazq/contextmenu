function unblazqRuleAllows(rule, data)
    if rule == nil then
        return true
    end
    if rule == false then
        return false
    end
    local fw = data.framework or 'standalone'
    local matched = false

    if fw == 'esx' and rule.esx and rule.esx.groups and data.group then
        for _, g in ipairs(rule.esx.groups) do
            if data.group == g then
                matched = true
                break
            end
        end
    end

    if (fw == 'qb' or fw == 'qbox') and rule.qb and rule.qb.permission ~= nil then
        if data.qbPermission == true then
            matched = true
        end
    end

    if rule.jobs and data.jobName then
        for _, j in ipairs(rule.jobs) do
            if j.name == data.jobName then
                local need = j.grade
                if need == nil or (data.jobGrade or 0) >= need then
                    matched = true
                    break
                end
            end
        end
    end

    if rule.esx or rule.qb or rule.jobs then
        return matched
    end

    return true
end
