local minspeed, maxspeed, minshapevolume, maxshapevolume, minvol, cutoffDist, scanDelay, updateDelay, spinSounds, playerSounds, windSound, debugMode, loudness



local function isValidSound(soundObj)
  return soundObj and isfunction(soundObj.Stop)
end

local function debugPrint(...)
  if not debugMode then return end

  print('[FlyBySounds]', ...)
end

local relevantEntities = {}

CreateClientConVar("cl_flybysound_scandelay", 0.5, true, false, "How often the script scans for relevant entities. Smaller values give faster feedback but are more CPU intensive.", 0.0, 1.0)
CreateClientConVar("cl_flybysound_updatedelay", 0.05, true, false, "How often the script updates sound effects (pitch, volume). Smaller values give smoother sound transitions but more CPU intensive.", 0.0, 0.3)
CreateClientConVar("cl_flybysound_cutoffdist", 3000, true, false, "Maximum distance at which sounds can be heard. Smaller values can give better performance in large maps.", 0, 10000)
CreateClientConVar("cl_flybysound_altsound", 0, true, false, "If set to 1 then an alternative wind sound will play. (Portal 2)")
CreateClientConVar("cl_flybysound_debug", 0, true, false, "If set to 1 then debug messages will be displayed.")
CreateClientConVar("cl_flybysound_loudness", 1.0, true, false, "Scales the audio volume of the sounds.")

cv_minspeed        = GetConVar("sv_flybysound_minspeed")
cv_maxspeed        = GetConVar("sv_flybysound_maxspeed")
cv_minshapevolume  = GetConVar("sv_flybysound_minshapevolume")
cv_maxshapevolume  = GetConVar("sv_flybysound_maxshapevolume")
cv_minvol          = GetConVar("sv_flybysound_minvol")
cv_cutoffDist      = GetConVar("cl_flybysound_cutoffdist")
cv_scanDelay       = GetConVar("cl_flybysound_scandelay")
cv_updateDelay     = GetConVar("cl_flybysound_updatedelay")
cv_playerSounds    = GetConVar("sv_flybysound_playersounds")
cv_spinSounds      = GetConVar("sv_flybysound_spinsounds")
cv_windSound       = GetConVar("cl_flybysound_altsound")
cv_debug           = GetConVar('cl_flybysound_debug')
cv_loudness        = GetConVar('cl_flybysound_loudness')


concommand.Add("cl_flybysound_resetconvars", function()
  cv_scanDelay:Revert()
  cv_updateDelay:Revert()
  cv_cutoffDist:Revert()
  cv_windSound:Revert()
  cv_debug:Revert()
  cv_loudness:Revert()
end)

local function updateCVars()
  minspeed        = cv_minspeed:GetInt()
  maxspeed        = cv_maxspeed:GetInt()
  minshapevolume  = cv_minshapevolume:GetInt()
  maxshapevolume  = cv_maxshapevolume:GetInt()
  minvol          = cv_minvol:GetInt()
  cutoffDist      = cv_cutoffDist:GetInt()
  scanDelay       = cv_scanDelay:GetFloat()
  updateDelay     = cv_updateDelay:GetFloat()
  playerSounds    = cv_playerSounds:GetBool()
  spinSounds      = cv_spinSounds:GetBool()
  debugMode       = cv_debug:GetBool()
  loudness        = cv_loudness:GetFloat()

  windSound = "pink/flybysounds/fast_windloop1-louder.wav"
  if cv_windSound:GetBool() == true then
    windSound = "pink/flybysounds/portal2_wind.wav"
  end
end

updateCVars()

cvars.RemoveChangeCallback("cl_flybysound_altsound", "flybysounds_altsound_callback")

cvars.AddChangeCallback("cl_flybysound_altsound", function(convar, oldVal, newVal)
  updateCVars()

  for _, entity in ipairs(relevantEntities) do
    if not isValidSound(entity.FlyBySound) then continue end

    entity.FlyBySound:Stop()
    entity.FlyBySoundPlaying = false
    entity.FlyBySound = CreateSound(entity, windSound)
  end

end, "flybysounds_altsound_callback")


local function isEntityRelevant(ent)
  if not IsValid(ent) then return false end

  if ent:GetNW2Bool("flyBySoundsDisabled", false) then return false end

  if cutoffDist > 0 and EyePos():DistToSqr(ent:GetPos()) > cutoffDist * cutoffDist then return false end

  if ent:IsPlayer() then
    if ent:GetMoveType() == MOVETYPE_NOCLIP or not playerSounds or not ent:Alive() then return false end
  end

  if ent:WaterLevel() > 1 then return false end

  if LocalPlayer():GetVehicle() == ent then return false end

  return true
end

local function averageSpeed(ent)
  local vel = ent:GetVelocity()

  local angVel = 1.0
  if spinSounds then angVel = ent.FlyBySoundAngVel or 0.0 end

  local averageSpeed = (math.abs(vel.y) + math.abs(vel.x) + math.abs(vel.z)) / 3

  return math.Round(averageSpeed + angVel)
end

local function guessScale(ent)
  if not IsValid(ent) then return 0 end
  if ent:IsPlayer() then return 125 end
  local min, max = ent:GetCollisionBounds()

  if not min then min = 0 end
  if not max then max = 0 end

  local vecDiff = min - max
  local scaled = vecDiff * ent:GetModelScale()
  return math.Round((math.abs(scaled.x) + math.abs(scaled.y) + math.abs(scaled.z)) / 3)
end

local function scanForRelevantEntities()
  relevantEntities = {}

  for _, vClass in ipairs(FlyBySound_validClasses) do
    for _, ent in ipairs(ents.FindByClass(vClass)) do
      if ent == LocalPlayer() then continue end
      if isEntityRelevant(ent) then
        table.insert(relevantEntities, ent)
      elseif isValidSound(ent.FlyBySound) and ent.FlyBySound:IsPlaying() then
        ent.FlyBySound:Stop()
        ent.FlyBySoundPlaying = false
      end
    end
  end
end



local function updateSound(entity)
  if not IsValid(entity) then return end

  local shapevolume = guessScale(entity)
  if shapevolume < minvol then return end

  -- Calculate cheap angular velocity length
  if spinSounds then
    local entAngles = entity:GetAngles()

    if entity.FlyBySoundLastAng then
      local angDiff = entAngles - entity.FlyBySoundLastAng

      angDiff.x = (angDiff.x + 180) % 360 - 180
      angDiff.y = (angDiff.y + 180) % 360 - 180
      angDiff.z = (angDiff.z + 180) % 360 - 180

      local angDiffLength = (math.abs(angDiff.x) + math.abs(angDiff.y) + math.abs(angDiff.z)) / 3

      entity.FlyBySoundAngVel = angDiffLength * 10
    end

    entity.FlyBySoundLastAng = entAngles
  end

  local speed = averageSpeed(entity)
  if speed <= minspeed then
    if entity.FlyBySoundPlaying then
      entity.FlyBySoundPlaying = false
      if isValidSound(entity.FlyBySound) then entity.FlyBySound:FadeOut(0.5) end
    end
    return
  end

  if not entity.FlyBySound then
    debugPrint('Creating Sound', entity)
    entity.FlyBySound = CreateSound(entity, windSound)
  end

  local dist = math.Round(EyePos():Distance(entity:GetPos()))
  if entity == LocalPlayer() then dist = maxspeed - speed end
  if dist < 0 then dist = 0 end

  local volume = (math.Clamp(speed, minspeed, maxspeed) - minspeed) / (maxspeed - minspeed)

  volume = volume * loudness

  if entity == LocalPlayer() then volume = volume / 3 end

  local pitch = ((1 - ((math.Clamp(shapevolume, minshapevolume, maxshapevolume) - minshapevolume) / (maxshapevolume - minshapevolume))) * 200) - (dist / 500) * 50
  pitch = math.max(pitch, 10)

  if isValidSound(entity.FlyBySound) then
    if entity.FlyBySoundPlaying then
      entity.FlyBySound:ChangeVolume(volume, 0)
      entity.FlyBySound:ChangePitch(pitch, 0)
    else
      entity.FlyBySoundPlaying = true
      entity.FlyBySound:PlayEx(volume, pitch)
    end
  end
end

local lastScan = 0
local lastUpdate = 0

local function registerThinkHooks()
  -- this can run less often to save CPU time
  hook.Add("Think", "FlyBySound_Scan", function()
    if scanDelay > 0 and CurTime() < lastScan + scanDelay then return end
    lastScan = CurTime()

    updateCVars()
    scanForRelevantEntities()
  end)

  -- this must run more often to create smooth sound transitions
  hook.Add("Think", "FlyBySound_Think", function()
    if updateDelay > 0 and CurTime() < lastUpdate + updateDelay then return end
    lastUpdate = CurTime()

    for _, entity in ipairs(relevantEntities) do
      updateSound(entity)
    end

    if (playerSounds and LocalPlayer():GetMoveType() != MOVETYPE_NOCLIP) then
      updateSound(LocalPlayer())
    elseif isValidSound(LocalPlayer().FlyBySound) and LocalPlayer().FlyBySound:IsPlaying() then
      LocalPlayer().FlyBySound:Stop()
      LocalPlayer().FlyBySoundPlaying = false
    end
  end)

  debugPrint('Think Hooks Addded')
end

-- register the hooks when the map is loaded
hook.Add("InitPostEntity", "FlyBySound_Init", function ()
  registerThinkHooks()
end)

-- re-register for development hot-reloads
registerThinkHooks()

hook.Add("EntityRemoved", "FlyBySound_EntityRemoved", function(ent)
  if isValidSound(ent.FlyBySound) then
    ent.FlyBySound:Stop()
  end
end)

-- Spawnmenu -> Options -> Fly By Sounds
hook.Add("PopulateToolMenu", "FlyBySoundsMenu", function()
	spawnmenu.AddToolMenuOption("Options", "Fly By Sounds", "FlyBySoundsClientMenu", "Client Options", "", "", function(panel)
		panel:ClearControls()
		panel:Help("Fly By Sounds Client Options")
		panel:Help("(All number sliders have an effect on performance!)")

		panel:Help(" ")

		panel:NumSlider("Entity Scan Delay", "cl_flybysound_scandelay", 0.00, 1.00, 2)
		panel:NumSlider("Sound Update Delay", "cl_flybysound_updatedelay", 0.00, 0.300, 2)

		panel:NumSlider("Maximum Audible Distance", "cl_flybysound_cutoffdist", 0, 10000, 1)

    panel:NumSlider("Loudness", "cl_flybysound_loudness", 0.00, 1.00, 2)

		panel:CheckBox("Alternative Sound Effect", "cl_flybysound_altsound")

		panel:Help(" ")

		panel:Button("Reset To Defaults", "cl_flybysound_resetconvars", {})
	end)

	spawnmenu.AddToolMenuOption("Options", "Fly By Sounds", "FlyBySoundsServerMenu", "Server Options", "", "", function(panel)
		panel:ClearControls()
		panel:Help("Fly By Sounds Server Options")

		panel:Help(" ")

		panel:NumSlider("Minimum Speed", "sv_flybysound_minspeed", 0, 2000, 0)
		panel:NumSlider("Maximum Speed", "sv_flybysound_maxspeed", 1, 1000, 0)

		panel:NumSlider("Minimum Shape Size", "sv_flybysound_minshapevolume", 0, 1000, 0)
		panel:NumSlider("Maximum Shape Size", "sv_flybysound_maxshapevolume", 1, 1000, 0)

		panel:Help(" ")

		panel:NumSlider("Minimum Volume", "sv_flybysound_minvol", 1, 100, 2)

		panel:Help(" ")

		panel:CheckBox("Apply to Players", "sv_flybysound_playersounds")
		panel:CheckBox("Spinning Sounds", "sv_flybysound_spinsounds")

		panel:Help(" ")

		panel:Button("Reset To Defaults", "sv_flybysound_resetconvars", {})
	end)
end)
