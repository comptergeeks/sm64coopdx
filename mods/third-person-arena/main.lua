-- name: Third Person Arena (Prototype)
-- description: Third-person shoulder-camera combat with Koopa bots and cosmetic ragdolls.\nMouse 1 or R: fire. L: swap shoulder. /tps: camera. /bots 0-4: bots.\nHost and fighters must share an area.
-- incompatible: gamemode camera
-- pausable: false

local C = FpsCombat
local PROTOCOL = 'tps-arena-v1'
local enabled, sequence, nextShot = true, 0, 0
local flashUntil, hitUntil = 0, 0
local history, received, victimCooldown = {}, {}, {}
FpsArena={}

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
FpsArena.active=active

local function input_ready()
    return enabled and active(0) and not is_game_paused()
        and not djui_is_chatbox_open() and not djui_hud_is_pause_menu_created()
        and ThirdPersonCamera.enabled
end

local function configure_camera()
    ThirdPersonCamera.enable()
end

local function restore_camera()
    ThirdPersonCamera.disable()
end

local function receive_result(p)
    if not C.valid_shot(p) or not C.finite(p.victim) or not C.finite(p.victimEpoch) then return end
    local host = server()
    local botShot=FpsBots and FpsBots.is_id(p.shooter)
    local shooter = botShot and host or network_player_from_global_index(p.shooter)
    local me = gNetworkPlayers[0]
    if not host or not shooter or not C.same_area(host, me) or not C.same_area(shooter, me) then return end
    if shooter.currLevelAreaSeqId ~= p.epoch then return end
    if botShot and (not FpsBots.in_area() or FpsBots.generation(p.shooter)~=p.botGeneration) then return end
    if received[p.shooter] and p.seq <= received[p.shooter] then return end
    received[p.shooter] = p.seq
    if not botShot and p.shooter~=me.globalIndex and FpsWeapon then
        FpsWeapon.flash(gMarioStates[shooter.localIndex],{x=p.dx,y=p.dy,z=p.dz})
    end
    if p.shooter == me.globalIndex and p.victim >= 0 then hitUntil = tick()+6 end
    if p.victim ~= me.globalIndex or p.victimEpoch ~= me.currLevelAreaSeqId or not active(0) then return end
    local m = gMarioStates[0]
    if m.invincTimer > 0 then return end
    m.health = math.max(0xFF, m.health-(botShot and 0x100 or C.DAMAGE))
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

local function ray_target(origin,direction,exclude,withBots)
    local collision = collision_find_surface_on_ray(origin.x, origin.y, origin.z,
        direction.x*C.RANGE, direction.y*C.RANGE, direction.z*C.RANGE)
    local wallDistance = collision.surface and C.distance(origin, collision.hitPos) or C.RANGE
    local players = {}
    for i = 0, MAX_PLAYERS-1 do
        if i ~= exclude and active(i) then
            local target, targetNp = gMarioStates[i], gNetworkPlayers[i]
            if C.same_area(gNetworkPlayers[0], targetNp) then
                players[#players+1] = {id=targetNp.globalIndex, pos=target.pos,
                    height=mario_is_crouching(target) and 100 or 160}
            end
        end
    end
    if withBots and FpsBots then
        for _,target in ipairs(FpsBots.targets()) do players[#players+1]=target end
    end
    return C.pick_target(origin,direction,players,wallDistance)
end

local botSequences={}
function FpsArena.bot_shot(bot,origin,direction)
    if not network_is_server() then return end
    local victim=ray_target(origin,direction,-1,false)
    if not victim then return end
    local targetNp=network_player_from_global_index(victim)
    local target=gMarioStates[targetNp.localIndex]
    if target.invincTimer>0 or (victimCooldown[victim] or 0)>tick() then return end
    victimCooldown[victim]=tick()+20
    local id=FpsBots.id(bot.index)
    botSequences[id]=(botSequences[id] or 0)+1
    local p={protocol=PROTOCOL,kind='result',shooter=id,seq=botSequences[id],
        epoch=gNetworkPlayers[0].currLevelAreaSeqId,botGeneration=bot.generation,
        victim=victim,victimEpoch=targetNp.currLevelAreaSeqId,
        ox=origin.x,oy=origin.y,oz=origin.z,dx=direction.x,dy=direction.y,dz=direction.z}
    network_send(true,p)
    receive_result(p)
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
    if FpsBots then gGlobalSyncTable.fpsBotAwake=true end
    local victim = ray_target(origin,direction,np.localIndex,true)
    local victimEpoch = -1
    if victim and FpsBots and FpsBots.is_id(victim) then
        victimEpoch=FpsBots.generation(victim) or -1
        if not FpsBots.damage(victim,direction) then victim=nil end
    elseif victim then
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
    if FpsWeapon then FpsWeapon.lastShot=tick() end
    local camera = ThirdPersonCamera
    local m = gMarioStates[0]
    local _,distance=ray_target(camera.pos,camera.direction,0,true)
    local aim={x=camera.pos.x+camera.direction.x*(distance+2),
        y=camera.pos.y+camera.direction.y*(distance+2),z=camera.pos.z+camera.direction.z*(distance+2)}
    local origin=FpsWeapon.muzzle(m,camera.direction)
    -- The shoulder can see around cover that the muzzle cannot shoot through.
    local obstruction=collision_find_surface_on_ray(m.pos.x,m.pos.y+90,m.pos.z,
        origin.x-m.pos.x,origin.y-(m.pos.y+90),origin.z-m.pos.z)
    if obstruction.surface then origin={x=m.pos.x,y=m.pos.y+90,z=m.pos.z} end
    local dx,dy,dz=aim.x-origin.x,aim.y-origin.y,aim.z-origin.z
    local length = math.max(0.001,math.sqrt(dx*dx+dy*dy+dz*dz))
    local p = {protocol=PROTOCOL, kind='shot', shooter=np.globalIndex, seq=sequence,
        epoch=np.currLevelAreaSeqId, ox=origin.x, oy=origin.y, oz=origin.z,
        dx=dx/length, dy=dy/length, dz=dz/length}
    FpsWeapon.flash(m,{x=p.dx,y=p.dy,z=p.dz})
    play_sound(SOUND_OBJ_POUNDING_CANNON, m.marioObj.header.gfx.cameraToObject)
    if network_is_server() then resolve_shot(p) else network_send_to(host.localIndex, true, p) end
end

local function before_mario(m)
    if m.playerIndex ~= 0 or not input_ready() then return end
    local shooting = (m.controller.buttonDown & (R_TRIG | B_BUTTON)) ~= 0
        or (djui_hud_get_mouse_buttons_down() & 1) ~= 0
    if shooting then fire() end
    m.controller.buttonPressed = m.controller.buttonPressed & ~(R_TRIG | B_BUTTON)
    m.controller.buttonDown = m.controller.buttonDown & ~(R_TRIG | B_BUTTON)
end

local function packet(p)
    if type(p) ~= 'table' or p.protocol ~= PROTOCOL then return end
    if p.kind == 'shot' then resolve_shot(p)
    elseif p.kind == 'result' and not network_is_server() then receive_result(p) end
end

local function hud()
    if not enabled or not ThirdPersonCamera.enabled or not active(0) then return end
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
        and 'MOUSE 1 / B / R: FIRE   L: SHOULDER' or 'JOIN THE HOST IN THE SAME AREA TO FIGHT'
    djui_hud_set_color(12,20,34,175)
    djui_hud_render_rect(5,h-23,225,14)
    djui_hud_set_color(255,255,255,240)
    djui_hud_print_text(label, 8, h-20, 0.35)
    if FpsBots then
        djui_hud_set_color(12,20,34,175)
        djui_hud_render_rect(5,29,190,14)
        djui_hud_set_color(255,255,255,240)
        djui_hud_print_text('KOOPA BOTS: '..(gGlobalSyncTable.fpsBotCount or 0)
            ..'   ELIMINATIONS: '..(gGlobalSyncTable.fpsBotKills or 0),8,32,0.35)
    end
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
local wasDead={}
hook_event(HOOK_MARIO_UPDATE,function(m)
    if not FpsRagdoll then return end
    local dead=m.health<=0xFF
    if dead and not wasDead[m.playerIndex] and is_player_active(m)~=0 then
        local v=m.vel
        local length=math.max(1,math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z))
        FpsRagdoll.spawn(m.pos,m.faceAngle.y*math.pi/32768,{x=v.x/length,y=0.3,z=v.z/length},false)
    end
    wasDead[m.playerIndex]=dead
end)
hook_chat_command('tps', 'Toggle shoulder camera (both views are third person).', function()
    enabled = not enabled
    if enabled then configure_camera() else restore_camera() end
    djui_chat_message_create('Shoulder camera: '..(enabled and 'ON' or 'OFF'))
    return true
end)
