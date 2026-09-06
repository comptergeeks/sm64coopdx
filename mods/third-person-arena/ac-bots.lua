FpsBots={bots={},visuals={},count=2,kills=0,seen={},epoch=0}
local B,C=FpsBots,FpsCombat
local MAX_BOTS=4
local function key(id,field) return 'fpsBot'..id..field end
local function put(id,field,value) gGlobalSyncTable[key(id,field)]=value end
local function get(id,field) return gGlobalSyncTable[key(id,field)] end
function B.is_id(id) return type(id)=='number' and id>=MAX_PLAYERS and id<MAX_PLAYERS+MAX_BOTS end
function B.id(index) return MAX_PLAYERS+index-1 end
function B.in_area()
    local np=gNetworkPlayers[0]
    return gGlobalSyncTable.fpsBotLevel==np.currLevelNum and gGlobalSyncTable.fpsBotArea==np.currAreaIndex
        and gGlobalSyncTable.fpsBotAct==np.currActNum and gGlobalSyncTable.fpsBotCourse==np.currCourseNum
end
function B.generation(id) return get(id-MAX_PLAYERS+1,'generation') end

local behavior=hook_behavior(nil,OBJ_LIST_GENACTOR,false,function(o)
    o.oFlags=OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
    o.oAnimations=gObjectAnimations.koopa_seg6_anims_06011364
    o.oDrawingDistance=12000
    obj_scale(o,1.6)
end,function(o) cur_obj_init_animation(9) end)

local function destroy_visuals()
    for _,v in pairs(B.visuals) do
        obj_mark_for_deletion(v.body)
        obj_mark_for_deletion(v.gun)
    end
    B.visuals={}
end

local function publish(bot)
    for _,field in ipairs({'x','y','z','yaw','hp','generation','death','dx','dy','dz','flash','hx','hy','hz','vx','vy','vz'}) do
        put(bot.index,field,bot[field] or 0)
    end
end

function B.reset()
    destroy_visuals()
    B.seen={}
    if network_is_server() then
        B.bots={}
        B.epoch=B.epoch+1
        B.start=get_global_timer()+90
        gGlobalSyncTable.fpsBotEpoch=B.epoch
        gGlobalSyncTable.fpsBotCount=0
        gGlobalSyncTable.fpsBotAwake=false
    end
end

local function safe_floor(x,y,z)
    local height=find_floor_height(x,y,z)
    if collision_find_floor and not C.safe_surface(collision_find_floor(x,y,z)) then return -11000 end
    if find_water_level and height<find_water_level(x,z)-30 then return -11000 end
    return height
end

local function spawn(index,generation)
    local m=gMarioStates[0]
    for attempt=0,15 do
        local angle=ThirdPersonCamera.yaw+(index-1.5)*0.7+attempt*0.42
        local radius=650+attempt*25
        local x,z=m.pos.x+math.sin(angle)*radius,m.pos.z+math.cos(angle)*radius
        local y=safe_floor(x,m.pos.y+400,z)
        if y>-10000 and math.abs(y-m.pos.y)<300 then
            local wall=collision_find_surface_on_ray(m.pos.x,m.pos.y+90,m.pos.z,x-m.pos.x,y-m.pos.y,z-m.pos.z)
            if not wall.surface then
                local bot={index=index,x=x,y=y,z=z,yaw=0,hp=3,generation=generation or 1,death=0,
                    cooldown=get_global_timer()+120+index*30,dx=0,dy=0,dz=0,flash=0}
                B.bots[index]=bot
                publish(bot)
                return bot
            end
        end
    end
end

function B.targets()
    local targets={}
    if not network_is_server() then
        if not B.in_area() then return targets end
        for index=1,(gGlobalSyncTable.fpsBotCount or 0) do
            if (get(index,'hp') or 0)>0 and get(index,'x') and get(index,'y') and get(index,'z') then
                targets[#targets+1]={id=B.id(index),height=160,
                    pos={x=get(index,'x'),y=get(index,'y'),z=get(index,'z')}}
            end
        end
        return targets
    end
    for _,bot in pairs(B.bots) do
        if bot.hp>0 then targets[#targets+1]={id=B.id(bot.index),pos=bot,height=160} end
    end
    return targets
end

function B.damage(id,direction,point)
    local bot=B.bots[id-MAX_PLAYERS+1]
    if not bot or bot.hp<=0 then return false end
    bot.hp=bot.hp-1
    bot.dx,bot.dy,bot.dz=direction.x,direction.y,direction.z
    point=point or {x=bot.x,y=bot.y+100,z=bot.z}
    bot.hx,bot.hy,bot.hz=point.x,point.y,point.z
    bot.cooldown=get_global_timer()+75 -- hit-stun gives the player breathing room
    if bot.hp==0 then
        bot.death=bot.generation
        bot.respawn=get_global_timer()+180
        B.kills=B.kills+1
        gGlobalSyncTable.fpsBotKills=B.kills
    end
    publish(bot)
    return true
end

local function nearest(bot)
    local best,distance
    for i=0,MAX_PLAYERS-1 do
        if FpsArena.active(i) then
            local m=gMarioStates[i]
            local d=C.distance(bot,m.pos)
            if not distance or d<distance then best,distance=m,d end
        end
    end
    return best,distance
end

local function move(bot,target,distance)
    bot.vx,bot.vy,bot.vz=0,0,0
    local dx,dz=target.pos.x-bot.x,target.pos.z-bot.z
    local length=math.sqrt(dx*dx+dz*dz)
    if length<1 then return end
    dx,dz=dx/length,dz/length
    bot.yaw=atan2s(dz,dx)
    local approach=distance>650 and 1 or (distance<330 and -1 or 0)
    local strafe=math.sin(get_global_timer()*0.025+bot.index*2)*0.75
    local vx,vz=(dx*approach-dz*strafe)*5,(dz*approach+dx*strafe)*5
    local x,z=bot.x+vx,bot.z+vz
    local floor=safe_floor(x,bot.y+100,z)
    if floor < -10000 or floor-bot.y>45 or bot.y-floor>80 then return end
    local lengthMove=math.sqrt(vx*vx+vz*vz)
    if lengthMove<0.1 then return end
    local wall=collision_find_surface_on_ray(bot.x,bot.y+65,bot.z,
        vx/lengthMove*(lengthMove+50),0,vz/lengthMove*(lengthMove+50))
    if not wall.surface then
        bot.vx,bot.vy,bot.vz=x-bot.x,floor-bot.y,z-bot.z
        bot.x,bot.y,bot.z=x,floor,z
    end
end

local function host_update()
    local now=get_global_timer()
    if not B.start then B.reset() end
    local np=gNetworkPlayers[0]
    if now<B.start or not np.currLevelSyncValid or not np.currAreaSyncValid then return end
    gGlobalSyncTable.fpsBotLevel,gGlobalSyncTable.fpsBotArea=np.currLevelNum,np.currAreaIndex
    gGlobalSyncTable.fpsBotAct,gGlobalSyncTable.fpsBotCourse=np.currActNum,np.currCourseNum
    gGlobalSyncTable.fpsBotCount=B.count
    for index=1,B.count do
        local bot=B.bots[index] or spawn(index,1)
        if bot then
            if bot.hp<=0 then
                if now>=bot.respawn then spawn(index,bot.generation+1) end
            else
                local target,distance=nearest(bot)
                if target then
                    move(bot,target,distance)
                    if gGlobalSyncTable.fpsBotAwake and now>=bot.cooldown and distance<2200 then
                        bot.flash=now+12
                        bot.cooldown=now+90+index*10
                        -- Aim is deliberately imperfect; dodging and strafing should work.
                        local aim={x=target.pos.x+math.sin(now*0.13+index)*55,y=target.pos.y+90,z=target.pos.z}
                        -- Match the rendered pistol's +Z barrel tip, including its side offset.
                        local origin={x=bot.x+sins(bot.yaw)*52.4-coss(bot.yaw)*40,
                            y=bot.y+79.6,z=bot.z+coss(bot.yaw)*52.4+sins(bot.yaw)*40}
                        local length=C.distance(origin,aim)
                        if length>1 then
                            FpsArena.bot_shot(bot,origin,{x=(aim.x-origin.x)/length,
                                y=(aim.y-origin.y)/length,z=(aim.z-origin.z)/length})
                        end
                    end
                end
                if now%3==0 then publish(bot) end
            end
        end
    end
end

local function render_update()
    if not B.in_area() then destroy_visuals(); return end
    local epoch=gGlobalSyncTable.fpsBotEpoch
    if B.visualEpoch~=epoch then destroy_visuals(); B.seen={}; B.visualEpoch=epoch end
    for index=1,MAX_BOTS do
        local hp=get(index,'hp')
        local exists=index<=(gGlobalSyncTable.fpsBotCount or 0) and hp~=nil
        local v=B.visuals[index]
        if exists and hp>0 then
            local pos={x=get(index,'x'),y=get(index,'y'),z=get(index,'z')}
            if pos.x and pos.y and pos.z then
                if not v then
                    v={body=spawn_non_sync_object(behavior,E_MODEL_KOOPA_WITH_SHELL,pos.x,pos.y,pos.z,function() end),
                        gun=FpsRagdoll.object(E_MODEL_TPS_PISTOL,pos,0.60)}
                    if not v.body or not v.gun then
                        if v.body then obj_mark_for_deletion(v.body) end
                        if v.gun then obj_mark_for_deletion(v.gun) end
                        return
                    end
                    B.visuals[index]=v
                end
                local yaw=get(index,'yaw') or 0
                v.body.oPosX=v.body.oPosX+(pos.x-v.body.oPosX)*0.45
                v.body.oPosY=v.body.oPosY+(pos.y-v.body.oPosY)*0.45
                v.body.oPosZ=v.body.oPosZ+(pos.z-v.body.oPosZ)*0.45
                v.body.oFaceAngleYaw=yaw
                v.gun.oPosX=v.body.oPosX+sins(yaw)*20-coss(yaw)*40
                v.gun.oPosY=v.body.oPosY+70
                v.gun.oPosZ=v.body.oPosZ+coss(yaw)*20+sins(yaw)*40
                local flash=get(index,'flash') or 0
                if flash>0 and flash~=v.flash and FpsWeapon then
                    v.flash=flash
                    FpsWeapon.flash_at({x=v.gun.oPosX+sins(yaw)*32,y=v.gun.oPosY+10,z=v.gun.oPosZ+coss(yaw)*32})
                end
                v.gun.oFaceAngleYaw=yaw
            end
        elseif v then
            obj_mark_for_deletion(v.body); obj_mark_for_deletion(v.gun); B.visuals[index]=nil
        end
        local death=get(index,'death') or 0
        if exists and hp==0 and death>0 and B.seen[index]~=death then
            B.seen[index]=death
            local pos={x=get(index,'x'),y=get(index,'y'),z=get(index,'z')}
            if pos.x and pos.y and pos.z then
                FpsRagdoll.spawn(pos,(get(index,'yaw') or 0)*math.pi/32768,
                    {x=get(index,'dx') or 0,y=get(index,'dy') or 0,z=get(index,'dz') or 0},true,nil,
                    {point={x=get(index,'hx') or pos.x,y=get(index,'hy') or pos.y+100,z=get(index,'hz') or pos.z},
                        velocity={x=get(index,'vx') or 0,y=get(index,'vy') or 0,z=get(index,'vz') or 0},kind='blaster'})
            end
        end
    end
end

function B.update()
    if not FpsArena or is_game_paused() then return end
    if network_is_server() then host_update() end
    render_update()
    FpsRagdoll.update()
end

hook_event(HOOK_UPDATE,B.update)
hook_event(HOOK_ON_WARP,B.reset)
hook_event(HOOK_ON_CLEAR_AREAS,function() B.visuals={}; FpsRagdoll.bodies={} end)
hook_chat_command('bots','[0-4] Set training bots (host only).',function(message)
    if not network_is_server() then djui_chat_message_create('Only the host can change bots.'); return true end
    local count=tonumber(message)
    if not count or count%1~=0 or count<0 or count>MAX_BOTS then
        djui_chat_message_create('Use /bots 0 through /bots 4.'); return true
    end
    B.count=count; B.reset()
    djui_chat_message_create('Training bots: '..count)
    return true
end)
