-- block colors
local flatColors, staircaseColors = require('color_blocks')
-- variables
local startHeight = 80
local generated = {}
local currentPixel = -1

local staircase = true
local stairsGroups = {[-1] = {}, [1] = {}}

local dithering = true

local commandSpeed = 20
local commands = {}
local commandData = {}

local tick = 0

local areaPos
local orginal = textures['image']
local preview = textures:newTexture('preview', 128, 128)
-- area model
local areaModel = models:newPart('', 'World'):setVisible(false)
do
   local areaTexture = textures:newTexture('areaTexture', 2, 1)
   areaTexture:setPixel(0, 0, vec(1, 0, 0, 0.5)):setPixel(1, 0, vec(0, 0, 1, 0.5)):update()
   areaModel:newSprite('a'):texture(areaTexture, 16, 16):region(1, 1):setUV(0.5, 0):setPos(16, 0, 0)
   areaModel:newSprite('b'):texture(areaTexture, 16, 16):region(1, 1):setUV(0.5, 0):pos(16, 0, 16)
   areaModel:newSprite('c'):texture(areaTexture, 16, 16):region(1, 1):rot(0, 90, 0):setPos(16, 0, 0)
   areaModel:newSprite('d'):texture(areaTexture, 16, 16):region(1, 1):rot(0, 90, 0):pos(0, 0, 0)
end
-- map preview hud
do
   local hud = models:newPart('', 'Hud')
   hud:newSprite(''):texture(preview, 128, 128)
end
-- functions
local function setMapPos()
   if not player:isLoaded() then return end
   areaPos = ((player:getPos().xz + 64) / 128):floor() * 128 - 64

   local min, max = world.getBuildHeight()
   local offset = -0.5
   areaModel:setPos(areaPos.x_y:add(0, max, 0) * 16 - vec(offset, 0, offset)) ---@diagnostic disable-line: param-type-mismatch
   areaModel:setScale(128 + offset / 8, max - min, 128 + offset / 8)
   areaModel:setVisible(true)
end

local function generateMap()
   currentPixel = 0
   generated = {}
   for x = 1, 128 do
      generated[x] = {x = x - 1, type = 'line'}
   end
end
generateMap()

local function buildMap()
   if not areaPos then return end
   stairsGroups = {[-1] = {}, [1] = {}}
   table.insert(commands, {type = 'command', '/fill '..areaPos.x..' '..startHeight..' '..(areaPos.y - 1)..' '..(areaPos.x + 127)..' '..startHeight..' '..(areaPos.y - 1)..' stone'})
   for _, v in pairs(generated) do
      table.insert(commands, v)
   end
end

-- render
function events.world_render()
   if currentPixel == -1 then return end
   local colors = staircase and staircaseColors or flatColors
   local maxTime = client.getSystemTime() + 10
   while client.getSystemTime() < maxTime and currentPixel < 128 * 128 do
      local x, y = math.floor(currentPixel / 128), currentPixel % 128
      local orginalColor = orginal:getPixel(x, y).xyz
      -- find best color
      local dist = 10
      local best
      for _, v in pairs(colors) do
         local newDist = (v[1] - orginalColor):lengthSquared()
         if newDist < dist then
            dist = newDist
            best = v
         end
      end
      -- dithering
      if dithering and (x + y) % 2 == 0 then
         local dist2 = 10
         local best2
         for _, v in pairs(colors) do
            if v ~= best then
               local newDist = (v[1] - orginalColor):lengthSquared()
               if newDist < dist2 then
                  dist2 = newDist
                  best2 = v
               end
            end
         end
         if (best2[1] - best[1]):length() < 0.1 then
            best = best2
         end
      end
      -- set pixel
      preview:setPixel(x, y,best[1])
      table.insert(generated[x + 1], {best[2], best[3]})
      currentPixel = currentPixel + 1
   end
   preview:update()
   if currentPixel >= 128 * 128 then
      currentPixel = -1
   end
end
-- generate
local commandTypes = {
   line = function(tbl)
      local data = commandData
      data.current = (data.current or 0) + 1
      if data.current > #tbl then return true end
      local blockData = tbl[data.current]
      local block = blockData[1]
      local height = blockData[2]
      data.height = (data.height or startHeight) + blockData[2]
      if height == 0 then -- flat
         local start = data.current - 1
         for _ = data.current, #tbl - 1 do
            local nextBlockData = tbl[data.current + 1]
            if nextBlockData[1] ~= block or nextBlockData[2] ~= 0 then break end
            data.current = data.current + 1
         end
         local x = areaPos.x + tbl.x
         host:sendChatCommand('/fill '..x..' '..data.height..' '..(areaPos.y + start)..' '..x..' '..data.height..' '..(areaPos.y + data.current - 1)..' '..block)
      else -- staircase
         local pos = vec(areaPos.x + tbl.x, data.height, areaPos.y + data.current - 1)
         local len = 1
         local stairs = stairsGroups[height][block]
         -- magic
         for k = data.current + 1, stairs and math.min(#tbl - 1, data.current + stairs.len - 1) or -1 do
            local nextBlockData = tbl[k]
            if nextBlockData[1] ~= block or nextBlockData[2] ~= height then break end
            len = len + 1
         end
         if len == 1 then
            host:sendChatCommand('/setblock '..pos.x..' '..pos.y..' '..pos.z..' '..block)
         else
            local stairStart = stairs.pos
            local stairEnd = stairs.pos + vec(0, height, 1) * (len - 1)
            local pasteHeight = pos.y
            if height == -1 then pasteHeight = pasteHeight - len + 1 end
            host:sendChatCommand('/clone '..stairStart.x..' '..stairStart.y..' '..stairStart.z..' '..stairEnd.x..' '..stairEnd.y..' '..stairEnd.z..' '..pos.x..' '..pasteHeight..' '..pos.z)
         end
         data.current = data.current + len - 1
         data.height = data.height + height * (len - 1)
         -- combine stairs
         if stairs and stairs.pos + vec(0, stairs.len * height, stairs.len) ~= pos then
            if stairs.len == len then stairs.pos = pos end
            return
         end
         stairsGroups[height][block] = {
            pos = stairs and stairs.pos or pos,
            len = (stairs and stairs.len or 0) + len
         }
      end
   end,
   command = function(tbl)
      host:sendChatCommand(tbl[1])
      return true
   end
}
function events.tick()
   -- if not generate or currentPixel ~= -1 then return end
   if #commands == 0 then if A then print((client:getSystemTime() - A) / 1000) A = nil end return end
   tick = (tick + 1) % 20
   local commandCount = math.floor(tick / 20 * commandSpeed) - math.floor((tick - 1) / 20 * commandSpeed)
   for _ = 1, commandCount do
      local finished = commandTypes[commands[1].type](commands[1])
      if finished then
         table.remove(commands, 1)
         commandData = {}
         if #commands == 0 then return end
      end
   end
end
-- ui
local panels = require('panels.main')
local page = panels.newPage('main')
panels.setPage(page)
page:newText():setText('Select area'):onPress(setMapPos)
page:newText():setText('Clear area'):onPress(function()
   if not areaPos then return end
   local min, max = world.getBuildHeight()
   table.insert(commands, {type = 'command', '//pos1 '..table.concat({areaPos.x_y:add(0, min, 0):unpack()}, ',')})
   table.insert(commands, {type = 'command', '//pos2 '..table.concat({areaPos.x_y:add(127, max, 127):unpack()}, ',')})
   table.insert(commands, {type = 'command', '//set air'})
end):setMargin(10)
page:newToggle():setText('Staircase method'):onToggle(function(toggled) staircase = toggled generateMap() end):setToggled(staircase)
page:newToggle():setText('dithering'):onToggle(function(toggled) dithering = toggled generateMap() end):setToggled(dithering):setMargin(10)
page:newSlider():setText('cmd/s'):setRange(1, 1024):setStep(16, 1):setValue(commandSpeed):onScroll(function(value) commandSpeed = value end)
page:newText():setText('generate'):onPress(buildMap)