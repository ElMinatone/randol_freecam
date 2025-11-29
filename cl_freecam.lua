local Config = lib.load('config')
local FREE_CAM
local offsetRotX, offsetRotY, offsetRotZ = 0.0, 0.0, 0.0
local offsetCoords = {x = 0.0, y = 0.0, z = 0.0}
local precision = 1.0
local speed = 1.0
local currFilter = 1
local currPrecisionIndex = 17
local playerControl = false
local fixedCam = false
local fixedEntity = 0
local fixedOffsetX, fixedOffsetY, fixedOffsetZ = 0.0, 0.0, 0.0
local fixedRotOffsetX, fixedRotOffsetY, fixedRotOffsetZ = 0.0, 0.0, 0.0
local fixedCamFov = 0.0
local camActive = false
local dofOn = false
local dofStrength = 0.5
local dofFar = 150.0
local dofNear = 0.10
local barsOn = false

local function toggleMap()
    local isRadarVisible = not IsRadarHidden()
    DisplayRadar(not isRadarVisible)
end

local function toggleBars()
    barsOn = not barsOn
    if barsOn then
        while barsOn do
            DrawRect(1.0, 1.0, 2.0, 0.23, 0, 0, 0, 255)
            DrawRect(1.0, 0.0, 2.0, 0.23, 0, 0, 0, 255)
            Wait(0)
        end
    end
end

local function resetEverything()
    ClearFocus()
    SetCamUseShallowDofMode(FREE_CAM, false)
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(FREE_CAM, false)
    offsetRotX = 0.0
    offsetRotY = 0.0
    offsetRotZ = 0.0
    speed = 1.0
    precision = 1.0
    currFov = GetGameplayCamFov()
    currFilter = 1
    ClearTimecycleModifier()
    FREE_CAM = nil
    dofStrength = 0.5
    dofFar = 150.0
    dofNear = 0.10
    dofOn = false
    barsOn = false
end

local function setNewFov(setNewFov)
    if DoesCamExist(FREE_CAM) then
        local currFov = GetCamFov(FREE_CAM)
        local newFov = currFov + setNewFov

        if ((newFov >= Config.MinFov) and (newFov <= Config.MaxFov)) then
            SetCamFov(FREE_CAM, newFov)
        end
    end
end

local function toggleDof()
    dofOn = not dofOn
    if dofOn then
        if DoesCamExist(FREE_CAM) then
            SetCamUseShallowDofMode(FREE_CAM, true)
            SetCamNearDof(FREE_CAM, dofNear)
            SetCamFarDof(FREE_CAM, dofFar)
            SetCamDofStrength(FREE_CAM, dofStrength)
        end
    else
        dofStrength = 0.5
        dofFar = 150.0
        dofNear = 0.10
        SetCamNearDof(FREE_CAM, dofNear)
        SetCamFarDof(FREE_CAM, dofFar)
        SetCamDofStrength(FREE_CAM, dofStrength)
        SetCamUseShallowDofMode(FREE_CAM, false)
        ClearFocus()
    end
end

local function processNewPos(x, y, z)
    local newPos = {x = x, y = y, z = z}
    local moveSpeed = 0.1 * speed * precision

    local function updatePosition(multX, multY, multZ, direction)
        newPos.x = newPos.x + direction * moveSpeed * multX
        newPos.y = newPos.y - direction * moveSpeed * multY
    end

    if IsDisabledControlPressed(1, 32) then -- W (forwards)
        updatePosition(Sin(offsetRotZ), Cos(offsetRotZ), Sin(offsetRotX), -1)
    elseif IsDisabledControlPressed(1, 33) then -- S (backwards)
        updatePosition(Sin(offsetRotZ), Cos(offsetRotZ), Sin(offsetRotX), 1)
    end

    if IsDisabledControlPressed(1, 34) then -- A (left)
        updatePosition(Sin(offsetRotZ + 90.0), Cos(offsetRotZ + 90.0), Sin(offsetRotY), -1)
    elseif IsDisabledControlPressed(1, 35) then -- D (right)
        updatePosition(Sin(offsetRotZ + 90.0), Cos(offsetRotZ + 90.0), Sin(offsetRotY), 1)
    end

    if IsDisabledControlPressed(1, 22) then -- Space (up)
        newPos.z += moveSpeed
    elseif IsDisabledControlPressed(1, 36) then -- LCTRL (down)
        newPos.z -= moveSpeed
    end

    if IsDisabledControlPressed(1, 21) then -- Shift (hold)
        if IsDisabledControlPressed(1, 15) then -- Mouse wheel up (speed up)
            speed = math.min(speed + 0.1, Config.MaxSpeed)
        elseif IsDisabledControlPressed(1, 14) then -- Mouse wheel down (speed down)
            speed = math.max(speed - 0.1, Config.MinSpeed)
        end
    else
        if IsDisabledControlPressed(1, 15) then -- Mouse wheel up (zoom in)
            setNewFov(-1.0)
        elseif IsDisabledControlPressed(1, 14) then -- Mouse wheel down (zoom out)
            setNewFov(1.0)
        end
    end

    offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision * 8.0)
    offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision * 8.0)

    if IsDisabledControlPressed(1, 44) then -- Q (roll left)
        offsetRotY = offsetRotY - precision
    elseif IsDisabledControlPressed(1, 38) then -- E (roll right)
        offsetRotY = offsetRotY + precision
    end

    offsetRotX = math.clamp(offsetRotX, -90.0, 90.0)
    offsetRotY = math.clamp(offsetRotY, -90.0, 90.0)
    offsetRotZ = offsetRotZ % 360.0

    return newPos
end

local function processCamControls()
    DisableFirstPersonCamThisFrame()

    local camCoords = GetCamCoord(FREE_CAM)
    if fixedCam then
        if not DoesEntityExist(fixedEntity) then
            fixedCam = false
            fixedEntity = 0
        else
            local world = GetOffsetFromEntityInWorldCoords(fixedEntity, fixedOffsetX, fixedOffsetY, fixedOffsetZ)
            SetFocusArea(world.x, world.y, world.z, 0.0, 0.0, 0.0)
            SetCamCoord(FREE_CAM, world.x, world.y, world.z)
            if not playerControl then
                offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision * 8.0)
                offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision * 8.0)
                if IsDisabledControlPressed(1, 44) then
                    offsetRotY = offsetRotY - precision
                elseif IsDisabledControlPressed(1, 38) then
                    offsetRotY = offsetRotY + precision
                end
                if IsDisabledControlPressed(1, 21) then
                    if IsDisabledControlPressed(1, 15) then
                        speed = math.min(speed + 0.1, Config.MaxSpeed)
                    elseif IsDisabledControlPressed(1, 14) then
                        speed = math.max(speed - 0.1, Config.MinSpeed)
                    end
                else
                    if IsDisabledControlPressed(1, 15) then
                        setNewFov(-1.0)
                    elseif IsDisabledControlPressed(1, 14) then
                        setNewFov(1.0)
                    end
                end
            end
            offsetRotX = math.clamp(offsetRotX, -90.0, 90.0)
            offsetRotY = math.clamp(offsetRotY, -90.0, 90.0)
            offsetRotZ = offsetRotZ % 360.0
            local er = GetEntityRotation(fixedEntity, 2)
            SetCamRot(FREE_CAM, er.x + fixedRotOffsetX + offsetRotX, er.y + fixedRotOffsetY + offsetRotY, er.z + fixedRotOffsetZ + offsetRotZ, 2)
        end
        if not playerControl then
            for k, v in pairs(Config.DisabledControls) do
                DisableControlAction(0, v, true)
            end
        end
    elseif playerControl then
        SetFocusArea(camCoords.x, camCoords.y, camCoords.z, 0.0, 0.0, 0.0)
        SetCamCoord(FREE_CAM, camCoords.x, camCoords.y, camCoords.z)
        SetCamRot(FREE_CAM, offsetRotX, offsetRotY, offsetRotZ, 2)
    else
        local newPos = processNewPos(camCoords.x, camCoords.y, camCoords.z)
        SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)
        SetCamCoord(FREE_CAM, newPos.x, newPos.y, newPos.z)
        SetCamRot(FREE_CAM, offsetRotX, offsetRotY, offsetRotZ, 2)

        for k, v in pairs(Config.DisabledControls) do
            DisableControlAction(0, v, true)
        end

        local currentPos = GetEntityCoords(cache.ped)
        if #(currentPos - vec3(newPos.x, newPos.y, newPos.z)) > Config.MaxDistance then
            camActive = false
            lib.hideMenu()
        end
    end

    if dofOn then
        SetUseHiDof()
    end
end

local function toggleCam()
    camActive = not camActive
    if camActive then
        ClearFocus()
        local selPrec = tonumber(Config.PrecisionOptions[currPrecisionIndex])
        if selPrec then precision = selPrec end
        FREE_CAM = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', GetEntityCoords(cache.ped), 0, 0, 0, GetGameplayCamFov() * 1.0)
        SetCamActive(FREE_CAM, true)
        RenderScriptCams(true, false, 0, true, false)
        SetCamAffectsAiming(FREE_CAM, false)

        CreateThread(function()
            while camActive do
                processCamControls()
                Wait(0)
            end
            resetEverything()
        end)
    else
        if fixedCam then
            DetachCam(FREE_CAM)
            fixedCam = false
            fixedEntity = 0
        end
    end
end
 
local function camForward()
    local rx, rz
    if DoesCamExist(FREE_CAM) then
        local cr = GetCamRot(FREE_CAM, 2)
        rx = math.rad(cr.x)
        rz = math.rad(cr.z)
    else
        local gr = GetGameplayCamRot(2)
        rx = math.rad(gr.x)
        rz = math.rad(gr.z)
    end
    local cx = -math.sin(rz) * math.cos(rx)
    local cy = math.cos(rz) * math.cos(rx)
    local cz = math.sin(rx)
    return vec3(cx, cy, cz)
end

local function getCenterEntity()
    local origin
    if DoesCamExist(FREE_CAM) then
        origin = GetCamCoord(FREE_CAM)
    else
        origin = GetGameplayCamCoord()
    end
    local dir = camForward()
    local dest = origin + dir * 500.0
    local ray = StartShapeTestRay(origin.x, origin.y, origin.z, dest.x, dest.y, dest.z, -1, 0, 7)
    local _, hit, _, _, ent = GetShapeTestResult(ray)
    if debugFreecam then
        print(('[freecam] ray hit=%s ent=%s from=(%.2f,%.2f,%.2f) to=(%.2f,%.2f,%.2f)'):format(tostring(hit), tostring(ent), origin.x, origin.y, origin.z, dest.x, dest.y, dest.z))
    end
    if hit == 1 and ent ~= 0 then return ent end
    return 0
end

local function entityLabel(ent)
    if ent == 0 then return 'None' end
    if IsEntityAVehicle(ent) then return 'Vehicle' end
    if IsEntityAnObject(ent) then return 'Prop' end
    if IsEntityAPed(ent) then
        if IsPedAPlayer(ent) then return 'Player' end
        return 'Ped'
    end
    return 'Entity'
end

local function toLocalOffset(ent, camPos)
    if not DoesEntityExist(ent) then return 0.0, 0.0, 0.0 end
    local off = GetOffsetFromEntityGivenWorldCoords(ent, camPos.x, camPos.y, camPos.z)
    if debugFreecam then
        local pos = GetEntityCoords(ent)
        print(('[freecam] toLocalOffset ent=%s entPos=(%.2f,%.2f,%.2f) camPos=(%.2f,%.2f,%.2f) off=(%.3f,%.3f,%.3f)'):format(tostring(ent), pos.x, pos.y, pos.z, camPos.x, camPos.y, camPos.z, off.x, off.y, off.z))
    end
    return off.x, off.y, off.z
end

RegisterCommand(Config.CommandName, function()
    lib.registerMenu({
        id = 'cinematic_cam_menu',
        title = 'Câmera Cinematográfica',
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
            if selected == 5 then
                currFilter = scrollIndex
                if camActive and DoesCamExist(FREE_CAM) then
                    SetTimecycleModifier(Config.Filters[scrollIndex])
                end
            elseif selected == 9 then
                if camActive and DoesCamExist(FREE_CAM) then
                    dofNear = tonumber(Config.NearDof[scrollIndex])
                    SetCamNearDof(FREE_CAM, dofNear)
                end
            elseif selected == 10 then
                if camActive and DoesCamExist(FREE_CAM) then
                    dofFar = tonumber(Config.FarDof[scrollIndex])
                    SetCamFarDof(FREE_CAM, dofFar)
                end
            elseif selected == 11 then
                if camActive and DoesCamExist(FREE_CAM) then
                    dofStrength = tonumber(Config.StrengthDof[scrollIndex])
                    SetCamDofStrength(FREE_CAM, dofStrength)
                end
            elseif selected == 2 then
                currPrecisionIndex = scrollIndex
                local newPrecision = tonumber(Config.PrecisionOptions[scrollIndex]) or 1.0
                if camActive then
                    precision = newPrecision
                end
            end
        end,
        onCheck = function(selected, checked, args)
            if selected == 1 then
                toggleCam()
                if camActive then
                    SetNuiFocus(false, false)
                else
                    SetNuiFocus(true, true)
                end
            elseif selected == 6 then
                toggleDof()
            elseif selected == 7 then
                toggleBars()
            elseif selected == 8 then
                toggleMap()
            elseif selected == 4 then
                playerControl = checked
            elseif selected == 3 then
                if checked then
                    if camActive and DoesCamExist(FREE_CAM) then
                        local ent = getCenterEntity()
                        if ent == 0 then ent = cache.ped end
                        if ent ~= 0 and DoesEntityExist(ent) then
                            local cx, cy, cz = GetCamCoord(FREE_CAM)
                            local offX, offY, offZ = toLocalOffset(ent, { x = cx, y = cy, z = cz })
                            fixedOffsetX = type(offX) == 'number' and offX or 0.0
                            fixedOffsetY = type(offY) == 'number' and offY or 0.0
                            fixedOffsetZ = type(offZ) == 'number' and offZ or 0.0
                            local cr = GetCamRot(FREE_CAM, 2)
                            local er = GetEntityRotation(ent, 2)
                            fixedRotOffsetX = cr.x - er.x
                            fixedRotOffsetY = cr.y - er.y
                            fixedRotOffsetZ = cr.z - er.z
                            fixedCamFov = GetCamFov(FREE_CAM)
                            fixedCam = true
                            fixedEntity = ent
                        end
                    end
                else
                    fixedCam = false
                    fixedEntity = 0
                    fixedOffsetX, fixedOffsetY, fixedOffsetZ = 0.0, 0.0, 0.0
                    fixedRotOffsetX, fixedRotOffsetY, fixedRotOffsetZ = 0.0, 0.0, 0.0
                    fixedCamFov = 0.0
                end
            end
        end,
        options = {
            {label = 'Ativar/Desativar Câmera', checked = camActive, icon = 'camera'},
            {label = 'Precisão', values = Config.PrecisionOptions, icon = 'gauge-high', defaultIndex = currPrecisionIndex, description = 'Ajustar multiplicador de precisão dos controles.'},
            {label = 'Fixar Câmera', checked = fixedCam, icon = 'crosshairs', description = 'Fixar a câmera ao alvo no centro. Enter alterna.'},
            {label = 'Controle do Jogador', checked = playerControl, icon = 'gamepad', description = 'Permitir mover o jogador enquanto a câmera fica fixa.'},
            {label = 'Filtros de Câmera', values = Config.Filters, icon = 'camera', defaultIndex = currFilter, description = 'Use as setas para navegar. Enter reseta o filtro.'},
            {label = 'Profundidade de Campo', checked = dofOn, icon = 'eye', description = 'Ativar/Desativar efeito de profundidade de campo.'},
            {label = 'Barras Cinematográficas', checked = barsOn, icon = 'film', description = 'Ativar/Desativar barras pretas.'},
            {label = 'Minimapa', checked = not IsRadarHidden(), icon = 'map', description = 'Ativar/Desativar minimapa.'},
            {label = 'DoF Plano Próximo', values = Config.NearDof, icon = 'left-right', description = 'Ajustar distância de foco próximo.'},
            {label = 'DoF Plano Distante', values = Config.FarDof, icon = 'left-right', description = 'Ajustar distância de foco distante.'},
            {label = 'DoF Intensidade', values = Config.StrengthDof, icon = 'left-right', description = 'Ajustar intensidade do efeito.'},
        }
    }, function(selected, scrollIndex, args)
        if selected == 5 then
            local input = lib.inputDialog('Buscar Filtro', {
                {
                    type = 'input',
                    label = 'Nome do filtro',
                    placeholder = 'Ex: night, noir, mineshaft',
                }
            }, { allowCancel = true, confirmLabel = 'Confirmar', cancelLabel = 'Cancelar' })
            local query = input and input[1] and tostring(input[1]):lower()
            local foundIndex = 1
            if query and #query > 0 then
                for i = 1, #Config.Filters do
                    local name = tostring(Config.Filters[i]):lower()
                    if string.find(name, query, 1, true) then
                        foundIndex = i
                        break
                    end
                end
            end
            if foundIndex == 1 then
                if camActive and DoesCamExist(FREE_CAM) then
                    ClearTimecycleModifier()
                end
                currFilter = 1
            else
                if camActive and DoesCamExist(FREE_CAM) then
                    SetTimecycleModifier(Config.Filters[foundIndex])
                    currFilter = foundIndex
                end
            end
            lib.setNuiFocus(true, true)
        elseif selected == 3 then
            if fixedCam then
                fixedCam = false
                fixedEntity = 0
                fixedOffsetX, fixedOffsetY, fixedOffsetZ = 0.0, 0.0, 0.0
                fixedRotOffsetX, fixedRotOffsetY, fixedRotOffsetZ = 0.0, 0.0, 0.0
                fixedCamFov = 0.0
            else
                if camActive and DoesCamExist(FREE_CAM) then
                    local ent = getCenterEntity()
                    if ent == 0 then ent = cache.ped end
                    if ent ~= 0 and DoesEntityExist(ent) then
                        local cx, cy, cz = GetCamCoord(FREE_CAM)
                        local offX, offY, offZ = toLocalOffset(ent, { x = cx, y = cy, z = cz })
                        fixedOffsetX = type(offX) == 'number' and offX or 0.0
                        fixedOffsetY = type(offY) == 'number' and offY or 0.0
                        fixedOffsetZ = type(offZ) == 'number' and offZ or 0.0
                        local cr = GetCamRot(FREE_CAM, 2)
                        local er = GetEntityRotation(ent, 2)
                        fixedRotOffsetX = cr.x - er.x
                        fixedRotOffsetY = cr.y - er.y
                        fixedRotOffsetZ = cr.z - er.z
                        fixedCamFov = GetCamFov(FREE_CAM)
                        fixedCam = true
                        fixedEntity = ent
                    end
                end
            end
        end
    end)
    if not camActive then
        SetNuiFocus(true, true)
    end
    lib.showMenu('cinematic_cam_menu')
    
end)

AddEventHandler('gameEventTriggered', function(event, data)
    if event ~= 'CEventNetworkEntityDamage' then return end
    local victim, victimDied = data[1], data[4]
    if not IsPedAPlayer(victim) then return end
    if victimDied and NetworkGetPlayerIndexFromPed(victim) == cache.playerId and (IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim)) then
        if DoesCamExist(FREE_CAM) then
            resetEverything()
        end
    end
end)

RegisterCommand('ccamdebug', function()
    lib.closeInputDialog()
    lib.setNuiFocus(true, true)
end)
 
