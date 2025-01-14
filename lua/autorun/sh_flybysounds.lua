local cv_minspeed = CreateConVar("sv_flybysound_minspeed", 100, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Minimum speed required for sound to be heard.")
local cv_maxspeed = CreateConVar("sv_flybysound_maxspeed", 1000, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Volume does not increase after this speed is exceeded.")

local cv_minshapevolume = CreateConVar("sv_flybysound_minshapevolume", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Pitch does not increase when volume (area) falls below this amount.")
local cv_maxshapevolume = CreateConVar("sv_flybysound_maxshapevolume", 300, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Pitch does not decrease when volume (area) exceeds this amount.")

local cv_minvol = CreateConVar("sv_flybysound_minvol", 30, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Object must have at least this much volume (area) to produce fly by sounds.")

local cv_playerSounds = CreateConVar("sv_flybysound_playersounds", 0, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Script applies to players.")

local cv_spinSounds = CreateConVar("sv_flybysound_spinsounds", 0, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "If set to 1, the sound will be heard when an entity is spinning.")

concommand.Add("sv_flybysound_resetconvars", function(ply)
	cv_minspeed:Revert()
	cv_maxspeed:Revert()
	cv_minshapevolume:Revert()
	cv_maxshapevolume:Revert()
	cv_minvol:Revert()
	cv_playerSounds:Revert()
	cv_spinSounds:Revert()
end)

FlyBySound_validClasses = {
	"prop_physics",
	"prop_physics_override",
	"prop_physics_multiplayer",
	"prop_ragdoll",

	"prop_vehicle_jeep",
	"prop_vehicle_airboat",
	"prop_vehicle_prisoner_pod",

	"npc_rollermine",
	"sent_ball",
	"player",

	"gmod_wheel",
}

local function isValidClass(ent)
	for _, class in ipairs(FlyBySound_validClasses) do
		if ent:GetClass() == class then
			return true
		end
	end

	return false
end

-- Properties for Sandbox (hold C and right click on an entity)
properties.Add("flybysounds_on", {
	MenuLabel = "Enable Fly By Sounds",
	Order = 3200,
	MenuIcon = "icon16/sound.png",

	Filter = function(self, ent, ply)
		if (!IsValid(ent)) then return false end
		if (ent:IsPlayer()) then return false end
		if (!isValidClass(ent)) then return false end

		return ent:GetNW2Bool("flyBySoundsDisabled", false)
	end,

	Action = function (self, ent)
		self:MsgStart()
			net.WriteEntity(ent)
		self:MsgEnd()
	end,

	Receive = function (self, length, ply)
		local ent = net.ReadEntity()

		ent:SetNW2Bool("flyBySoundsDisabled", false)
	end
})

properties.Add("flybysounds_off", {
  MenuLabel = "Disable Fly By Sounds",
  Order = 3201,
  MenuIcon = "icon16/sound_mute.png",

  Filter = function(self, ent, ply)
    if (!IsValid(ent)) then return false end
    if (ent:IsPlayer()) then return false end
		if (!isValidClass(ent)) then return false end

    return !ent:GetNW2Bool("flyBySoundsDisabled", false)
  end,

  Action = function (self, ent)
    self:MsgStart()
      net.WriteEntity(ent)
    self:MsgEnd()
  end,

  Receive = function (self, length, ply)
    local ent = net.ReadEntity()

    ent:SetNW2Bool("flyBySoundsDisabled", true)
  end
})
