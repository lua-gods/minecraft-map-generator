-- block colors
local flatColors, staircaseColors = require('color_blocks')
-- variables
local startHeight = 80
local speed = 256
local generated = {}
local height = 0
local currentPixel = -1

local staircase = true

local generate = false
local commandSpeed = 1
local currentCommand = 0

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
   generate = false
   generated = {}
end
generateMap()

local function buildMap()
   if not areaPos or generate then return end
   generate = true
   currentCommand = 0
   if #generated == 0 then
      generateMap()
   end
   host:sendChatCommand('/fill '..areaPos.x..' '..startHeight..' '..(areaPos.y - 1)..' '..(areaPos.x + 127)..' '..startHeight..' '..(areaPos.y - 1)..' stone')
end
-- render
function events.world_render()
   if currentPixel == -1 then return end
   local colors = staircase and staircaseColors or flatColors
   for _ = currentPixel, math.min(currentPixel + speed, 128 * 128 - 1) do
      local x, y = math.floor(currentPixel / 128), currentPixel % 128
      if y == 0 then height = startHeight table.insert(generated, {x = x}) end
      local orginalColor = orginal:getPixel(x, y).xyz
      local dist = 100
      local best
      for _, v in pairs(colors) do
         local newDist = (v[1] - orginalColor):lengthSquared()
         if newDist < dist then
            dist = newDist
            best = v
         end
      end
      preview:setPixel(x, y,best[1])
      height = height + best[3]
      table.insert(generated[#generated], {best[2], height})
      currentPixel = currentPixel + 1
   end
   preview:update()
   if currentPixel >= 128 * 128 then
      currentPixel = -1
   end
end
-- generate
function events.tick()
   if not generate or currentPixel ~= -1 then return end
   if #generated == 0 then print('done') generate = false return end
   tick = (tick + 1) % 20
   local commandCount = math.floor(tick / 20 * commandSpeed) - math.floor((tick - 1) / 20 * commandSpeed)
   for _ = 1, commandCount do
      local commands = generated[1]
      currentCommand = currentCommand + 1
      if currentCommand > #commands then
         table.remove(generated, 1)
         currentCommand = 0
         if #generated == 0 then return end
      else
         local command = commands[currentCommand]
         host:sendChatCommand('/setblock '..(areaPos.x + commands.x)..' '..command[2]..' '..(areaPos.y + currentCommand - 1)..' '..command[1])
      end
   end
end
-- ui
local panels = require('panels.main')
local page = panels.newPage('main')
panels.setPage(page)
page:newText():setText('select area'):onPress(setMapPos)
page:newText():setText('clear area'):onPress(function()
   if not areaPos then return end
   local min, max = world.getBuildHeight()
   host:sendChatCommand('//pos1 '..table.concat({areaPos.x_y:add(0, min, 0):unpack()}, ','))
   host:sendChatCommand('//pos2 '..table.concat({areaPos.x_y:add(127, max, 127):unpack()}, ','))
   host:sendChatCommand('//set air')
end):setMargin(10)
page:newToggle():setText('staircase method'):onToggle(function(toggled) staircase = toggled generateMap() end):setToggled(staircase):setMargin(10)
page:newSlider():setText('command speed'):setRange(1, 1024):setStep(16, 1):setValue(commandSpeed):onScroll(function(value) commandSpeed = value end)
page:newText():setText('generate'):onPress(buildMap)