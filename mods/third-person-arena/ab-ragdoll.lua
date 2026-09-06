-- Cosmetic mass-weighted Verlet skeleton. See docs/ragdoll-impact-research.md.
FpsRagdoll = {bodies={}}
local R = FpsRagdoll
-- Art-directed SM64 units/tick, not proprietary Frostbite force constants.
R.impactProfile={bodyKick=7,localKick=16,lift=2,spread=75,inherit=0.85,maxSpeed=38}
local masses={7,8,4,1.5,1,1.5,1,3,1.5,3,1.5}
local offsets = {{0,72,0},{0,115,0},{0,157,0}, {-37,112,0},{-53,76,9},
    {37,112,0},{53,76,9}, {-23,43,0},{-23,12,8},{23,43,0},{23,12,8}}
local links = {{1,2},{2,3},{2,4},{4,5},{2,6},{6,7},{1,8},{8,9},{1,10},{10,11},
    {4,6},{8,10},{1,4},{1,6}}

function R.skeleton(pos, yaw, velocity)
    local body={nodes={},links={},age=0}
    local s,c=math.sin(yaw),math.cos(yaw)
    for i,v in ipairs(offsets) do
        local x,y,z=pos.x+v[1]*c+v[3]*s,pos.y+v[2],pos.z-v[1]*s+v[3]*c
        body.nodes[i]={x=x,y=y,z=z,px=x-velocity.x,py=y-velocity.y,pz=z-velocity.z,invMass=1/masses[i]}
    end
    for _,v in ipairs(links) do
        local a,b=body.nodes[v[1]],body.nodes[v[2]]
        body.links[#body.links+1]={v[1],v[2],FpsCombat.distance(a,b)}
    end
    return body
end

function R.impact(body,direction,impact)
    impact=impact or {}
    local profile=R.impactProfile
    local magnitude=math.sqrt(direction.x^2+direction.y^2+direction.z^2)
    local d=magnitude>0.001 and {x=direction.x/magnitude,y=direction.y/magnitude,z=direction.z/magnitude}
        or {x=0,y=0,z=0}
    local point=impact.point or body.nodes[2]
    local velocity=impact.velocity or {x=0,y=0,z=0}
    local strength=impact.kind=='fall' and 0 or math.max(0,math.min(3,impact.strength or 1))
    for _,p in ipairs(body.nodes) do
        local distance=FpsCombat.distance(p,point)
        local weight=math.exp(-(distance/profile.spread)^2)
        local kick=strength*(profile.bodyKick+profile.localKick*weight)
        local vx=velocity.x*profile.inherit+d.x*kick
        local vy=velocity.y*profile.inherit+d.y*kick+profile.lift*strength
        local vz=velocity.z*profile.inherit+d.z*kick
        local speed=math.sqrt(vx*vx+vy*vy+vz*vz)
        local clamp=math.min(1,profile.maxSpeed/math.max(0.001,speed))
        p.px,p.py,p.pz=p.x-vx*clamp,p.y-vy*clamp,p.z-vz*clamp
    end
    body.impactAge=0; body.quietFrames=0; body.sleeping=false
end

function R.step(body, collide)
    body.age=body.age+1
    for _,p in ipairs(body.nodes) do
        local x,y,z=p.x,p.y,p.z
        p.grounded=false
        p.x=p.x+(p.x-p.px)*0.985
        p.y=p.y+(p.y-p.py)*0.985-2.3
        p.z=p.z+(p.z-p.pz)*0.985
        p.px,p.py,p.pz=x,y,z
    end
    for iteration=1,8 do
        for index,link in ipairs(body.links) do
            local a,b=body.nodes[link[1]],body.nodes[link[2]]
            local dx,dy,dz=b.x-a.x,b.y-a.y,b.z-a.z
            local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
            if distance>0.001 then
                -- Brace support eases off over the first eight ticks; anatomical
                -- links keep their lengths while the impact breaks the pose.
                local stiffness=index>10 and (0.25+0.75*math.max(0,1-body.age/8)) or 1
                local correction=(distance-link[3])/distance*stiffness
                local total=(a.invMass or 1)+(b.invMass or 1)
                local wa,wb=(a.invMass or 1)/total,(b.invMass or 1)/total
                dx,dy,dz=dx*correction,dy*correction,dz*correction
                a.x,a.y,a.z=a.x+dx*wa,a.y+dy*wa,a.z+dz*wa
                b.x,b.y,b.z=b.x-dx*wb,b.y-dy*wb,b.z-dz*wb
            end
        end
        for _,p in ipairs(body.nodes) do collide(p) end
    end
    local energy,contacts=0,0
    for _,p in ipairs(body.nodes) do
        energy=energy+(p.x-p.px)^2+(p.y-p.py)^2+(p.z-p.pz)^2
        if p.grounded then contacts=contacts+1 end
    end
    body.quietFrames=contacts>=2 and energy/#body.nodes<0.15 and ((body.quietFrames or 0)+1) or 0
    body.sleeping=body.quietFrames>=20
end

-- Behavior registration is load-only in coopdx. The solver also runs without the engine.
local behavior=hook_behavior and hook_behavior(nil, OBJ_LIST_GENACTOR, false, function(o)
            o.oFlags=OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
            o.oOpacity=255
            o.oDrawingDistance=12000
        end, function() end)
function R.object(model, pos, scale)
    return spawn_non_sync_object(behavior,model,pos.x,pos.y,pos.z,function(o) obj_scale(o,scale) end)
end

function R.spawn(pos,yaw,direction,koopa,m,impact)
    if #R.bodies>=8 then
        local old=table.remove(R.bodies,1)
        if old.player~=nil then gMarioStates[old.player].marioBodyState.tpsRagdoll=false end
        for _,o in ipairs(old.objects) do obj_mark_for_deletion(o) end
    end
    local body=R.skeleton(pos,yaw,{x=0,y=0,z=0})
    body.objects={}
    if m then
        local parts={MARIO_ANIM_PART_BUTT,MARIO_ANIM_PART_TORSO,MARIO_ANIM_PART_HEAD,
            MARIO_ANIM_PART_LEFT_FOREARM,MARIO_ANIM_PART_LEFT_HAND,
            MARIO_ANIM_PART_RIGHT_FOREARM,MARIO_ANIM_PART_RIGHT_HAND,
            MARIO_ANIM_PART_LEFT_LEG,MARIO_ANIM_PART_LEFT_FOOT,
            MARIO_ANIM_PART_RIGHT_LEG,MARIO_ANIM_PART_RIGHT_FOOT}
        for i,part in ipairs(parts) do
            local p=m.marioBodyState.animPartsPos[part+1]
            local n=body.nodes[i]
            n.radius=(i<=3) and 28 or 10
            if FpsCombat.distance(p,pos)<300 then
                n.x,n.y,n.z=p.x,p.y,p.z
                n.px,n.py,n.pz=p.x,p.y,p.z
            end
        end
        for _,link in ipairs(body.links) do link[3]=FpsCombat.distance(body.nodes[link[1]],body.nodes[link[2]]) end
        R.impact(body,direction,impact)
        body.player=m.playerIndex
        m.marioBodyState.tpsRagdoll=true
        for i,n in ipairs(body.nodes) do
            local p=m.marioBodyState.tpsRagdollNodes[i]
            p.x,p.y,p.z=n.x,n.y,n.z
        end
        R.bodies[#R.bodies+1]=body
        return
    end
    R.impact(body,direction,impact)
    for i,p in ipairs(body.nodes) do
        local model=E_MODEL_METALLIC_BALL
        local scale=(i==1 or i==2) and 0.32 or 0.16
        if koopa and E_MODEL_TPS_KOOPA_BODY then
            local models={E_MODEL_TPS_KOOPA_BODY,E_MODEL_METALLIC_BALL,E_MODEL_TPS_KOOPA_HEAD,
                E_MODEL_TPS_KOOPA_ARM,E_MODEL_TPS_KOOPA_HAND,E_MODEL_TPS_KOOPA_ARM,E_MODEL_TPS_KOOPA_HAND,
                E_MODEL_TPS_KOOPA_LEG,E_MODEL_TPS_KOOPA_FOOT,E_MODEL_TPS_KOOPA_LEG,E_MODEL_TPS_KOOPA_FOOT}
            model,scale=models[i],i==2 and 0.001 or 0.4
            body.koopa=true; body.yaw=yaw
        else
            if i==1 and koopa then model,scale=E_MODEL_KOOPA_SHELL,0.85 end
            if i==3 then model,scale=koopa and E_MODEL_YELLOW_SPHERE or E_MODEL_MARIOS_CAP,koopa and 0.6 or 1 end
        end
        body.objects[i]=R.object(model,p,scale)
        if not body.objects[i] then
            for _,o in pairs(body.objects) do obj_mark_for_deletion(o) end
            return
        end
    end
    R.bodies[#R.bodies+1]=body
end

local function collide(p)
    local floor=find_floor_height(p.x,math.max(p.y,p.py)+35,p.z)
    local radius=p.radius or 12
    if floor>-10000 and p.y<floor+radius then
        local vy=p.y-p.py
        p.y=floor+radius
        -- Contact damping happens once per tick, not eight times per solver pass.
        if not p.grounded then
            p.px=p.x-(p.x-p.px)*0.82
            p.pz=p.z-(p.z-p.pz)*0.82
            p.py=p.y+math.min(0,vy)*0.08
        end
        p.grounded=true
    end
    local dx,dy,dz=p.x-p.px,p.y-p.py,p.z-p.pz
    if dx*dx+dy*dy+dz*dz>1 then
        local hit=collision_find_surface_on_ray(p.px,p.py,p.pz,dx,dy,dz)
        if hit.surface then
            p.x,p.y,p.z=p.px,p.py,p.pz
        end
    end
end

function R.update()
    for i=#R.bodies,1,-1 do
        local body=R.bodies[i]
        if (body.player==nil and body.age>=300) or (body.player~=nil and not gPlayerSyncTable[body.player].tpsDead) then
            if body.player~=nil then gMarioStates[body.player].marioBodyState.tpsRagdoll=false end
            for _,o in ipairs(body.objects) do obj_mark_for_deletion(o) end
            table.remove(R.bodies,i)
        else
            -- Sleep only after sustained ground contact and low kinetic energy.
            -- Bodies still falling or tumbling never freeze at a fixed age.
            if body.sleeping and body.age%10==0 then
                for _,p in ipairs(body.nodes) do
                    if p.grounded then
                        local floor=find_floor_height(p.x,p.y+45,p.z)
                        if math.abs(p.y-floor-(p.radius or 12))>6 then
                            body.sleeping=false; body.quietFrames=0; break
                        end
                    end
                end
            end
            if not body.sleeping then R.step(body,collide) else body.age=body.age+1 end
            if body.player~=nil then
                local m=gMarioStates[body.player]
                for j,n in ipairs(body.nodes) do
                    local p=m.marioBodyState.tpsRagdollNodes[j]
                    p.x,p.y,p.z=n.x,n.y,n.z
                end
            end
            for j,o in ipairs(body.objects) do
                local p=body.nodes[j]
                o.oPosX,o.oPosY,o.oPosZ=p.x,p.y,p.z
                if body.koopa then
                    local target=({[1]=2,[3]=2,[4]=5,[6]=7,[8]=9,[10]=11})[j]
                    if target then
                        local q=body.nodes[target]
                        local dx,dy,dz=q.x-p.x,q.y-p.y,q.z-p.z
                        if j==3 then dx,dy,dz=-dx,-dy,-dz end
                        o.oFaceAngleYaw=atan2s(dx,-dz)
                        o.oFaceAngleRoll=atan2s(math.sqrt(dx*dx+dz*dz),dy)
                    else
                        o.oFaceAngleYaw=body.yaw*32768/math.pi+16384
                        o.oFaceAngleRoll=16384
                    end
                elseif j==1 or j==3 then o.oFaceAngleRoll=(body.nodes[2].x-body.nodes[1].x)*150 end
            end
        end
    end
end

function R.clear()
    -- Called before old level objects are destroyed; never retain stale object handles.
    for _,body in ipairs(R.bodies) do
        for _,o in ipairs(body.objects) do obj_mark_for_deletion(o) end
    end
    R.bodies={}
    if gMarioStates then for i=0,MAX_PLAYERS-1 do gMarioStates[i].marioBodyState.tpsRagdoll=false end end
end
