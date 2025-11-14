-- Simple Putt-Putt (mini golf) game
-- Aim with the mouse, hold SPACE to charge power, release SPACE to shoot.

local function dist(x1,y1,x2,y2)
  return ((x1-x2)^2 + (y1-y2)^2)^0.5
end

function love.load()
  love.window.setTitle("Putt-Putt Golf - Mouse aim, Space to shoot")
  width, height = 800, 600
  love.window.setMode(width, height)

  ball = { x = 120, y = height/2, r = 10, vx = 0, vy = 0 }
  hole = { x = width - 120, y = height/2 + 30, r = 14 }

  -- barriers: generated randomly but not overlapping ball or hole
  barriers = {}
  local function rects_overlap(rx,ry,rw,rh, x2,y2,w2,h2)
    return not (rx+rw < x2 or x2+w2 < rx or ry+rh < y2 or y2+h2 < ry)
  end
  local attempts = 0
  while #barriers < 4 and attempts < 200 do
    attempts = attempts + 1
    local bw = math.random(60, 160)
    local bh = math.random(20, 80)
    local bx = math.random(80, width - 80 - bw)
    local by = math.random(80, height - 80 - bh)
    local ok = true
    -- avoid overlapping ball/hole start areas
    if dist(bx+bw/2, by+bh/2, ball.x, ball.y) < 120 then ok = false end
    if dist(bx+bw/2, by+bh/2, hole.x, hole.y) < 120 then ok = false end
    for _,r in ipairs(barriers) do
      if rects_overlap(bx,by,bw,bh, r.x,r.y,r.w,r.h) then ok = false; break end
    end
    if ok then table.insert(barriers, { x=bx, y=by, w=bw, h=bh }) end
  end

  charging = false
  power = 0
  maxPower = 900        -- translates roughly to initial speed
  minPower = 100        -- minimum power to shoot
  chargeRate = 600     -- how fast power increases per second

  friction = 0.98      -- per-frame multiplier (close enough for simple physics)
  sunk = false
  score = 0
  attempts = 0
end

function love.update(dt)
  -- Charging power while holding space
  if charging then
    power = math.min(maxPower, power + chargeRate * dt)
  end

  -- Update ball physics
  if not sunk then
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    -- simple damping
    ball.vx = ball.vx * (1 - (1-friction) * dt * 60)
    ball.vy = ball.vy * (1 - (1-friction) * dt * 60)

    -- clamp very small velocities to zero
    if math.abs(ball.vx) < 1e-2 then ball.vx = 0 end
    if math.abs(ball.vy) < 1e-2 then ball.vy = 0 end

    -- wall collisions (reflect with some loss)
    if ball.x - ball.r < 0 then
      ball.x = ball.r
      ball.vx = -ball.vx * 0.6
    end
    if ball.x + ball.r > width then
      ball.x = width - ball.r
      ball.vx = -ball.vx * 0.6
    end
    if ball.y - ball.r < 0 then
      ball.y = ball.r
      ball.vy = -ball.vy * 0.6
    end
    if ball.y + ball.r > height then
      ball.y = height - ball.r
      ball.vy = -ball.vy * 0.6
    end

    -- Barriers collisions (circle vs AABB)
    for _,r in ipairs(barriers) do
      -- find closest point on rect to circle center
      local closestX = math.max(r.x, math.min(ball.x, r.x + r.w))
      local closestY = math.max(r.y, math.min(ball.y, r.y + r.h))
      local dx = ball.x - closestX
      local dy = ball.y - closestY
      local dist2 = dx*dx + dy*dy
      if dist2 < (ball.r * ball.r) then
        local d = math.sqrt(dist2)
        local overlap = ball.r - (d == 0 and 0.0001 or d)
        -- normal from rect to ball
        local nx = dx / (d == 0 and 1 or d)
        local ny = dy / (d == 0 and 1 or d)
        -- push ball out
        ball.x = ball.x + nx * overlap
        ball.y = ball.y + ny * overlap
        -- reflect velocity along normal with damping
        local vdotn = ball.vx * nx + ball.vy * ny
        ball.vx = ball.vx - (1.9 * vdotn) * nx
        ball.vy = ball.vy - (1.9 * vdotn) * ny
        -- small damping to avoid sticking
        ball.vx = ball.vx * 0.9
        ball.vy = ball.vy * 0.9
      end
    end

    -- Check for sinking in hole
    if dist(ball.x, ball.y, hole.x, hole.y) <= hole.r then
      sunk = true
      score = score + 1
    end
  end
end

function love.draw()
  -- background
  love.graphics.clear(0.18, 0.6, 0.18)

  -- hole
  love.graphics.setColor(0,0,0)
  love.graphics.circle("fill", hole.x, hole.y, hole.r)

  -- ball
  love.graphics.setColor(1,1,1)
  love.graphics.circle("fill", ball.x, ball.y, ball.r)

  -- aiming line from ball to mouse
  local mx, my = love.mouse.getPosition()
  love.graphics.setColor(1,1,0)
  love.graphics.print("Aim: mouse | Hold SPACE to charge, release to shoot | R to reset", 8, 6)

  if not sunk then
    love.graphics.setColor(1,1,1,0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(ball.x, ball.y, mx, my)
  end

  -- power bar when charging
  -- draw barriers
  for _,r in ipairs(barriers) do
    love.graphics.setColor(0.4,0.2,0.1)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
  end

  -- power bar (always visible)
  local pct = 0
  if power and maxPower and maxPower > 0 then
    pct = math.min(1, power / maxPower)
  end
  local barX, barY, barW, barH = 20, height - 36, 220, 18
  love.graphics.setColor(0,0,0)
  love.graphics.rectangle("line", barX, barY, barW, barH)
  love.graphics.setColor(0.85 * pct + 0.15, 0.15, 0.15)
  love.graphics.rectangle("fill", barX+2, barY+2, (barW-4) * pct, barH-4)
  love.graphics.setColor(1,1,1)
  love.graphics.printf(string.format("Power: %d%%", math.floor(pct*100)), barX, barY-16, barW, "left")

  -- HUD
  love.graphics.setColor(1,1,1)
  local sc = score or 0
  local at = attempts or 0
  love.graphics.print(string.format("Score: %d  Attempts: %d", sc, at), 8, 24)
  if sunk then
    love.graphics.printf("Nice! Ball in the hole. Press R to play again.", 0, height/2 - 10, width, "center")
  end
end

function love.keypressed(key)
  if key == "space" and not charging and not sunk then
    charging = true
    power = 0
  elseif key == "r" then
    -- reset positions
    ball.x = 120; ball.y = height/2; ball.vx = 0; ball.vy = 0
    hole.x = math.random(width/2 + 50, width - 80)
    hole.y = math.random(80, height - 80)
    sunk = false
  end
end

function love.keyreleased(key)
  if key == "space" and charging then
    charging = false
    -- shoot: compute direction from ball to mouse
    local mx, my = love.mouse.getPosition()
    local dx = mx - ball.x
    local dy = my - ball.y
    local mag = math.sqrt(dx*dx + dy*dy)
    if mag < 1e-6 then
      return
    end
    local nx = dx / mag
    local ny = dy / mag
    -- translate charged power into velocity
    local speed = power / 1.0
    ball.vx = nx * speed
    ball.vy = ny * speed
    attempts = attempts + 1
    power = 0
  end
end

-- make sure random is seeded for hole placement
math.randomseed(os.time())
