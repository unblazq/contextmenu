
unblazqLastRayDebug = nil

function unblazqGetCursorScreenPosition()
    if not IsControlEnabled(0, 239) then
        EnableControlAction(0, 239, true)
    end
    if not IsControlEnabled(0, 240) then
        EnableControlAction(0, 240, true)
    end
    return vector2(GetControlNormal(0, 239), GetControlNormal(0, 240))
end

local function unblazqDegreesToRadians(degrees)
    return (degrees * 3.14) / 180.0
end

function unblazqScreenToWorld(screenPosition, maxDistance)
    local pos = GetFinalRenderedCamCoord()
    local rot = GetFinalRenderedCamRot(0)
    local fov = GetFinalRenderedCamFov()
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, fov, 0, 2)
    local camRight, camForward, camUp, camPos = GetCamMatrix(cam)
    DestroyCam(cam, true)

    local sp = vector2(screenPosition.x - 0.5, screenPosition.y - 0.5) * 2.0
    local fovRadians = unblazqDegreesToRadians(fov)
    local to = camPos + camForward + (camRight * sp.x * fovRadians * GetAspectRatio(false) * 0.534375) - (camUp * sp.y * fovRadians * 0.534375)
    local direction = (to - camPos) * maxDistance
    local endPoint = camPos + direction

    local rayHandle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, endPoint.x, endPoint.y, endPoint.z, -1, nil, 0)
    local retval, hit, worldPosition, normalDirection, entity = GetShapeTestResult(rayHandle)
    if retval == 0 then
        Wait(1)
        retval, hit, worldPosition, normalDirection, entity = GetShapeTestResult(rayHandle)
    end

    local entityValid = entity ~= nil and entity ~= 0 and DoesEntityExist(entity)
    unblazqLastRayDebug = {
        retval = retval,
        hitRaw = hit,
        hitType = type(hit),
        hitOk = (hit == true or hit == 1),
        worldPosition = worldPosition,
        normalDirection = normalDirection,
        entity = entity,
        entityValid = entityValid,
        isPed = entityValid and IsEntityAPed(entity) or false,
        isVehicle = entityValid and IsEntityAVehicle(entity) or false,
    }

    if hit == true or hit == 1 then
        return true, worldPosition, normalDirection, entity
    end
    return false, vector3(0, 0, 0), vector3(0, 0, 0), nil
end
