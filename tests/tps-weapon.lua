-- Weapon attachment and animation continuity against a minimal engine adapter.
for line in io.lines('include/mario_animation_ids.h') do
    local hex,name=line:match('0x(%x+)%s*%*/%s*(MARIO_ANIM_[%w_]+)')
    if name then _G[name]=tonumber(hex,16) end
end
local hooks={}
HOOK_BEFORE_MARIO_UPDATE,HOOK_MARIO_UPDATE,HOOK_UPDATE,HOOK_ON_OBJECT_RENDER,HOOK_ON_CLEAR_AREAS='before','mario','update','render','clear'
OBJ_LIST_GENACTOR,OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE,ACT_IDLE,MARIO_HAND_FISTS=1,1,0,0
MARIO_ANIM_PART_RIGHT_FOREARM=11
function hook_behavior() return 1 end
function hook_event(kind,fn) hooks[kind]=fn end
function get_character_anim(m,id) return id+(m.character.type==2 and 300 or 0) end
function set_mario_animation(m,id)
    local a=m.marioObj.header.gfx.animInfo
    if a.animID~=id then a.animID=id; a.animFrame=0; a.animFrameAccelAssist=0 end
    a.animAccel=65536
end
function get_hand_foot_pos_x() return 10 end
function get_hand_foot_pos_y() return 100 end
function get_hand_foot_pos_z() return 0 end
ThirdPersonCamera={enabled=true,yaw=0,pitch=0}
gPlayerSyncTable={[0]={}}
FpsArena={active=function() return true end}
dofile('mods/third-person-arena/aa-combat.lua')
dofile('mods/third-person-arena/ad-weapon.lua')
local a={animID=MARIO_ANIM_WALKING,animFrame=12,animFrameAccelAssist=(12<<16)+100,animAccel=123456,curAnim={loopEnd=30}}
local m={playerIndex=0,action=1,character={type=0},pos={x=0,y=0,z=0},faceAngle={y=123},
    marioObj={header={gfx={animInfo=a,angle={y=0}}}},
    marioBodyState={torsoAngle={},animPartsPos={[12]={x=0,y=100,z=0}}}}
FpsWeapon.pose(m)
assert(a.animID==MARIO_ANIM_WALK_WITH_LIGHT_OBJ and a.animFrame==12 and a.animAccel==123456,'holding pose lost walk phase')
a.animFrame=15; a.animFrameAccelAssist=(15<<16)+99
hooks.before(m)
assert(a.animID==MARIO_ANIM_WALKING and a.animFrame==15 and a.animFrameAccelAssist==(15<<16)+99,'native walking did not resume at rendered phase')
set_mario_animation(m,MARIO_ANIM_WALKING)
assert(a.animFrame==15,'native update restarted walking')
assert(m.faceAngle.y==123,'visual aiming changed movement heading')
for _,d in ipairs({{x=0,y=0,z=1},{x=0.8,y=0.6,z=0},{x=0,y=-0.6,z=-0.8}}) do
    local mount,up=FpsWeapon.mount(m,d)
    local grip={x=mount.x-up.x*11*0.6+d.x*0.6,y=mount.y-up.y*11*0.6+d.y*0.6,z=mount.z-up.z*11*0.6+d.z*0.6}
    assert(FpsCombat.distance(grip,{x=18,y=100,z=0})<0.001,'handle center is outside the fist')
end
m.character.type=2; a.animID=MARIO_ANIM_WALKING+300
FpsWeapon.pose(m)
assert(a.animID==MARIO_ANIM_WALK_WITH_LIGHT_OBJ+300,'alternate character holding animation was not selected')
print('Passed weapon checks: grip alignment at three angles, walk continuity, movement heading, character animation mapping')
