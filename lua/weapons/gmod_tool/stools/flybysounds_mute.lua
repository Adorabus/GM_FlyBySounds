
TOOL.Category = "Effects"
TOOL.Name = "FlyBySounds Mute"

if CLIENT then
	language.Add("tool.flybysounds_mute.name", "FlyBySounds Mute")
	language.Add("tool.flybysounds_mute.desc", "Prevent certain entities from making fly by sounds.")
	language.Add("tool.flybysounds_mute.0", "Primary: Mute   Secondary: Unmute   Reload: Unmute All Constrained")
end

local function SetEntityMute(ent, mute)
	if (!IsValid(ent) || ent:IsPlayer()) then return false end
	if (CLIENT) then return true end

  ent:SetNW2Bool("flyBySoundsDisabled", mute)

	return true
end

function TOOL:LeftClick(trace)
	return SetEntityMute(trace.Entity, true)
end

function TOOL:RightClick(trace)
  return SetEntityMute(trace.Entity, false)
end

function TOOL:Reload(trace)
  if (!IsValid(trace.Entity) || trace.Entity:IsPlayer()) then return false end
  if (CLIENT) then return true end

  local ents = {}
  local constraints = {}

  duplicator.GetAllConstrainedEntitiesAndConstraints(trace.Entity, ents, constraints)

  for _, ent in pairs(ents) do
    if (IsValid(ent) && !ent:IsPlayer() && ent:GetNW2Bool("flyBySoundsDisabled", false)) then
      ent:SetNW2Bool("flyBySoundsDisabled", false)
    end
  end

  return true
end

function TOOL.BuildCPanel(CPanel)
	CPanel:AddControl("Header", { Description = "FlyBySounds Mute" })
end
