-- uvlookup_patches.lua
-- Patch-based UV lookup for Aseprite
-- Adapted to collect UV/color lookups per "patch" (mask) so textures can be applied reliably

function init(plugin)
	print("Aseprite is initializing uvlookup_patches plugin")
  
	if plugin.preferences.uvPatchData == nil then
	  plugin.preferences.uvPatchData = {}
	end
  
	-- In-memory tables (not persisted except plugin.preferences if you want)
	uvColorsByPatch = plugin.preferences.uvPatchData -- reuse preferences so it can persist between runs
  
	function tableClear(t)
	  for k in pairs(t) do t[k] = nil end
	end
  
	-- Helpers
	local function findSpriteByPath(spritePath)
	  for i, spr in ipairs(app.sprites) do
		if spr.filename == spritePath then return spr end
	  end
	  return nil
	end
  
	-- UI dialog
	function uvlookup()
	  local dialog = Dialog { title = "UV lookup - patches" }
  
	  local lookupDirection = "Horizontal"
  
	  dialog:entry { id = "uv_patch_name_id", label = "Patch name:", text = "torso" }
  
	  dialog:combobox {
		id = "uv_lookup_direction_id",
		label = "Lookup direction:",
		options = {"Horizontal", "Vertical"},
		onchange = function() lookupDirection = dialog.data.uv_lookup_direction_id end
	  }
  
	  dialog:button {
		id = "uv_make_lookup_button_id",
		text = "Make lookup (from active sprite)",
		onclick = function()
		  local patchName = dialog.data.uv_patch_name_id
		  if not patchName or #patchName == 0 then app.alert("Set a patch name first") return end
  
		  local sprite = app.activeSprite
		  local cel = app.activeCel
		  local layer = app.activeLayer
  
		  if not sprite or not cel or not layer then app.alert("Open the lookup sprite, select the mask layer and a cel/frame") return end
  
		  local image = cel.image
		  if not image then app.alert("Active cel has no image") return end
  
		  -- Build patch color list from the *active* image under its active mask layer.
		  -- We only read colors from the image; we DO NOT modify the image.
		  local patchColors = {}
  
		  for y = 0, image.height - 1 do
			for x = 0, image.width - 1 do
			  local maskPixel = image:getPixel(x, y)
			  if app.pixelColor.rgbaA(maskPixel) > 0 then
				-- For lookup we store the actual color at this pixel (not a UV-encoded color)
				local pixelValue = image:getPixel(x, y)
				table.insert(patchColors, pixelValue)
			  end
			end
		  end
  
		  if #patchColors == 0 then app.alert("No opaque pixels found in active cel / layer") return end
  
		  uvColorsByPatch[patchName] = patchColors
		  plugin.preferences.uvPatchData = uvColorsByPatch
		  app.alert("Lookup stored for patch: " .. patchName .. " (" .. #patchColors .. " pixels)")
		end
	  }
  
	  dialog:button {
		id = "uv_make_source_button_id",
		text = "Make source (apply to active sprite)",
		onclick = function()
		  local patchName = dialog.data.uv_patch_name_id
		  if not patchName or #patchName == 0 then app.alert("Set a patch name first") return end
  
		  local patchColors = uvColorsByPatch[patchName]
		  if not patchColors then app.alert("No lookup stored for patch: " .. patchName) return end
  
		  local sprite = app.activeSprite
		  local cel = app.activeCel
		  local layer = app.activeLayer
  
		  if not sprite or not cel or not layer then app.alert("Open the target sprite, select the mask layer and a cel/frame") return end
  
		  local image = cel.image
		  if not image then app.alert("Active cel has no image") return end
  
		  local colorIndex = 1
		  local total = #patchColors
  
		  if lookupDirection == "Vertical" then
			for y = 0, image.height - 1 do
			  for x = 0, image.width - 1 do
				local maskPixel = image:getPixel(x, y)
				if app.pixelColor.rgbaA(maskPixel) > 0 then
				  -- apply only if patch has colors left
				  local uvColor = patchColors[colorIndex]
				  if not uvColor then break end
				  local r = app.pixelColor.rgbaR(uvColor)
				  local g = app.pixelColor.rgbaG(uvColor)
				  local b = app.pixelColor.rgbaB(uvColor)
				  local a = app.pixelColor.rgbaA(uvColor)
  
				  image:putPixel(x, y, app.pixelColor.rgba(r, g, b, a))
				  colorIndex = colorIndex + 1
				end
			  end
			end
		  else -- Horizontal (default)
			for x = 0, image.width - 1 do
			  for y = 0, image.height - 1 do
				local maskPixel = image:getPixel(x, y)
				if app.pixelColor.rgbaA(maskPixel) > 0 then
				  local uvColor = patchColors[colorIndex]
				  if not uvColor then break end
				  local r = app.pixelColor.rgbaR(uvColor)
				  local g = app.pixelColor.rgbaG(uvColor)
				  local b = app.pixelColor.rgbaB(uvColor)
				  local a = app.pixelColor.rgbaA(uvColor)
  
				  image:putPixel(x, y, app.pixelColor.rgba(r, g, b, a))
				  colorIndex = colorIndex + 1
				end
			  end
			end
		  end
  
		  app.refresh()
		  app.alert("Applied patch '" .. patchName .. "' (used " .. math.min(colorIndex-1, total) .. " / " .. total .. " pixels)")
		end
	  }
  
	  dialog:button {
		id = "uv_clear_patch_id",
		text = "Clear stored patch",
		onclick = function()
		  local patchName = dialog.data.uv_patch_name_id
		  if uvColorsByPatch[patchName] then
			uvColorsByPatch[patchName] = nil
			plugin.preferences.uvPatchData = uvColorsByPatch
			app.alert("Cleared patch: " .. patchName)
		  else
			app.alert("No stored patch with name: " .. patchName)
		  end
		end
	  }
  
	  dialog:button { id = "uv_show_list_id", text = "List stored patches", onclick = function()
		local keys = {}
		for k in pairs(uvColorsByPatch) do table.insert(keys, k) end
		if #keys == 0 then app.alert("No patches stored") else app.alert("Stored patches:\n" .. table.concat(keys, "\n")) end
	  end }
  
	  dialog:show { wait = false }
	end
  
	plugin:newCommand {
	  id = "uvlookup_patches_command_id",
	  title = "UV lookup (patches)",
	  group = "edit_insert",
	  onclick = function()
		uvlookup()
	  end,
	  onenabled = function() return true end
	}
  end
  
  function exit(plugin)
	print("Aseprite is closing uvlookup_patches plugin")
  end
  