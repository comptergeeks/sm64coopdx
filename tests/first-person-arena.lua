-- Run from the repository root with Lua 5.3+.
dofile('mods/first-person-arena/aa-combat.lua')
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
    return {protocol='fps-arena-v1',kind='shot',shooter=1,seq=seq or 1,epoch=7,
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
    'HOOK_ON_PLAYER_DISCONNECTED','HOOK_ON_EXIT'}) do _G[name]=name end
function hook_event(name, fn) hooks[name]=fn end
function hook_chat_command(name, _, fn) commands[name]=fn end
MAX_PLAYERS, NPT_SERVER, ACT_FLAG_INTANGIBLE, ACT_FLAG_SWIMMING = 3,2,0x100,0x200
ACT_BACKWARD_AIR_KB, R_TRIG = 10,16
SOUND_OBJ_POUNDING_CANNON, SOUND_OBJ_BULLY_METAL = 1,2
gNetworkPlayers, gMarioStates = {}, {}
for i=0,2 do
    gNetworkPlayers[i]={connected=true,localIndex=i,globalIndex=i,type=i==0 and 2 or 3,
        currCourseNum=1,currActNum=1,currLevelNum=9,currAreaIndex=1,currLevelAreaSeqId=7,
        currAreaSyncValid=true,currLevelSyncValid=true}
    gMarioStates[i]={playerIndex=i,pos={x=0,y=0,z=i==0 and 500 or 0},health=0x880,
        action=0,invincTimer=0,faceAngle={y=0},vel={y=0},controller={buttonDown=0,buttonPressed=0},
        marioObj={header={gfx={cameraToObject={}}}}}
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
dofile('mods/first-person-arena/main.lua')
hooks.HOOK_ON_SYNC_VALID()
check(gFirstPersonCamera.enabled and gFirstPersonCamera.forceRoll, 'first-person camera enabled upright')
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
commands.fps()
check(not gFirstPersonCamera.enabled and gFirstPersonCamera.fov==70,
    'toggle restores original camera configuration')
-- A valid-looking result for the previous area must not follow the victim through a warp.
client=true; gNetworkPlayers[1].type=NPT_SERVER
p=shot(8); p.kind='result'; p.victim=0; p.victimEpoch=6
hooks.HOOK_ON_PACKET_RECEIVE(p)
check(gMarioStates[0].health==0x680, 'late hit after warp cannot damage victim')
print('Passed '..count..' checks')
