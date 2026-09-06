-- Run from the repository root with Lua 5.3+.
dofile('mods/third-person-arena/aa-combat.lua')
local C, count = FpsCombat, 0
local function check(value, name)
    assert(value, name)
    count = count+1
    print('ok '..count..' - '..name)
end
local origin, direction = {x=0,y=120,z=0}, {x=0,y=0,z=1}
local players = {{id=1,pos={x=0,y=0,z=500},height=160},
                 {id=2,pos={x=0,y=0,z=900},height=160}}
check(C.pick_target(origin,direction,players) == 1, 'nearest player stops shot')
check(C.pick_target(origin,direction,players,400) == nil, 'wall blocks player')
local _, entry = C.pick_target(origin,direction,players)
check(C.pick_target(origin,direction,players,entry) == nil, 'wall wins exact tie')
check(C.pick_target(origin,{x=0,y=0,z=-1},players) == nil, 'targets behind camera miss')
check(C.pick_target(origin,direction,{{id=1,pos=players[1].pos,height=100}}) == nil,
    'crouching player can duck shot')
check(C.ray_capsule({x=0,y=300,z=500},{x=0,y=-1,z=0},players[1].pos,160) == 140,
    'vertical ray hits rounded head')
check(C.ray_capsule({x=0,y=80,z=500},direction,players[1].pos,160) == 0,
    'shot beginning inside capsule hits immediately')
check(C.pick_target(origin,direction,{{id=1,pos={x=0,y=0,z=7000},height=160}}) == nil,
    'range is bounded')
local function shot(seq)
    return {protocol='tps-arena-v1',kind='shot',shooter=1,seq=seq or 1,epoch=7,referee=0,
        ox=0,oy=120,oz=0,dx=0,dy=0,dz=1}
end
local history = {}
check(C.admit(history,shot(),0), 'first shot admitted')
check(not C.admit(history,shot(),30), 'replayed sequence rejected')
check(not C.admit(history,shot(2),11), 'fire rate limited')
check(C.admit(history,shot(2),12), 'shot allowed at cooldown boundary')
for _, value in ipairs({0/0, math.huge, 'invalid'}) do
    local p=shot(); p.dx=value
    check(not C.valid_shot(p), 'malformed direction rejected: '..tostring(value))
end
local p=shot(); p.dz=2
check(not C.valid_shot(p), 'non-unit direction rejected')

-- Engine adapter smoke tests. Run callbacks with controlled network snapshots.
local hooks, commands, sent = {}, {}, {}
for _, name in ipairs({'HOOK_ON_SYNC_VALID','HOOK_ON_WARP','HOOK_BEFORE_MARIO_UPDATE',
    'HOOK_ON_PACKET_RECEIVE','HOOK_ON_HUD_RENDER','HOOK_ON_PLAYER_CONNECTED',
    'HOOK_ON_PLAYER_DISCONNECTED','HOOK_ON_EXIT','HOOK_MARIO_UPDATE'}) do _G[name]=name end
function hook_event(name, fn) hooks[name]=fn end
function hook_chat_command(name, _, fn) commands[name]=fn end
MAX_PLAYERS, NPT_SERVER, ACT_FLAG_INTANGIBLE, ACT_FLAG_SWIMMING = 3,2,0x100,0x200
ACT_BACKWARD_AIR_KB, R_TRIG, B_BUTTON = 10,16,0x4000
SOUND_OBJ_POUNDING_CANNON, SOUND_OBJ_BULLY_METAL = 1,2
gNetworkPlayers, gMarioStates = {}, {}
for i=0,2 do
    gNetworkPlayers[i]={connected=true,localIndex=i,globalIndex=i,type=i==0 and 2 or 3,
        currCourseNum=1,currActNum=1,currLevelNum=9,currAreaIndex=1,currLevelAreaSeqId=7,
        currAreaSyncValid=true,currLevelSyncValid=true}
    gMarioStates[i]={playerIndex=i,pos={x=0,y=0,z=i==0 and 500 or 0},health=0x880,
        action=0,invincTimer=0,faceAngle={y=0},vel={y=0},controller={buttonDown=0,buttonPressed=0},
        marioBodyState={},marioObj={header={gfx={cameraToObject={}}}}}
end
gMarioStates[2].pos.x=1000
gFirstPersonCamera={enabled=false,forceRoll=false,centerL=true,fov=70,pitch=0,yaw=0,crouch=0}
local now, wall, paused, client, crouching = 100,nil,false,false,false
function get_global_timer() return now end
function network_is_server() return not client end
function network_player_from_global_index(i) return gNetworkPlayers[i] end
function is_player_active() return 1 end
function mario_is_crouching() return crouching end
function is_game_paused() return paused end
function djui_is_chatbox_open() return false end
function djui_hud_is_pause_menu_created() return false end
function djui_hud_is_mouse_locked() return true end
function djui_hud_get_mouse_buttons_down() return 0 end
function set_first_person_enabled(value) gFirstPersonCamera.enabled=value end
function get_first_person_enabled() return gFirstPersonCamera.enabled end
function camera_config_enable_mouse_look() end
function camera_reset_overrides() end
function collision_find_surface_on_ray() return {surface=wall,hitPos={x=0,y=120,z=200}} end
function network_send(_, packet) sent[#sent+1]=packet end
function network_send_to(_, _, packet) sent[#sent+1]=packet end
function set_mario_action(m, action) m.action=action end
function play_sound() end
function atan2s() return 0 end
function sins(angle) return math.sin(angle*math.pi/32768) end
function coss(angle) return math.cos(angle*math.pi/32768) end
function djui_chat_message_create() end
gLakituState={shakeMagnitude={}}
for _,name in ipairs({'pos','curPos','goalPos','focus','curFocus','goalFocus'}) do gLakituState[name]={x=0,y=0,z=0} end
for i=0,2 do gMarioStates[i].area={camera={pos={},focus={}}} end
local frozen=false
function camera_freeze() frozen=true end
function camera_unfreeze() frozen=false end
function djui_hud_set_mouse_locked() end
function set_override_fov() end
function first_person_check_cancels() return false end
function djui_hud_get_raw_mouse_x() return 0 end
function djui_hud_get_raw_mouse_y() return 0 end
CAMERA_MODE_FREE_ROAM,L_TRIG=1,32
dofile('mods/third-person-arena/ae-camera.lua')
dofile('mods/third-person-arena/main.lua')
hooks.HOOK_ON_SYNC_VALID()
check(ThirdPersonCamera.enabled and frozen and not gFirstPersonCamera.enabled, 'third-person enabled and first-person disabled')
ThirdPersonCamera.update(gMarioStates[0])
check(C.distance(ThirdPersonCamera.pos,gMarioStates[0].pos)>300, 'camera stays behind and away from character')
check(gLakituState.roll==0, 'third-person camera stays upright')
hooks.HOOK_ON_PACKET_RECEIVE(shot())
check(gMarioStates[0].health==0x680, 'host resolves client shot and applies two wedges locally')
check(sent[#sent].victim==0 and gMarioStates[0].vel.y==25, 'confirmed hit broadcasts and applies knockback')
hooks.HOOK_ON_PACKET_RECEIVE(shot())
check(#sent==1, 'replay does not broadcast or damage twice')
now=130; wall={}; gMarioStates[0].invincTimer=0
hooks.HOOK_ON_PACKET_RECEIVE(shot(2))
check(sent[#sent].victim==-1 and gMarioStates[0].health==0x680, 'adapter consults world wall collision')
wall=nil; now=160; crouching=true
hooks.HOOK_ON_PACKET_RECEIVE(shot(3))
check(sent[#sent].victim==-1, 'engine boolean crouch uses short capsule')
crouching=false; now=190
gNetworkPlayers[1].currAreaIndex=2
hooks.HOOK_ON_PACKET_RECEIVE(shot(4))
check(#sent==3, 'different area cannot damage host')
gNetworkPlayers[1].currAreaIndex=1
p=shot(4); p.epoch=6
hooks.HOOK_ON_PACKET_RECEIVE(p)
check(#sent==3, 'shot from previous warp is discarded')
p=shot(4); p.ox=10000
hooks.HOOK_ON_PACKET_RECEIVE(p)
check(#sent==3, 'faraway forged origin rejected')
gMarioStates[0].controller.buttonDown=R_TRIG
paused=true
hooks.HOOK_BEFORE_MARIO_UPDATE(gMarioStates[0])
check(#sent==3, 'pause suppresses firing')
paused=false
commands.tps()
check(not ThirdPersonCamera.enabled and not frozen and not gFirstPersonCamera.enabled,
    'toggle returns to native third person, never first person')
-- A valid-looking result for the previous area must not follow the victim through a warp.
client=true; gNetworkPlayers[1].type=NPT_SERVER
p=shot(8); p.kind='result'; p.victim=0; p.victimEpoch=6
hooks.HOOK_ON_PACKET_RECEIVE(p)
check(gMarioStates[0].health==0x680, 'late hit after warp cannot damage victim')

-- The solver must remain bounded and connected after a strong impact.
dofile('mods/third-person-arena/ab-ragdoll.lua')
local body=FpsRagdoll.skeleton({x=0,y=0,z=0},0.7,{x=18,y=12,z=9})
for i=1,240 do
    FpsRagdoll.step(body,function(node)
        if node.y<12 then
            node.y=12; node.py=12
            node.px=node.x-(node.x-node.px)*0.7
            node.pz=node.z-(node.z-node.pz)*0.7
        end
    end)
end
local stable=true
for _,node in ipairs(body.nodes) do
    stable=stable and C.finite(node.x) and C.finite(node.y) and node.y>=12
end
check(stable,'ragdoll remains finite and above the floor after impact')
local error=0
for _,link in ipairs(body.links) do
    error=math.max(error,math.abs(C.distance(body.nodes[link[1]],body.nodes[link[2]])-link[3]))
end
check(error<3,'ragdoll joints stay connected after settling')

-- Bot/visual adapter: instantiate the whole module, respecting load-only hooks.
local loading=true
local objectCount=0
function hook_behavior(_,_,_,init,loop)
    assert(loading,'behavior registered after load')
    return {init=init,loop=loop}
end
function spawn_non_sync_object(behavior,model,x,y,z,setup)
    objectCount=objectCount+1
    local o={oPosX=x,oPosY=y,oPosZ=z,model=model,header={gfx={}}}
    if behavior.init then behavior.init(o) end
    setup(o)
    return o
end
function obj_mark_for_deletion(o) o.deleted=true end
function obj_scale() end
function obj_scale_xyz() end
function cur_obj_init_animation() end
function find_floor_height() return 0 end
gObjectAnimations={koopa_seg6_anims_06011364={}}
gGlobalSyncTable={}
HOOK_UPDATE,HOOK_ON_CLEAR_AREAS='HOOK_UPDATE','HOOK_ON_CLEAR_AREAS'
OBJ_LIST_GENACTOR,OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE=1,1
E_MODEL_METALLIC_BALL,E_MODEL_KOOPA_SHELL,E_MODEL_YELLOW_SPHERE=1,2,3
E_MODEL_MARIOS_CAP,E_MODEL_KOOPA_WITH_SHELL,E_MODEL_TPS_PISTOL=4,5,6
dofile('mods/third-person-arena/ab-ragdoll.lua')
dofile('mods/third-person-arena/ac-bots.lua')
loading=false
client=false; paused=false; wall=nil; now=300
gMarioStates[0].health=0x880; gMarioStates[0].action=0; gMarioStates[0].invincTimer=0
gNetworkPlayers[1].connected=false; gNetworkPlayers[2].connected=false
FpsBots.reset(); now=400; FpsBots.update()
check(#FpsBots.targets()==2 and objectCount==4,'two bots spawn with body and gun visuals')
check(not gGlobalSyncTable.fpsBotAwake,'bots wait for the first player shot before attacking')
local bot=FpsBots.bots[1]
local oldX,oldZ=bot.x,bot.z
now=403; FpsBots.update()
check(C.distance(bot,{x=oldX,y=bot.y,z=oldZ})>0,'bot moves toward/around a target')
wall={}; oldX,oldZ=bot.x,bot.z; now=406; FpsBots.update()
check(bot.x==oldX and bot.z==oldZ,'bot does not walk through a wall')
wall=nil
local originalFloor=find_floor_height
function find_floor_height() return -11000 end
now=409; FpsBots.update()
check(bot.x==oldX and bot.z==oldZ,'bot rejects a missing floor/cliff')
find_floor_height=originalFloor
local id=FpsBots.id(1)
for i=1,3 do check(FpsBots.damage(id,{x=1,y=0,z=0}),'bot accepts hit '..i) end
check(bot.hp==0 and #FpsBots.targets()==1,'dead bot leaves hit-test targets')
check(not FpsBots.damage(id,{x=1,y=0,z=0}),'dead bot cannot award another kill')
FpsBots.update()
check(#FpsRagdoll.bodies==1 and not FpsBots.visuals[1],'bot death replaces live model with a ragdoll')
FpsBots.update()
check(#FpsRagdoll.bodies==1,'repeated death state does not duplicate the ragdoll')
now=600; FpsBots.update()
check(FpsBots.bots[1].hp==3 and FpsBots.bots[1].generation==2,'bot respawns with a new generation')
local priorHealth=gMarioStates[0].health
local pos=gMarioStates[0].pos
-- Aim directly at the local player, avoiding AI inaccuracy for this check.
FpsArena.bot_shot(FpsBots.bots[1],{x=pos.x,y=120,z=pos.z-300},{x=0,y=0,z=1})
check(gMarioStates[0].health==priorHealth-0x100,'bot shot damages player by one wedge')
commands.bots('0'); now=800; FpsBots.update()
check(#FpsBots.targets()==0 and next(FpsBots.visuals)==nil,'disabling bots clears AI and visuals')
FpsRagdoll.clear()
check(#FpsRagdoll.bodies==0,'ragdoll cleanup releases all body handles')
-- Attack bindings must be consumed before native action input is calculated.
commands.tps()
FpsWeapon={muzzle=function(m) return {x=m.pos.x,y=m.pos.y+110,z=m.pos.z} end,flash=function() end}
local controller=gMarioStates[0].controller
controller.buttonDown=B_BUTTON|R_TRIG|1
controller.buttonPressed=B_BUTTON|R_TRIG|1
hooks.HOOK_BEFORE_MARIO_UPDATE(gMarioStates[0])
check(controller.buttonDown==1 and controller.buttonPressed==1,
    'fire consumes B and R while preserving unrelated buttons')
controller.buttonDown=B_BUTTON
controller.buttonPressed=B_BUTTON
hooks.HOOK_BEFORE_MARIO_UPDATE(gMarioStates[0])
check(controller.buttonDown==0 and controller.buttonPressed==0,
    'cooldown also consumes B so repeated fire cannot punch')
-- Match lifecycle regression: a death is scored once and respawns in-area.
gPlayerSyncTable={ [0]={},[1]={},[2]={} }
HOOK_ON_DEATH,ACT_DISAPPEARED,ACT_FREEFALL,GRAPH_RENDER_ACTIVE='HOOK_ON_DEATH',100,101,1
dofile('mods/third-person-arena/af-match.lua')
local me=gMarioStates[0]
me.numLives=4; me.marioObj.header.gfx.node={flags=0}
FpsMatch.spawns={{x=10,y=20,z=30}}
me.vel={x=6,y=3,z=0}
FpsMatch.record_hit(0,1,gNetworkPlayers[0].currLevelAreaSeqId,{x=0,y=0,z=1},{x=10,y=100,z=20})
me.vel={x=-45,y=25,z=0} -- native knockback must not replace pre-hit momentum
FpsMatch.begin(me)
check(gPlayerSyncTable[0].tpsDeathVX==6 and gPlayerSyncTable[0].tpsDeathVY==3,
    'death synchronization preserves movement from before native knockback')
check(gPlayerSyncTable[0].tpsDeathHX==10 and gPlayerSyncTable[0].tpsDeathHY==100,
    'death synchronization carries the actual impact point')
check(FpsMatch.dead and gPlayerSyncTable[0].tpsDead and not FpsArena.active(0),
    'eliminated player leaves combat during countdown')
check(gGlobalSyncTable.tpsDeaths0==1 and gGlobalSyncTable.tpsKills1==1,
    'host awards one death and credits recent shooter')
FpsMatch.record_death({victim=0,serial=1,epoch=gNetworkPlayers[0].currLevelAreaSeqId})
check(gGlobalSyncTable.tpsDeaths0==1,'duplicate death cannot change score')
FpsMatch.record_death({victim=0,serial=2,epoch=-1})
check(gGlobalSyncTable.tpsDeaths0==1,'stale-area death cannot change score')
now=FpsMatch.respawnAt-1
FpsMatch.before(me)
check(FpsMatch.dead and me.action==ACT_DISAPPEARED,'countdown retains eliminated state')
now=now+1
FpsMatch.before(me)
check(not FpsMatch.dead and me.health==0x880 and me.invincTimer==90,
    'countdown restores full health with spawn protection')
check(me.pos.x==10 and me.pos.y==60 and me.pos.z==30 and me.action==ACT_FREEFALL,
    'respawn returns to safe ground without a stage warp')
check(C.safe_surface({type=0,normal={y=1}}),'flat ordinary ground is safe')
check(not C.safe_surface({type=0x23,normal={y=1}}),'instant quicksand cannot be a bot or respawn floor')
check(not C.safe_surface({type=0,normal={y=0.3}}),'steep slopes cannot be a bot or respawn floor')
local oldLevel=gNetworkPlayers[0].currLevelNum
gNetworkPlayers[0].currLevelNum=123
gNetworkPlayers[1].connected=true; gNetworkPlayers[2].connected=true
check(FpsArena.referee_for(gNetworkPlayers[1]).globalIndex==1,
    'remote area elects a referee even when lobby host is elsewhere')
gNetworkPlayers[1].connected=false
check(FpsArena.referee_for(gNetworkPlayers[2]).globalIndex==2,
    'next connected player takes over area after referee leaves')
gNetworkPlayers[1].connected=true; gNetworkPlayers[0].currLevelNum=oldLevel
SURFACE_BURNING=1
check(not C.safe_surface({type=1,normal={y=1}}),'lava cannot be a bot or respawn floor')
print('Passed '..count..' checks')
