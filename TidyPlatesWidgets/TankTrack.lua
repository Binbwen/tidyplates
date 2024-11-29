------------------------------
-- Tank Role Tracking
------------------------------


local playerTankRole = false


function TidyPlatesWidgets.IsPlayerTank()
    return playerTankRole
end

local TankWatcher = CreateFrame("Frame", nil, nil)
TankWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
TankWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
TankWatcher:SetScript(
    "OnEvent",
    function(frame, event, ...)
        local oldRole = playerTankRole
        playerTankRole = GetSpecializationRole(GetSpecialization()) == "TANK"
        if playerTankRole ~= oldRole then
            TidyPlates:RequestUpdate()
        end
    end
)
