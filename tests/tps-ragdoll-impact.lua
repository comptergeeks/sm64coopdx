dofile('mods/third-person-arena/aa-combat.lua')
dofile('mods/third-person-arena/ab-ragdoll.lua')
local R=FpsRagdoll
local function body() return R.skeleton({x=0,y=0,z=0},0,{x=0,y=0,z=0}) end
local b=body()
R.impact(b,{x=0,y=0,z=1},{point={x=-50,y=110,z=0},velocity={x=10,y=0,z=0}})
assert(b.nodes[4].z-b.nodes[4].pz>b.nodes[6].z-b.nodes[6].pz,'near shoulder did not receive stronger impact')
for _,p in ipairs(b.nodes) do assert(math.abs((p.x-p.px)-8.5)<0.001,'running momentum was discarded') end
assert(b.nodes[2].y-b.nodes[2].py==2,'blaster hit adds excessive vertical launch')
local function spin(impactX)
 local b=body(); R.impact(b,{x=0,y=0,z=1},{point={x=impactX,y=110,z=0}})
 local torque=0
 for _,p in ipairs(b.nodes) do torque=torque-p.x*(p.z-p.pz)/p.invMass end
 return torque
end
assert(spin(-50)>0 and spin(50)<0,'opposite-side hits did not produce opposite tumble directions')
local falling=body()
R.impact(falling,{x=0,y=0,z=1},{kind='fall',velocity={x=0,y=-20,z=0}})
assert(falling.nodes[1].y-falling.nodes[1].py==-17,'environment death invented an upward weapon kick')
for i=1,180 do R.step(falling,function() end) end
assert(not falling.sleeping and falling.nodes[1].y<0,'airborne body froze at an age limit')
local extreme=body()
R.impact(extreme,{x=0,y=0,z=1},{velocity={x=1000,y=1000,z=1000},strength=100})
for _,p in ipairs(extreme.nodes) do
 local speed=math.sqrt((p.x-p.px)^2+(p.y-p.py)^2+(p.z-p.pz)^2)
 assert(speed<=R.impactProfile.maxSpeed+0.001,'impact speed exceeded safety bound')
end
for i=1,300 do
 R.step(b,function(p)
  if p.y<12 then p.y=12; p.py=12; p.px=p.x; p.pz=p.z; p.grounded=true end
 end)
end
assert(b.sleeping,'grounded motionless body never slept')
for _,p in ipairs(b.nodes) do assert(FpsCombat.finite(p.x) and FpsCombat.finite(p.y) and p.y>=12,'body became invalid') end
for i,link in ipairs(b.links) do
 if i<=10 then assert(math.abs(FpsCombat.distance(b.nodes[link[1]],b.nodes[link[2]])-link[3])<4,'anatomical joint stretched') end
end
print('Passed ragdoll impact checks: localized kick, opposite spin, inherited momentum, restrained lift, fall continuity, speed bound, settling and joint lengths')
