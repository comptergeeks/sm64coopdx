-- name: First Person Arena (Prototype)
-- description: Mario movement with first-person hitscan combat.\nHost and fighters must share an area.\nMouse 1 or R: fire. /fps: toggle view.\nPrototype: native knockback, no articulated ragdolls yet.
-- incompatible: gamemode camera
-- pausable: false

local C = FpsCombat
local PROTOCOL = 'fps-arena-v1'
local enabled, sequence, nextShot = true, 0, 0
local flashUntil, hitUntil = 0, 0
local history, received, victimCooldown = {}, {}, {}
local cameraSaved

local function tick() return get_global_timer() end
local function server()
    if network_is_server() then return gNetworkPlayers[0] end
    for i = 1, MAX_PLAYERS-1 do
        local np = gNetworkPlayers[i]
        if np.connected and np.type == NPT_SERVER then return np end
    end
end

local function active(i)
    local m, np = gMarioStates[i], gNetworkPlayers[i]
    return np and np.connected and np.currAreaSyncValid and np.currLevelSyncValid
        and is_player_active(m) ~= 0 and m.health > 0xFF
        and (m.action & ACT_FLAG_INTANGIBLE) == 0
end

local function input_ready()
    return enabled and active(0) and not is_game_paused()
        and not djui_is_chatbox_open() and not djui_hud_is_pause_menu_created()
        and get_first_person_enabled()
end

local function configure_camera()
    if not cameraSaved then
        cameraSaved = {enabled=gFirstPersonCamera.enabled, roll=gFirstPersonCamera.forceRoll,
            center=gFirstPersonCamera.centerL, fov=gFirstPersonCamera.fov}
    end
    set_first_person_enabled(true)
    gFirstPersonCamera.forceRoll = true
    gFirstPersonCamera.centerL = false
    gFirstPersonCamera.fov = 80
    camera_config_enable_mouse_look(true)
end

local function restore_camera()
    if not cameraSaved then return end
    set_first_person_enabled(cameraSaved.enabled)
    gFirstPersonCamera.forceRoll = cameraSaved.roll
    gFirstPersonCamera.centerL = cameraSaved.center
    gFirstPersonCamera.fov = cameraSaved.fov
    camera_reset_overrides()
    cameraSaved = nil
end

local function receive_result(p)
    if not C.valid_shot(p) or not C.finite(p.victim) or not C.finite(p.victimEpoch) then return end
    local host = server()
    local shooter = network_player_from_global_index(p.shooter)
    local me = gNetworkPlayers[0]
    if not host or not shooter or not C.same_area(host, me) or not C.same_area(shooter, me) then return end
    if shooter.currLevelAreaSeqId ~= p.epoch then return end
    if received[p.shooter] and p.seq <= received[p.shooter] then return end
    received[p.shooter] = p.seq
    if p.shooter == me.globalIndex and p.victim >= 0 then hitUntil = tick()+6 end
    if p.victim ~= me.globalIndex or p.victimEpoch ~= me.currLevelAreaSeqId or not active(0) then return end
    local m = gMarioStates[0]
    if m.invincTimer > 0 then return end
    m.health = math.max(0xFF, m.health-C.DAMAGE)
    m.invincTimer = 20
    -- Transitional native knockback. An articulated ragdoll will replace this later.
    if (m.action & ACT_FLAG_SWIMMING) == 0 then
        m.faceAngle.y = atan2s(-p.dz, -p.dx)
        set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
        m.forwardVel = -45
        m.vel.y = 25
    end
    play_sound(SOUND_OBJ_BULLY_METAL, m.marioObj.header.gfx.cameraToObject)
end

local function resolve_shot(p)
    if not network_is_server() or not C.valid_shot(p) then return end
    local np = network_player_from_global_index(p.shooter)
    if not np or not active(np.localIndex) or not C.same_area(np, gNetworkPlayers[0]) then return end
    if np.currLevelAreaSeqId ~= p.epoch then return end
    local m = gMarioStates[np.localIndex]
    local origin, direction = {x=p.ox, y=p.oy, z=p.oz}, {x=p.dx, y=p.dy, z=p.dz}
    -- Allow modest snapshot drift, but never accept arbitrary remote shot origins.
    if C.distance(origin, {x=m.pos.x, y=m.pos.y+90, z=m.pos.z}) > 200 then return end
    if not C.admit(history, p, tick()) then return end
    local collision = collision_find_surface_on_ray(origin.x, origin.y, origin.z,
        direction.x*C.RANGE, direction.y*C.RANGE, direction.z*C.RANGE)
    local wallDistance = C.RANGE
    if collision.surface then wallDistance = C.distance(origin, collision.hitPos) end
    local players = {}
    for i = 0, MAX_PLAYERS-1 do
        if i ~= np.localIndex and active(i) then
            local target, targetNp = gMarioStates[i], gNetworkPlayers[i]
            if C.same_area(np, targetNp) then
                players[#players+1] = {id=targetNp.globalIndex, pos=target.pos,
                    height=mario_is_crouching(target) and 100 or 160}
            end
        end
    end
    local victim = C.pick_target(origin, direction, players, wallDistance)
    local victimEpoch = -1
    if victim then
        local targetNp = network_player_from_global_index(victim)
        local target = gMarioStates[targetNp.localIndex]
        if target.invincTimer > 0 or (victimCooldown[victim] or 0) > tick() then
            victim = nil
        else
            victimEpoch = targetNp.currLevelAreaSeqId
            victimCooldown[victim] = tick()+20
        end
    end
    p.protocol, p.kind, p.victim, p.victimEpoch = PROTOCOL, 'result', victim or -1, victimEpoch
    network_send(true, p)
    receive_result(p)
end

local function fire()
    if tick() < nextShot then return end
    local host, np = server(), gNetworkPlayers[0]
    if not host or not C.same_area(host, np) then return end
    nextShot, sequence, flashUntil = tick()+C.COOLDOWN, sequence+1, tick()+3
    local camera = gFirstPersonCamera
    local m = gMarioStates[0]
    local dx = -coss(camera.pitch)*sins(camera.yaw)
    local dy = -sins(camera.pitch)
    local dz = -coss(camera.pitch)*coss(camera.yaw)
    local length = math.sqrt(dx*dx+dy*dy+dz*dz)
    local p = {protocol=PROTOCOL, kind='shot', shooter=np.globalIndex, seq=sequence,
        epoch=np.currLevelAreaSeqId, ox=m.pos.x, oy=m.pos.y+120-camera.crouch, oz=m.pos.z,
        dx=dx/length, dy=dy/length, dz=dz/length}
    play_sound(SOUND_OBJ_POUNDING_CANNON, m.marioObj.header.gfx.cameraToObject)
    if network_is_server() then resolve_shot(p) else network_send_to(host.localIndex, true, p) end
end

local function before_mario(m)
    if m.playerIndex ~= 0 or not input_ready() then return end
    local shooting = (m.controller.buttonDown & R_TRIG) ~= 0
        or (djui_hud_get_mouse_buttons_down() & 1) ~= 0
    if shooting then fire() end
    m.controller.buttonPressed = m.controller.buttonPressed & ~R_TRIG
    m.controller.buttonDown = m.controller.buttonDown & ~R_TRIG
end

local function packet(p)
    if type(p) ~= 'table' or p.protocol ~= PROTOCOL then return end
    if p.kind == 'shot' then resolve_shot(p)
    elseif p.kind == 'result' and not network_is_server() then receive_result(p) end
end

local function hud()
    if not enabled or not get_first_person_enabled() or not active(0) then return end
    if djui_is_chatbox_open() or djui_hud_is_pause_menu_created() then return end
    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_NORMAL)
    local w, h = djui_hud_get_screen_width(), djui_hud_get_screen_height()
    local x, y = w/2, h/2
    if tick() < hitUntil then djui_hud_set_color(255, 90, 70, 255)
    else djui_hud_set_color(255, 255, 255, 230) end
    djui_hud_render_rect(x-7, y-1, 4, 2)
    djui_hud_render_rect(x+3, y-1, 4, 2)
    djui_hud_render_rect(x-1, y-7, 2, 4)
    djui_hud_render_rect(x-1, y+3, 2, 4)
    if tick() < flashUntil then
        djui_hud_set_color(255, 200, 80, 180)
        djui_hud_render_rect(x-2, y-2, 4, 4)
    end
    djui_hud_set_color(255, 255, 255, 230)
    local host = server()
    local label = host and C.same_area(host, gNetworkPlayers[0])
        and 'MOUSE 1 / R: FIRE   /fps: VIEW' or 'JOIN THE HOST IN THE SAME AREA TO FIGHT'
    djui_hud_print_text(label, 8, h-20, 0.35)
end

local function reset_player(m)
    local id = gNetworkPlayers[m.playerIndex].globalIndex
    history[id], received[id], victimCooldown[id] = nil, nil, nil
end

hook_event(HOOK_ON_SYNC_VALID, function()
    if enabled then configure_camera() end
end)
hook_event(HOOK_ON_WARP, function()
    nextShot = tick()+30
    if enabled then configure_camera() end
end)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario)
hook_event(HOOK_ON_PACKET_RECEIVE, packet)
hook_event(HOOK_ON_HUD_RENDER, hud)
hook_event(HOOK_ON_PLAYER_CONNECTED, reset_player)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, reset_player)
hook_event(HOOK_ON_EXIT, restore_camera)
hook_chat_command('fps', 'Toggle first-person view (combat requires first-person).', function()
    enabled = not enabled
    if enabled then configure_camera() else restore_camera() end
    djui_chat_message_create('First Person Arena: '..(enabled and 'ON' or 'OFF'))
    return true
end)
