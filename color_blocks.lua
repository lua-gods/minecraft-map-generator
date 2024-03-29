local shades = {
   {mul = 0.71, offset = -1},
   {mul = 0.86, offset = 0},
   {mul = 1, offset = 1},
}

local blocks = client.getRegistry('block') ---@diagnostic disable-line: undefined-field

-- remove bad blocks
local badBlocks = {
   ['minecraft:gravel'] = true,
   ['minecraft:sand'] = true,
   ['minecraft:red_sand'] = true,
   ['minecraft:dragon_egg'] = true,
   ['minecraft:pointed_dripstone'] = true,
   ['minecraft:suspicious_sand'] = true,
   ['minecraft:suspicious_gravel'] = true,
   ['minecraft:scaffolding'] = true,
   ['minecraft:sponge'] = true,
   ['minecraft:budding_amethyst'] = true,
   ['minecraft:powder_snow'] = true,
}
for i, v in pairs(blocks) do
   if badBlocks[v] or v:match('powder') or v:match('anvil') or v:match('copper') or v:match('coral') then
      blocks[i] = nil
      -- badBlocks[v] = nil
   end
end

-- printTable(badBlocks)

-- sort blocks
local colors = {}

for _, v in pairs(blocks) do
   local block = world.newBlock(v)
   local color = block:getMapColor()
   if color ~= vec(0, 0, 0) then
      local colorId = tostring(color)
      if not colors[colorId] then colors[colorId] = {color = color} end
      table.insert(colors[colorId], {block, v})
   end
end

-- add extra blocks
local function addBlock(block, blockWithTargetColor)
   if not pcall(world.newBlock, block) then return end
   local color = tostring(world.newBlock(blockWithTargetColor or block):getMapColor())
   if colors[color] then
      table.insert(colors[color], {world.newBlock(block), block, true})
   else
      print('block filter:', 'color not found for', block)
   end
end

addBlock('minecraft:oak_leaves[persistent=true,waterlogged=true]', 'minecraft:water')
addBlock('minecraft:oak_leaves[persistent=true]')
addBlock('minecraft:redstone_block')

-- filter colors
local blockColors = {}

local function findBestBlock(tbl)
   for _, block in ipairs(tbl) do
      if block[3] then
         return {block[2], -1, tbl}
      end
   end
   for _, block in ipairs(tbl) do
      if block[1]:isFullCube() and block[1]:isOpaque() and block[1]:isSolidBlock() then
         return {block[2], 0, tbl}
      end
   end
   for _, block in ipairs(tbl) do
      if (block[1]:isFullCube() and block[1]:isSolidBlock()) or (block[1]:isFullCube() and block[1]:isOpaque()) or (block[1]:isSolidBlock() and block[1]:isOpaque()) then
         return {block[2], 1, tbl}
      end
   end
   for _, block in ipairs(tbl) do
      if block[1]:isSolidBlock() or block[1]:isOpaque() or block[1]:isFullCube() then
         return {block[2], 2, tbl}
      end
   end
   return {tbl[1][2], 3, tbl}
end

for _, v in pairs(colors) do
   table.insert(blockColors, findBestBlock(v))
end


local flatList, staircaseList = {}, {}

for _, v in pairs(blockColors) do
   if v[2] > 0 then
      print('block filter: no good blocks found', v[1]:match('^[^:]+:(.+)'), v[2], v[3])
   else
      table.insert(flatList, {v[3].color, v[1], 0})
      for _, shade in pairs(shades) do
         table.insert(staircaseList, {v[3].color * shade.mul, v[1], shade.offset})
      end
   end
end

return flatList, staircaseList