-- Optional real-engine probe. Copy as a-probe.lua into an ISOLATED build's
-- third-person-arena mod, then start a host and a client in Castle Grounds.
-- Never ship/enable this fixture in a normal game: it pins players and fires.
local ticks, previous, hits = 0, nil, 0
-- Exclude real mouse clicks while the two windows are being opened/focused.
djui_hud_get_mouse_buttons_down = function() return 0 end
hook_event(HOOK_BEFORE_MARIO_UPDATE, function(m)
    if m.playerIndex ~= 0 then return end
    local me = gNetworkPlayers[0]
    if not me.currAreaSyncValid or not me.currLevelSyncValid then return end
    local other
    for i=1,MAX_PLAYERS-1 do
        if gNetworkPlayers[i].connected and is_player_active(gMarioStates[i]) ~= 0 then other=i; break end
    end
    if not other then return end
    ticks=ticks+1
    if previous and m.health < previous then
        hits=hits+1
        print('TPS_PROBE HIT local='..me.globalIndex..' health='..m.health..' hits='..hits)
    end
    previous=m.health
    m.pos.x, m.pos.y = -1328, 260
    m.pos.z = network_is_server() and 4664 or 4964
    m.vel.x, m.vel.y, m.vel.z, m.forwardVel = 0,0,0,0
    set_mario_action(m, ACT_IDLE, 0)
    ThirdPersonCamera.pitch=0
    ThirdPersonCamera.yaw=network_is_server() and 0 or math.pi
    m.controller.buttonDown=0
    m.controller.buttonPressed=0
    if ticks==180 then
        m.controller.buttonDown=R_TRIG
        print('TPS_PROBE FIRE local='..me.globalIndex)
    end
    if ticks==270 then
        print('TPS_PROBE '..(hits==1 and 'PASS' or 'FAIL')..' local='..me.globalIndex..' hits='..hits)
    end
end)
