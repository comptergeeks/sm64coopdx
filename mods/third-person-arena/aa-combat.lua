-- Engine-independent geometry and admission rules; loaded before main.lua.
FpsCombat = {}
local C = FpsCombat
C.RANGE = 6000
C.COOLDOWN = 12 -- simulation ticks (30 Hz)
C.DAMAGE = 0x200 -- two wedges
C.RADIUS = 45

function C.finite(n)
    return type(n) == 'number' and n == n and math.abs(n) < math.huge
end

function C.same_area(a, b)
    return a.currCourseNum == b.currCourseNum and a.currActNum == b.currActNum
        and a.currLevelNum == b.currLevelNum and a.currAreaIndex == b.currAreaIndex
end

function C.distance(a, b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end

function C.valid_shot(p)
    if type(p) ~= 'table' then return false end
    for _, key in ipairs({'shooter', 'seq', 'epoch', 'ox', 'oy', 'oz', 'dx', 'dy', 'dz'}) do
        if not C.finite(p[key]) then return false end
    end
    if p.shooter < 0 or p.shooter % 1 ~= 0 or p.seq < 1 or p.seq % 1 ~= 0 then return false end
    if p.seq > 0x7FFFFFFF then return false end
    local length = p.dx*p.dx + p.dy*p.dy + p.dz*p.dz
    return math.abs(length - 1) < 0.01
        and math.max(math.abs(p.ox), math.abs(p.oy), math.abs(p.oz)) < 1000000
end

-- Distance to the first intersection with a sphere, including an inside origin.
function C.ray_sphere(o, d, center, radius)
    local x, y, z = o.x-center.x, o.y-center.y, o.z-center.z
    local c = x*x + y*y + z*z - radius*radius
    if c <= 0 then return 0 end
    local b = x*d.x + y*d.y + z*d.z
    local disc = b*b-c
    if disc < 0 then return nil end
    local t = -b-math.sqrt(disc)
    if t >= 0 then return t end
end

-- Upright capsule: segment endpoints are sphere centers above the feet.
function C.ray_capsule(o, d, feet, height)
    local radius = C.RADIUS
    local bottom, top = feet.y+radius, feet.y+math.max(radius, height-radius)
    local x, z = o.x-feet.x, o.z-feet.z
    if o.y >= bottom and o.y <= top and x*x+z*z <= radius*radius then return 0 end
    local best
    local function consider(t)
        if t and t >= 0 and (not best or t < best) then best = t end
    end
    consider(C.ray_sphere(o, d, {x=feet.x, y=bottom, z=feet.z}, radius))
    consider(C.ray_sphere(o, d, {x=feet.x, y=top, z=feet.z}, radius))
    local a = d.x*d.x+d.z*d.z
    local b = x*d.x+z*d.z
    local disc = b*b-a*(x*x+z*z-radius*radius)
    if a > 1e-9 and disc >= 0 then
        for _, t in ipairs({(-b-math.sqrt(disc))/a, (-b+math.sqrt(disc))/a}) do
            local y = o.y+t*d.y
            if y >= bottom and y <= top then consider(t) end
        end
    end
    return best
end

-- Walls win ties; the weapon never penetrates the first player or wall.
function C.pick_target(origin, direction, players, wallDistance)
    local best, distance = nil, math.min(C.RANGE, wallDistance or C.RANGE)
    for _, player in ipairs(players) do
        local t = C.ray_capsule(origin, direction, player.pos, player.height)
        if t and t < distance then best, distance = player.id, t end
    end
    return best, distance
end

function C.admit(history, p, tick)
    if not C.valid_shot(p) then return false end
    local last = history[p.shooter]
    if last and (p.seq <= last.seq or tick-last.tick < C.COOLDOWN) then return false end
    history[p.shooter] = {seq=p.seq, tick=tick}
    return true
end
