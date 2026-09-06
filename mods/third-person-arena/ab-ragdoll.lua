-- Small cosmetic Verlet skeleton. Gameplay never depends on these local bodies.
FpsRagdoll = {bodies={}}
local R = FpsRagdoll
local offsets = {{0,72,0},{0,115,0},{0,157,0}, {-37,112,0},{-53,76,9},
    {37,112,0},{53,76,9}, {-23,43,0},{-23,12,8},{23,43,0},{23,12,8}}
local links = {{1,2},{2,3},{2,4},{4,5},{2,6},{6,7},{1,8},{8,9},{1,10},{10,11},
    {4,6},{8,10},{1,4},{1,6}}

function R.skeleton(pos, yaw, velocity)
    local body={nodes={},links={},age=0}
    local s,c=math.sin(yaw),math.cos(yaw)
    for i,v in ipairs(offsets) do
        local x,y,z=pos.x+v[1]*c+v[3]*s,pos.y+v[2],pos.z-v[1]*s+v[3]*c
        body.nodes[i]={x=x,y=y,z=z,px=x-velocity.x,py=y-velocity.y,pz=z-velocity.z}
    end
    for _,v in ipairs(links) do
        local a,b=body.nodes[v[1]],body.nodes[v[2]]
        body.links[#body.links+1]={v[1],v[2],FpsCombat.distance(a,b)}
    end
    return body
end

function R.step(body, collide)
    body.age=body.age+1
    for _,p in ipairs(body.nodes) do
        local x,y,z=p.x,p.y,p.z
        p.x=p.x+(p.x-p.px)*0.985
        p.y=p.y+(p.y-p.py)*0.985-2.3
        p.z=p.z+(p.z-p.pz)*0.985
        p.px,p.py,p.pz=x,y,z
    end
    for iteration=1,8 do
        for _,link in ipairs(body.links) do
            local a,b=body.nodes[link[1]],body.nodes[link[2]]
            local dx,dy,dz=b.x-a.x,b.y-a.y,b.z-a.z
            local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
            if distance>0.001 then
                local correction=(distance-link[3])/distance*0.5
                dx,dy,dz=dx*correction,dy*correction,dz*correction
                a.x,a.y,a.z=a.x+dx,a.y+dy,a.z+dz
                b.x,b.y,b.z=b.x-dx,b.y-dy,b.z-dz
            end
        end
        for _,p in ipairs(body.nodes) do collide(p) end
    end
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

function R.spawn(pos,yaw,direction,koopa)
    if #R.bodies>=8 then
        local old=table.remove(R.bodies,1)
        for _,o in ipairs(old.objects) do obj_mark_for_deletion(o) end
    end
    local body=R.skeleton(pos,yaw,{x=direction.x*17,y=12+direction.y*10,z=direction.z*17})
    body.objects={}
    for i,p in ipairs(body.nodes) do
        local model=E_MODEL_METALLIC_BALL
        local scale=(i==1 or i==2) and 0.32 or 0.16
        if i==1 and koopa then model,scale=E_MODEL_KOOPA_SHELL,0.85 end
        if i==3 then model,scale=koopa and E_MODEL_YELLOW_SPHERE or E_MODEL_MARIOS_CAP,koopa and 0.6 or 1 end
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
    if floor>-10000 and p.y<floor+12 then
        p.y=floor+12
        p.px=p.x-(p.x-p.px)*0.72
        p.pz=p.z-(p.z-p.pz)*0.72
        p.py=p.y
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
        if body.age>=300 then
            for _,o in ipairs(body.objects) do obj_mark_for_deletion(o) end
            table.remove(R.bodies,i)
        else
            -- Stop the costly solver after settling; the body remains until expiry.
            if body.age<120 then R.step(body,collide) else body.age=body.age+1 end
            for j,o in ipairs(body.objects) do
                local p=body.nodes[j]
                o.oPosX,o.oPosY,o.oPosZ=p.x,p.y,p.z
                if j==1 or j==3 then o.oFaceAngleRoll=(body.nodes[2].x-body.nodes[1].x)*150 end
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
end
