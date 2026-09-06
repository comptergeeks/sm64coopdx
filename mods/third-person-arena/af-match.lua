-- Local respawn state; the host publishes scores for the whole match.
FpsMatch={dead=false,respawnAt=0,spawns={},seen={},lastHit={},deaths={}}
local M=FpsMatch
local function now() return get_global_timer() end
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function score(kind,id) return 'tps'..kind..id end
function M.record_hit(victim,killer,epoch,direction)
    M.lastHit[victim]={killer=killer,epoch=epoch,time=now(),direction=direction}
end
function M.record_death(p)
    if not network_is_server() or not FpsCombat.finite(p.victim) or not FpsCombat.finite(p.serial)
        or p.serial<1 or p.serial%1~=0 then return end
    local np=network_player_from_global_index(p.victim)
    if not np or not np.connected or np.currLevelAreaSeqId~=p.epoch then return end
    if p.serial<=(M.deaths[p.victim] or 0) then return end
    M.deaths[p.victim]=p.serial
    local key=score('Deaths',p.victim)
    gGlobalSyncTable[key]=(gGlobalSyncTable[key] or 0)+1
    local hit=M.lastHit[p.victim]
    if hit and hit.epoch==p.epoch and now()-hit.time<150 and hit.killer~=p.victim then
        key=score('Kills',hit.killer)
        gGlobalSyncTable[key]=(gGlobalSyncTable[key] or 0)+1
    end
    M.lastHit[p.victim]=nil
end
function M.bot_kill(killer,victim)
    if not network_is_server() then return end
    local key=score('Kills',killer)
    gGlobalSyncTable[key]=(gGlobalSyncTable[key] or 0)+1
    if victim then
        local deaths=score('Deaths',victim)
        gGlobalSyncTable[deaths]=(gGlobalSyncTable[deaths] or 0)+1
    end
end
function M.begin(m)
    if M.dead or not ThirdPersonCamera.enabled then return end
    M.dead=true; M.respawnAt=now()+90
    local np,s=gNetworkPlayers[0],gPlayerSyncTable[0]
    s.tpsDeathSerial=(s.tpsDeathSerial or 0)+1
    s.tpsDeathX,s.tpsDeathY,s.tpsDeathZ=m.pos.x,m.pos.y,m.pos.z
    s.tpsDeathYaw=m.faceAngle.y
    s.tpsDeathEpoch=np.currLevelAreaSeqId
    local hit=M.lastHit[np.globalIndex]
    local d=hit and hit.direction or ThirdPersonCamera.direction
    s.tpsDeathDX,s.tpsDeathDY,s.tpsDeathDZ=d.x,d.y,d.z
    s.tpsDead=true
    local p={protocol='tps-arena-v1',kind='death',victim=np.globalIndex,
        serial=s.tpsDeathSerial,epoch=np.currLevelAreaSeqId}
    if network_is_server() then M.record_death(p) else network_send(true,p) end
    set_mario_action(m,ACT_DISAPPEARED,0)
end
local function respawn(m)
    local origin
    local fallback=copy(m.pos)
    -- Prefer recorded safe ground furthest from other active combatants.
    local best=-1
    for _,p in ipairs(M.spawns) do
        local distance=10000
        for i=1,MAX_PLAYERS-1 do
            if FpsArena.active(i) then distance=math.min(distance,FpsCombat.distance(p,gMarioStates[i].pos)) end
        end
        if FpsBots then for _,b in ipairs(FpsBots.targets()) do distance=math.min(distance,FpsCombat.distance(p,b.pos)) end end
        local safe=not collision_find_floor or FpsCombat.safe_surface(collision_find_floor(p.x,p.y+100,p.z))
        if safe and distance>best then origin,best=p,distance end
    end
    local destination=origin or fallback
    m.pos.x,m.pos.y,m.pos.z=destination.x,destination.y+40,destination.z
    m.vel.x,m.vel.y,m.vel.z,m.forwardVel=0,0,0,0
    m.health,m.hurtCounter,m.healCounter=0x880,0,0
    m.invincTimer=90
    m.numLives=math.max(m.numLives,4)
    m.marioObj.header.gfx.node.flags=m.marioObj.header.gfx.node.flags | GRAPH_RENDER_ACTIVE
    set_mario_action(m,ACT_FREEFALL,0)
    M.dead=false; gPlayerSyncTable[0].tpsDead=false
    m.marioBodyState.tpsRagdoll=false
    if not origin then
        local np=gNetworkPlayers[0]
        warp_to_level(np.currLevelNum,np.currAreaIndex,np.currActNum)
    end
end
function M.before(m)
    if m.playerIndex~=0 or (not ThirdPersonCamera.enabled and not M.dead) then return end
    if m.health<=0xFF then M.begin(m) end
    if M.dead then
        if now()>=M.respawnAt then respawn(m); return end
        m.health=0x880; m.hurtCounter=0; m.healCounter=0
        m.controller.buttonDown,m.controller.buttonPressed=0,0
        m.controller.stickX,m.controller.stickY,m.controller.stickMag=0,0,0
        set_mario_action(m,ACT_DISAPPEARED,0)
    elseif m.floor and m.floor.normal.y>0.7 and math.abs(m.pos.y-m.floorHeight)<5
        and (m.action & ACT_FLAG_INTANGIBLE)==0 and (m.action & ACT_FLAG_SWIMMING)==0
        and (#M.spawns==0 or now()%90==0) then
        if FpsCombat.safe_surface(m.floor) then
            M.spawns[#M.spawns+1]=copy(m.pos)
            if #M.spawns>16 then table.remove(M.spawns,2) end
        end
    end
end
function M.update()
    if gGlobalSyncTable.tpsMatchSerial and M.matchSerial~=gGlobalSyncTable.tpsMatchSerial then
        M.matchSerial=gGlobalSyncTable.tpsMatchSerial
        if gNetworkPlayers[0].currAreaSyncValid then respawn(gMarioStates[0]) end
    end
    for i=0,MAX_PLAYERS-1 do
        local s,np=gPlayerSyncTable[i],gNetworkPlayers[i]
        if np.connected and s.tpsDead and s.tpsDeathSerial~=M.seen[i]
            and s.tpsDeathEpoch==np.currLevelAreaSeqId
            and FpsCombat.same_area(np,gNetworkPlayers[0]) then
            M.seen[i]=s.tpsDeathSerial
            if s.tpsDeathX and s.tpsDeathY and s.tpsDeathZ then
                FpsRagdoll.spawn({x=s.tpsDeathX,y=s.tpsDeathY,z=s.tpsDeathZ},
                    (s.tpsDeathYaw or 0)*math.pi/32768,
                    {x=s.tpsDeathDX or 0,y=s.tpsDeathDY or 0.3,z=s.tpsDeathDZ or 1},false,gMarioStates[i])
            end
        end
    end
end
local function reset_area()
    M.dead=false; M.spawns={}; M.seen={}; M.lastHit={}
    for i=0,MAX_PLAYERS-1 do gMarioStates[i].marioBodyState.tpsRagdoll=false end
    gPlayerSyncTable[0].tpsDead=false
end
hook_event(HOOK_BEFORE_MARIO_UPDATE,M.before)
hook_event(HOOK_UPDATE,M.update)
hook_event(HOOK_ON_WARP,reset_area)
hook_event(HOOK_ON_DEATH,function(m) if ThirdPersonCamera.enabled then M.begin(m); return false end end)
hook_event(HOOK_ON_PLAYER_DISCONNECTED,function(m)
    local id=gNetworkPlayers[m.playerIndex].globalIndex
    M.deaths[id]=nil; M.lastHit[id]=nil; M.seen[m.playerIndex]=nil
end)
hook_chat_command('match','Reset scores and start a fresh match (host).',function()
    if not network_is_server() then djui_chat_message_create('Only the host can reset the match.'); return true end
    for i=0,MAX_PLAYERS+3 do gGlobalSyncTable[score('Kills',i)]=0; gGlobalSyncTable[score('Deaths',i)]=0 end
    gGlobalSyncTable.tpsMatchSerial=(gGlobalSyncTable.tpsMatchSerial or 0)+1
    FpsBots.kills=0; gGlobalSyncTable.fpsBotKills=0
    FpsBots.reset()
    djui_chat_message_create('New match. Scores reset.'); return true
end)

-- ACT_DISAPPEARED suppresses native death/warp logic. Render the physics pose
-- during the countdown, including for remote players.
hook_event(HOOK_MARIO_UPDATE,function(m)
    if gPlayerSyncTable[m.playerIndex].tpsDead and m.marioBodyState.tpsRagdoll then
        m.marioObj.header.gfx.node.flags=m.marioObj.header.gfx.node.flags | GRAPH_RENDER_ACTIVE
    end
end)

hook_event(HOOK_ON_EXIT,function() gPlayerSyncTable[0].tpsDead=false; FpsRagdoll.clear() end)
