ThirdPersonCamera={enabled=false,yaw=0,pitch=-0.06,shoulder=65,pos={x=0,y=0,z=0},direction={x=0,y=0,z=-1}}
local T=ThirdPersonCamera
local function copy(dest,source) dest.x,dest.y,dest.z=source.x,source.y,source.z end

function T.enable()
    if not T.enabled then
        T.yaw=gMarioStates[0].faceAngle.y*math.pi/32768
        T.pitch=-0.06
    end
    T.enabled=true
    set_first_person_enabled(false)
    camera_freeze()
    camera_config_enable_mouse_look(true)
    djui_hud_set_mouse_locked(true)
    set_override_fov(65)
end

function T.disable()
    T.enabled=false
    set_first_person_enabled(false)
    camera_unfreeze()
    camera_reset_overrides()
    djui_hud_set_mouse_locked(false)
    set_override_fov(0)
end

function T.input(m)
    if not T.enabled or m.playerIndex~=0 or is_game_paused()
        or djui_is_chatbox_open() or djui_hud_is_pause_menu_created() then return end
    local c=m.controller
    T.yaw=T.yaw-djui_hud_get_raw_mouse_x()*0.0028+(c.extStickX or 0)*0.0009
    T.pitch=math.max(-1.05,math.min(0.85,T.pitch-djui_hud_get_raw_mouse_y()*0.0028+(c.extStickY or 0)*0.0009))
    if (c.buttonPressed & L_TRIG)~=0 then T.shoulder=-T.shoulder end
    local yaw=math.floor(T.yaw*32768/math.pi+32768)%65536
    if yaw>=32768 then yaw=yaw-65536 end
    gLakituState.yaw=yaw
    gLakituState.mode=CAMERA_MODE_FREE_ROAM
    m.area.camera.yaw=yaw
    m.area.camera.mode=CAMERA_MODE_FREE_ROAM
end

function T.update(m)
    if not T.enabled or m.playerIndex~=0 or not m.area then return end
    -- Cutscenes/menus keep their native camera and never enter first person.
    local dead=FpsMatch and FpsMatch.dead
    if not dead and first_person_check_cancels(m) then camera_unfreeze(); return end
    camera_freeze()
    local cp=math.cos(T.pitch)
    local d={x=math.sin(T.yaw)*cp,y=math.sin(T.pitch),z=math.cos(T.yaw)*cp}
    T.direction=d
    local subject=m.pos
    if dead and m.marioBodyState.tpsRagdoll then
        local p=m.marioBodyState.tpsRagdollNodes[1]
        subject={x=p.x,y=p.y-50,z=p.z}
    end
    local anchor={x=subject.x,y=subject.y+(mario_is_crouching(m) and 85 or 130),z=subject.z}
    local offset={x=-d.x*380-math.cos(T.yaw)*T.shoulder,
        y=-d.y*380+25,z=-d.z*380+math.sin(T.yaw)*T.shoulder}
    local length=math.sqrt(offset.x^2+offset.y^2+offset.z^2)
    local hit=collision_find_surface_on_ray(anchor.x,anchor.y,anchor.z,offset.x,offset.y,offset.z)
    local scale=1
    if hit.surface then scale=math.max(0.03,(FpsCombat.distance(anchor,hit.hitPos)-20)/length) end
    T.pos={x=anchor.x+offset.x*scale,y=anchor.y+offset.y*scale,z=anchor.z+offset.z*scale}
    local focus={x=T.pos.x+d.x*1000,y=T.pos.y+d.y*1000,z=T.pos.z+d.z*1000}
    for _,name in ipairs({'pos','curPos','goalPos'}) do copy(gLakituState[name],T.pos) end
    for _,name in ipairs({'focus','curFocus','goalFocus'}) do copy(gLakituState[name],focus) end
    copy(m.area.camera.pos,T.pos); copy(m.area.camera.focus,focus)
    gLakituState.roll=0
    gLakituState.shakeMagnitude.x,gLakituState.shakeMagnitude.y,gLakituState.shakeMagnitude.z=0,0,0
end

hook_event(HOOK_BEFORE_MARIO_UPDATE,T.input)
hook_event(HOOK_MARIO_UPDATE,T.update)
