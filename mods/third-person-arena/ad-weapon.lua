-- A real, shared 3D pistol attached to each character's animated hand.
FpsWeapon={lastShot=-100,objects={},flashes={},native={}}
local W=FpsWeapon
local behavior=hook_behavior(nil,OBJ_LIST_GENACTOR,false,function(o)
    o.oFlags=OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.oDrawingDistance=12000
    o.hookRender=1
end,function() end)

-- The skeleton reports the wrist, not the center of the closed glove.
W.scale=0.60
function W.grip(m,d)
    local wrist={x=get_hand_foot_pos_x(m,0),y=get_hand_foot_pos_y(m,0),z=get_hand_foot_pos_z(m,0)}
    if FpsCombat.distance(wrist,m.pos)>250 then
        return {x=m.pos.x,y=m.pos.y+100,z=m.pos.z}
    end
    local elbow=m.marioBodyState.animPartsPos[MARIO_ANIM_PART_RIGHT_FOREARM+1]
    local dx,dy,dz=wrist.x-elbow.x,wrist.y-elbow.y,wrist.z-elbow.z
    local length=math.max(0.001,math.sqrt(dx*dx+dy*dy+dz*dz))
    return {x=wrist.x+dx/length*8,y=wrist.y+dy/length*8,z=wrist.z+dz/length*8}
end
function W.mount(m,d)
    local grip=W.grip(m,d)
    local horizontal=math.sqrt(d.x*d.x+d.z*d.z)
    local up={x=0,y=1,z=0}
    if horizontal>0.001 then up={x=-d.x*d.y/horizontal,y=horizontal,z=-d.z*d.y/horizontal} end
    -- Grip center in model space is (0,-11,1). Put that inside the glove.
    return {x=grip.x+up.x*11*W.scale-d.x*W.scale,
        y=grip.y+up.y*11*W.scale-d.y*W.scale,
        z=grip.z+up.z*11*W.scale-d.z*W.scale},up
end
function W.muzzle(m,d)
    local pos,up=W.mount(m,d)
    return {x=pos.x+(d.x*54+up.x*16)*W.scale,
        y=pos.y+(d.y*54+up.y*16)*W.scale,
        z=pos.z+(d.z*54+up.z*16)*W.scale}
end

function W.flash_at(pos)
    local o=FpsRagdoll.object(E_MODEL_EXPLOSION,pos,0.25)
    if o then W.flashes[#W.flashes+1]={o=o,expires=get_global_timer()+3} end
end

function W.flash(m,d) W.flash_at(W.muzzle(m,d)) end
function W.tracer(p)
    if not FpsCombat.finite(p.distance) then return end
    local length=math.max(0,math.min(p.distance,1800))
    -- Short-lived beads make the hitscan direction visible without colliders.
    for step=1,math.min(18,math.floor(length/60)) do
        local t=step*60
        local o=FpsRagdoll.object(E_MODEL_YELLOW_SPHERE,
            {x=p.ox+p.dx*t,y=p.oy+p.dy*t,z=p.oz+p.dz*t},0.035)
        if o then W.flashes[#W.flashes+1]={o=o,expires=get_global_timer()+3} end
    end
end

local function update()
    if not FpsArena then return end
    for i=#W.flashes,1,-1 do
        local flash=W.flashes[i]
        if get_global_timer()>=flash.expires then obj_mark_for_deletion(flash.o); table.remove(W.flashes,i) end
    end
    for i=0,MAX_PLAYERS-1 do
        local active=FpsArena.active(i)
        if active and not W.objects[i] then
            local m=gMarioStates[i]
            W.objects[i]=spawn_non_sync_object(behavior,E_MODEL_TPS_PISTOL,m.pos.x,m.pos.y,m.pos.z,
                function(o) o.oBehParams=i; obj_scale(o,W.scale) end)
        elseif not active and W.objects[i] then
            obj_mark_for_deletion(W.objects[i]); W.objects[i]=nil
        end
    end
    if ThirdPersonCamera and ThirdPersonCamera.enabled and get_global_timer()%3==0 then
        gPlayerSyncTable[0].tpsYaw=ThirdPersonCamera.yaw
        gPlayerSyncTable[0].tpsPitch=ThirdPersonCamera.pitch
    end
end

-- Select only ordinary locomotion animations. Actions and movement physics stay
-- native; acrobatics, damage, swimming and cutscenes retain their own animation.
local poses={
    [MARIO_ANIM_IDLE_HEAD_LEFT]=MARIO_ANIM_IDLE_WITH_LIGHT_OBJ,
    [MARIO_ANIM_IDLE_HEAD_RIGHT]=MARIO_ANIM_IDLE_WITH_LIGHT_OBJ,
    [MARIO_ANIM_IDLE_HEAD_CENTER]=MARIO_ANIM_IDLE_WITH_LIGHT_OBJ,
    [MARIO_ANIM_WALKING]=MARIO_ANIM_WALK_WITH_LIGHT_OBJ,
    [MARIO_ANIM_RUNNING]=MARIO_ANIM_RUN_WITH_LIGHT_OBJ,
    [MARIO_ANIM_SINGLE_JUMP]=MARIO_ANIM_JUMP_WITH_LIGHT_OBJ,
    [MARIO_ANIM_GENERAL_FALL]=MARIO_ANIM_FALL_WITH_LIGHT_OBJ,
    [MARIO_ANIM_LAND_FROM_SINGLE_JUMP]=MARIO_ANIM_JUMP_LAND_WITH_LIGHT_OBJ,
}
local characterPoses={}
function W.pose(m)
    if not FpsArena or not FpsArena.active(m.playerIndex) then return end
    if m.playerIndex==0 and not ThirdPersonCamera.enabled then return end
    local info=m.marioObj.header.gfx.animInfo
    local kind=m.character and m.character.type or 0
    if not characterPoses[kind] then
        local map={}
        for native,holding in pairs(poses) do map[get_character_anim(m,native)]=get_character_anim(m,holding) end
        characterPoses[kind]=map
    end
    local pose=characterPoses[kind][info.animID]
    if not pose then return end
    -- Carry over the native frame so walking does not reset to frame zero.
    local frame,assist,accel=info.animFrame,info.animFrameAccelAssist,info.animAccel
    W.native[m.playerIndex]={id=info.animID,pose=pose}
    set_mario_animation(m,pose)
    local length=info.curAnim.loopEnd
    if length>0 then
        info.animFrame=frame%length
        info.animFrameAccelAssist=(info.animFrame << 16) | (assist & 0xFFFF)
        info.animAccel=accel
    end
    m.marioBodyState.handState=MARIO_HAND_FISTS
    local sync=gPlayerSyncTable[m.playerIndex]
    local yaw=m.playerIndex==0 and ThirdPersonCamera.yaw or sync.tpsYaw
    local pitch=m.playerIndex==0 and ThirdPersonCamera.pitch or (sync.tpsPitch or 0)
    if yaw then
        local angle=math.floor(yaw*32768/math.pi)%65536
        if angle>=32768 then angle=angle-65536 end
        -- Face the aim visually while native faceAngle continues driving SM64
        -- movement. This allows strafing without pointing the arms sideways.
        m.marioObj.header.gfx.angle.y=angle
        if m.action==ACT_IDLE then m.faceAngle.y=angle end
        m.marioBodyState.allowPartRotation=1
        m.marioBodyState.torsoAngle.x=math.floor(-pitch*32768/math.pi*0.65)
        m.marioBodyState.torsoAngle.y=0
        m.marioBodyState.torsoAngle.z=0
    end
end

local function render(o)
    if obj_has_behavior_id(o,behavior)==0 then return end
    local i=o.oBehParams
    local m=gMarioStates[i]
    if not m or not FpsArena.active(i) then return end
    local sync=gPlayerSyncTable[i]
    local yaw=sync.tpsYaw or m.faceAngle.y*math.pi/32768
    local pitch=sync.tpsPitch or 0
    if i==0 and ThirdPersonCamera.enabled then yaw,pitch=ThirdPersonCamera.yaw,ThirdPersonCamera.pitch end
    local recoil=i==0 and math.max(0,1-(get_global_timer()-W.lastShot)/8) or 0
    local cp=math.cos(pitch)
    local pos=W.mount(m,{x=math.sin(yaw)*cp,y=math.sin(pitch),z=math.cos(yaw)*cp})
    o.oPosX,o.oPosY,o.oPosZ=pos.x,pos.y,pos.z
    o.oFaceAngleYaw=math.floor(yaw*32768/math.pi)%65536
    o.oFaceAnglePitch=math.floor(-pitch*32768/math.pi-recoil*2500)%65536
    o.oFaceAngleRoll=0
    o.header.gfx.pos.x,o.header.gfx.pos.y,o.header.gfx.pos.z=pos.x,pos.y,pos.z
    o.header.gfx.angle.x,o.header.gfx.angle.y,o.header.gfx.angle.z=o.oFaceAnglePitch,o.oFaceAngleYaw,0
end

-- Restore the underlying animation before action code runs; otherwise native
-- walking would restart each tick after seeing the holding animation's ID.
hook_event(HOOK_BEFORE_MARIO_UPDATE,function(m)
    if FpsArena and FpsArena.active(m.playerIndex) and (m.playerIndex~=0 or ThirdPersonCamera.enabled) then
        if m.action==ACT_IDLE then m.actionState,m.actionTimer=0,0 end
        if m.action==ACT_START_SLEEPING or m.action==ACT_SLEEPING or m.action==ACT_WAKING_UP then
            set_mario_action(m,ACT_IDLE,0)
        end
    end
    local saved=W.native[m.playerIndex]
    if not saved then return end
    m.marioBodyState.allowPartRotation=0
    m.marioBodyState.torsoAngle.x,m.marioBodyState.torsoAngle.y,m.marioBodyState.torsoAngle.z=0,0,0
    local info=m.marioObj.header.gfx.animInfo
    if info.animID==saved.pose then
        local frame,assist,accel=info.animFrame,info.animFrameAccelAssist,info.animAccel
        set_mario_animation(m,saved.id)
        info.animFrame,info.animFrameAccelAssist,info.animAccel=frame,assist,accel
    end
    W.native[m.playerIndex]=nil
end)
hook_event(HOOK_MARIO_UPDATE,W.pose)
hook_event(HOOK_UPDATE,update)
hook_event(HOOK_ON_OBJECT_RENDER,render)
hook_event(HOOK_ON_CLEAR_AREAS,function() W.objects={}; W.flashes={} end)
