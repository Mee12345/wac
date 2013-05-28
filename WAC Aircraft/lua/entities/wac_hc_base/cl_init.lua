
include("shared.lua")


ENT.RenderGroup = RENDERGROUP_BOTH


ENT.thirdPerson = {
	distance = 600,
	angle = 10,
	position = Vector(-50,0,100)
}


ENT.Scale = 1 -- hud scaling and such


function ENT:receiveInput(name, value, seat)
	if name == "FreeView" then
		local player = LocalPlayer()
		if value > 0.5 then
			player.wac.viewFree = true
		else
			player.wac.viewFree = false
			player.wac_air_resetview = true
		end
	elseif name == "Camera" then
		local player = LocalPlayer()
		if value > 0.5 then
			player:GetVehicle().useCamera = !player:GetVehicle().useCamera
		end
	end
end


function ENT:Initialize()
	self:addSounds()
	self.SmoothUp = 0
	self.engineRpm = 0
	self.rotorRpm = 0
	self.Emitter = ParticleEmitter(self:GetPos())
	self.IsOn = false
	self.LastThink = CurTime()

	self.weapons = {}
	self.weaponAttachments = {}
	if self.WeaponAttachments then
		for name, info in pairs(self.WeaponAttachments) do
			if name != "BaseClass" and name != "seat" then
				local t = table.Copy(info)
				t.model = ClientsideModel(info.model, RENDERGROUP_OPAQUE)
				t.model:Spawn()
				t.model:SetPos(self:LocalToWorld(info.pos))
				t.model:SetParent(self)
				self.weaponAttachments[name] = t
			end
		end
	end
	if self.Camera then
		local t = {}
		self.camera = ClientsideModel(self.Camera.model)
		self.camera:SetPos(self:LocalToWorld(self.Camera.pos))
		self.camera:SetParent(self)
		self.camera:Spawn()
		t.info = self.Camera
		t.model = self.camera
		table.insert(self.weaponAttachments, t)
	end
end


function ENT:Think()
	
	if self.skin != self:GetSkin() then
		self.skin = self:GetSkin()
		self:updateSkin(self.skin)
	end

	if !self:GetNWBool("locked") then

		self:attachmentThink()

		local mouseFlight = self:GetNWBool("active")
		if self.sounds.Start then
			if mouseFlight!=self.IsOn then
				if mouseFlight then
					self.sounds.Start:Play()
				else
					self.sounds.Start:Stop()
				end
				self.IsOn=mouseFlight
			end
		end
		if !self.sounds.Engine:IsPlaying() then
			self.sounds.Engine:ChangePitch(0,0.1)
			self.sounds.Engine:Play()
		end
		if !self.sounds.Blades:IsPlaying() then
			self.sounds.Blades:ChangePitch(0,0.1)
			self.sounds.Blades:Play()
		end
		local frt = CurTime()-self.LastThink
		local e = LocalPlayer():GetViewEntity()
		if !IsValid(e) then e = LocalPlayer() end
		local pos = e:GetPos()
		local spos = self:GetPos()
		local doppler = (pos:Distance(spos+e:GetVelocity())-pos:Distance(spos+self:GetVelocity()))/200*self.rotorRpm

		self.SmoothUp = self.SmoothUp - (self.SmoothUp-self:GetNWFloat("up"))*frt*10
		self.rotorRpm = self.rotorRpm - (self.rotorRpm-self:GetNWFloat("rotorRpm"))*frt*10
		self.engineRpm = self.engineRpm - (self.engineRpm-self:GetNWFloat("engineRpm"))*frt*10

		local engineVal = math.Clamp(self.engineRpm*100+self.engineRpm*self.SmoothUp*3+doppler, 0, 200)
		local val = math.Clamp(self.rotorRpm*100 + doppler, 0, 200)

		local vehicle = LocalPlayer():GetVehicle()
		local inVehicle = false
		if 
			IsValid(vehicle)
			and !vehicle:GetThirdPersonMode()
			and vehicle:GetNWEntity("wac_aircraft") == self
		then
			inVehicle = true
		end
		self.sounds.Engine:ChangePitch(engineVal/1.1 + val/10, 0.1)
		self.sounds.Engine:ChangeVolume(math.Clamp(engineVal*engineVal/4000, 0, inVehicle and 1 or 5), 0.1)
		self.sounds.Blades:ChangePitch(math.Clamp(val, 10, 150), 0.1)
		self.sounds.Blades:ChangeVolume(math.Clamp(val*val/5000, 0, inVehicle and 0.4 or 5), 0.1)
		if self.sounds.Start then
			self.sounds.Start:ChangeVolume(math.Clamp(100 - self.engineRpm*110, 0, 100)/100, 0.1)
			self.sounds.Start:ChangePitch(100 - self.engineRpm*20, 0.1)
		end
		self.LastThink=CurTime()
	else
		self.sounds.Engine:Stop()
		self.sounds.Blades:Stop()
		if self.sounds.Start then
			self.sounds.Start:Stop()
		end
	end
end


function ENT:getPassenger(seat)
	if !IsValid(self:GetSwitcher()) then return end
	local s = self:GetSwitcher().seats[seat]
	if IsValid(s) then
		return s:GetPassenger()
	end
end


function ENT:attachmentThink()
	if !self.weaponAttachments then return end
	local camAng
	if !self.camera then return end
	local p = self:getPassenger(self.Camera.seat)
	if IsValid(p) then
		local ang = self:WorldToLocalAngles(p:GetAimVector():Angle())
		ang.r = 0
		if self.Camera.minAng then
			ang.p = (ang.p > self.Camera.minAng.p and ang.p or self.Camera.minAng.p)
			ang.y = (ang.y > self.Camera.minAng.y and ang.y or self.Camera.minAng.y)
		end
		if self.Camera.maxAng then
			ang.p = (ang.p < self.Camera.maxAng.p and ang.p or self.Camera.maxAng.p)
			ang.y = (ang.y < self.Camera.maxAng.y and ang.y or self.Camera.maxAng.y)
		end
		camAng = self:LocalToWorldAngles(ang)
	end

	if !camAng then return end
	local tr = util.QuickTrace(self:LocalToWorld(self.Camera.pos)+camAng:Forward()*20, camAng:Forward()*999999999, self)
	for _, t in pairs(self.weaponAttachments) do
		local localAng = self:WorldToLocalAngles((tr.HitPos - t.model:GetPos()):Angle())
		localAng = Angle(t.restrictPitch and 0 or localAng.p, t.restrictYaw and 0 or localAng.y, t.roll or 0)
		t.model:SetAngles(self:LocalToWorldAngles(localAng))
		if t.offset then
			t.model:SetPos(self:LocalToWorld(t.pos) + t.model:LocalToWorld(t.offset) - t.model:GetPos())
		end
	end
end


function ENT:OnRemove()
	for _,s in pairs(self.sounds) do
		s:Stop()
	end
	for _, t in pairs(self.weaponAttachments) do
		t.model:Remove()
	end
end



function ENT:DrawHUD(k,p)
	if !self.Seats or !self.Seats[k] or p:GetViewEntity()!=p then return end
	if p:GetVehicle().useCamera and self.camera and !p:GetVehicle():GetThirdPersonMode() then
		self:drawCameraHUD(self.Camera.seat)
	end
end


function ENT:drawCameraHUD(seat)

	local sw = ScrW()
	local sh = ScrH()
	
	local w = sh/6
	local s = sh/3
	
	surface.SetDrawColor(255,255,255,150)
	
	surface.DrawLine(sw/2-s, sh/2-s, sw/2-s+w, sh/2-s)
	surface.DrawLine(sw/2-s, sh/2-s, sw/2-s, sh/2-s+w)
	
	surface.DrawLine(sw/2+s, sh/2-s, sw/2+s-w, sh/2-s)
	surface.DrawLine(sw/2+s, sh/2-s, sw/2+s, sh/2-s+w)
	
	surface.DrawLine(sw/2-s, sh/2+s, sw/2-s+w, sh/2+s)
	surface.DrawLine(sw/2-s, sh/2+s, sw/2-s, sh/2+s-w)
	
	surface.DrawLine(sw/2+s, sh/2+s, sw/2+s-w, sh/2+s)
	surface.DrawLine(sw/2+s, sh/2+s, sw/2+s, sh/2+s-w)
	
	local weapon = self.weapons[self.Seats[seat].weapons[self:GetNWInt("seat_" .. seat .. "_actwep")]]
	if IsValid(weapon) and weapon.drawCrosshair then
		weapon:drawCrosshair()
	end

	local count=0
	for i, name in pairs(self.Seats[seat].weapons) do
		if i != "BaseClass" then
			count = count+1
			if i == self:GetNWInt("seat_"..seat.."_actwep") then
				surface.SetDrawColor(10,10,10,150)
				surface.DrawRect(sw/2+w*2,sh/7+count*50,w*2+10,50)
			end
		end
	end
	surface.SetDrawColor(10,10,10,100)
	surface.DrawRect(sw/2+w*2,sh/7+50,w*2+10,count*50)
	surface.SetDrawColor(255,255,255,200)
	surface.DrawOutlinedRect(sw/2+w*2,sh/7+50,w*2+10,count*50)
	surface.SetFont("wac_heli_small")
	surface.SetTextColor(230,230,230,255)
	local h = 1
	for i, name in pairs(self.Seats[seat].weapons) do
		if i != "BaseClass" then
			local wep = self.weapons[name]
			local ammo = wep:GetAmmo()
			surface.SetTextPos(sw/2+w*2+5,sh/7+5+h*50)
			surface.DrawText(name)
			surface.SetTextPos(sw/2+w*4+5-string.len(ammo)*14,sh/7+5+h*50)
			surface.DrawText(ammo)
			surface.SetDrawColor(255,255,255,200)
			local lastshot = wep:GetLastShot()
			local nextshot = wep:GetNextShot()
			surface.DrawRect(sw/2+w*2,sh/7+h*50+40,(w*2+10)*math.Clamp((nextshot-CurTime())/(nextshot-lastshot),0,1),10)
			h=h+1
		end
	end
end


function ENT:DrawScreenSpaceEffects(k,p)
	if !self.Seats or !self.Seats[k] or p:GetViewEntity()!=p then return end
	if p:GetVehicle().useCamera and self.camera and !p:GetVehicle():GetThirdPersonMode() then
		self:renderCameraEffects(self.WeaponAttachments.seat)
	end
end


local blurMaterial = Material("pp/blurscreen")

function ENT:renderCameraEffects(seat)
	local crt = CurTime()
	if !self.flickerNext or crt > self.flickerNext then
		self.flicker = math.random(1,8)==1 and 2 or 0
		self.flickerNext = crt+0.1
	end
	blurMaterial:SetFloat("$blur", 1+self.flicker)
	render.UpdateScreenEffectTexture()
	render.SetMaterial(blurMaterial)
	render.DrawScreenQuad()
	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = 0,
		["$pp_colour_contrast" ] = 1,
		["$pp_colour_colour" ] = 0.01,
		["$pp_colour_mulr" ] = 0,
		["$pp_colour_mulg" ] = 0,
		["$pp_colour_mulb" ] = 0,
	})
end


function ENT:onViewSwitch(p, thirdPerson)
	self.viewPos = nil
end


function ENT:onEnter(p)
	p.wac.lagAngles =  self:GetAngles()
	p.wac.lagPos = self:GetPos()
	p.wac.lagSpeed = Vector(0, 0, 0)
	p.wac.lagAccel = Vector(0, 0, 0)
	p.wac.lagAccelDelta = Vector(0, 0, 0)
	p.wac.air.vehicle = self
end


function ENT:viewCalcThirdPerson(k, p, view)
	local ang;
	if
			k == 1
			and p:GetInfo("wac_cl_air_mouse") == "1"
			and !p.wac.viewFree
	then
		ang = self:GetAngles()
	else
		ang = p:GetAimVector():Angle()
		ang.r = view.angles.r
	end
	ang:RotateAroundAxis(ang:Right(), -self.thirdPerson.angle)
	local origin = self:LocalToWorld(self.thirdPerson.position)
	local tr = util.QuickTrace(
			origin,
			ang:Forward()*-self.thirdPerson.distance,
			{self.Entity, self:GetNWEntity("wac_air_rotor_rear"), self:GetNWEntity("wac_air_rotor_main")}
	)
	self.viewTarget = {
		origin = (tr.HitPos - tr.Normal*10) - view.origin,
		angles = ang - self:GetAngles()
	}
	return view
end


function ENT:viewCalcFirstPerson(k, p, view)
	p.wac = p.wac or {}
	view.origin = self:LocalToWorld(Vector(0,0,34.15)*self.Scale+self.Seats[k].pos)
	if
		k == 1
		and p:GetInfo("wac_cl_air_mouse") == "1"
		and !p.wac.viewFree
	then
		self.viewTarget = {
			origin = Vector(0,0,0),
			angles = Angle(0,0,0),
			fov = view.fov
		}
	else
		self.viewTarget = {
			origin = Vector(0,0,0),
			angles = p:GetAimVector():Angle() - self:GetAngles(),
			fov = view.fov
		}
		self.viewTarget.angles.r = self.viewTarget.angles.r + self:GetAngles().r
	end
	return view
end


function ENT:viewCalcExit(p, view)
	p.wac.air.vehicle = nil
end


function ENT:viewCalc(k, p, pos, ang, fov)
	if !self.Seats[k] then return end
	local view = {origin = pos, angles = ang, fov = fov}

	if p:GetVehicle():GetNWEntity("wac_aircraft") != self then
		return self:viewCalcExit(p, view)
	end

	wac.smoothApproachAngles(p.wac.lagAngles, self:GetAngles(), 20)
	local shakeEnabled = p:GetInfo("wac_cl_air_shakeview") == "1"
	if shakeEnabled then
		wac.smoothApproachVector(p.wac.lagPos, self:GetPos(), 20)
		wac.smoothApproachVector(p.wac.lagSpeed, p.wac.lagPos-self:GetPos(), 20)
		wac.smoothApproachVector(p.wac.lagAccel, p.wac.lagSpeed, 20)
		wac.smoothApproachVector(p.wac.lagAccelDelta, p.wac.lagAccel, 20)
	end

	if p:GetVehicle():GetThirdPersonMode() then
		view = self:viewCalcThirdPerson(k, p, view)
	else
		if p:GetVehicle().useCamera and self.camera then
			--view = weapon.CalcView(self,weapon,p,pos,ang,view)
			view.origin = self.camera:LocalToWorld(self.Camera.viewPos)
			view.angles = self.camera:GetAngles()
			if self.viewTarget then
				self.viewTarget.angles = p:GetAimVector():Angle() - self:GetAngles()
			end
			self.viewPos = nil
			p.wac.lagAngles = Angle(0, 0, 0)
			p.wac.lagAccel = Vector(0, 0, 0)
			p.wac.lagAccelDelta = Vector(0, 0, 0)
		else
			view = self:viewCalcFirstPerson(k, p, view)
		end
	end
	if self.viewTarget then
		self.viewPos = self.viewPos or table.Copy(self.viewTarget)
		wac.smoothApproachVector(self.viewPos.origin, self.viewTarget.origin, 30)
		wac.smoothApproachAngles(self.viewPos.angles, self.viewTarget.angles, 30)
		view.origin = view.origin + self.viewPos.origin
		if p:GetInfo("wac_cl_air_smoothview") == "1" then
			view.angles = self:GetAngles()*2 + self.viewPos.angles - p.wac.lagAngles
			if shakeEnabled then
				view.origin = view.origin + (p.wac.lagAccel - p.wac.lagAccelDelta)/7*self.Scale
			end
		else
			view.angles = self:GetAngles() + self.viewPos.angles
		end
		self.viewTarget = nil
	end
	return view
end


function ENT:MovePlayerView(k,p,md)
	if p.wac_air_resetview then md:SetViewAngles(Angle(0,90,0)) p.wac_air_resetview=false end
	local freeView = md:GetViewAngles()
	local id = self:GetNWInt("seat_"..k.."_actwep")
	if !self.Seats or !self.Seats[k] then return end
	if (k==1 and p:GetInfo("wac_cl_air_mouse")=="1" and !p.wac.viewFree) then
		freeView.p = freeView.p-freeView.p*FrameTime()*6
		freeView.y = freeView.y-(freeView.y-90)*FrameTime()*6
	else
		freeView.p = math.Clamp(freeView.p,-90,90)
	end
	freeView.y = (freeView.y<-90 and -180 or (freeView.y<0 and 0 or freeView.y))
	md:SetViewAngles(freeView)
end


local HudMat = Material("WeltEnSTurm/helihud/arrow")
local HudCol = Color(70,199,50,150)
local Black = Color(0,0,0,200)
function ENT:DrawPilotHud()
	local pos = self:GetPos()
	local fwd = self:GetForward()
	local ri = self:GetRight()
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ri, 90)
	ang:RotateAroundAxis(fwd, 90)
	
	local uptm = self.rotorRpm
	local upm = self.SmoothUp
	cam.Start3D2D(self:LocalToWorld(Vector(20,3.75,37.75)*self.Scale+self.Seats[1].pos), ang, 0.015*self.Scale)
	surface.SetDrawColor(HudCol)
	surface.DrawRect(235, 249, 10, 2)
	surface.DrawRect(255, 249, 10, 2)
	surface.DrawRect(249, 235, 2, 10)
	surface.DrawRect(249, 255, 2, 10)
	surface.DrawRect(-3, 0, 3, 500)
	surface.DrawRect(500, 0, 3, 500)
	surface.DrawRect(7, 0, 3, 500)
	surface.DrawRect(490, 0, 3, 500)
	
	surface.DrawRect(-6,-3,19,3)
	surface.DrawRect(-6,500,19,3)
	surface.DrawRect(487,-3,19,3)
	surface.DrawRect(487,500,19,3)
	surface.DrawRect(9,248,5,3)
	surface.DrawRect(485,248,5,3)
	
	surface.DrawRect(1, 500-uptm*500, 5, uptm*500)
	surface.DrawLine(30, 5*ang.r-200+2.77*ang.p, 220, 5*ang.r-200+2.77*(ang.p*0.12))
	surface.DrawLine(30, 5*ang.r-200+2.77*ang.p+1, 220, 5*ang.r-200+2.77*(ang.p*0.12)+1)
	surface.DrawLine(280, 5*ang.r-200-2.77*(ang.p*0.12), 470, 5*ang.r-200-2.77*ang.p)
	surface.DrawLine(280, 5*ang.r-200-2.77*(ang.p*0.12)+1, 470, 5*ang.r-200-2.77*ang.p+1)
	surface.SetMaterial(HudMat)
	surface.DrawTexturedRect(-20,250-upm*250-10,20,20)
	surface.DrawTexturedRectRotated(498,math.Clamp(250-self:GetVelocity().z/5.249*2,0,500),20,20,180)
	surface.SetTextColor(HudCol)
	surface.SetFont("wac_heli_small")
	surface.SetTextPos(-10, 505) 
	surface.DrawText("SPD")
	surface.SetTextPos(-10, 520)
	surface.DrawText(math.floor(self:GetVelocity():Length()*0.1)) --knots (real would be 0.037147, but fuck it)
	
	if self:GetHover() then
		surface.SetTextColor(HudCol)
		surface.SetFont("wac_heli_small")
		surface.SetTextPos(483, -18)
		surface.DrawText("HVR")
	end
	
	local tr=util.QuickTrace(pos,Vector(0,0,-999999),self.Entity)
	surface.SetTextPos(485,505)
	surface.DrawText("ALT")
	surface.SetTextPos(485,520)
	surface.DrawText(math.floor((pos.z-tr.HitPos.z)/16))

	cam.End3D2D()
end

function ENT:DrawWeaponSelection()
	local fwd = self:GetForward()
	local ri = self:GetRight()
	local ang = self:GetAngles()
	ang:RotateAroundAxis(ri, 90)
	ang:RotateAroundAxis(fwd, 90)
	for k,t in pairs(self.Seats) do
		if k != "BaseClass" and t.weapons then
			cam.Start3D2D(self:LocalToWorld(Vector(20,5,25)*self.Scale + t.pos), ang, 0.02*self.Scale)
			surface.DrawRect(-10, 0, 500, 30)
			surface.DrawRect(-10, 30, 10, 20)
			if t.weapons then
				local active = self:GetNWInt("seat_"..k.."_actwep")
				if t.weapons[active] then
					local weapon = self.weapons[t.weapons[active]]
					local lastshot = weapon:GetLastShot()
					local nextshot = weapon:GetNextShot()
					local ammo = weapon:GetAmmo()
					surface.DrawRect(10, 40, math.Clamp((nextshot-CurTime())/(nextshot-lastshot), 0, 1)*480, 10)
					draw.SimpleText(k.." "..t.weapons[active], "wac_heli_big", 0, -2.5, Black, 0)
					draw.SimpleText(ammo, "wac_heli_big", 480, -2.5, Black, 2)
				end
			else
				draw.SimpleText(k, "wac_heli_big", 0, -2.5, Black, 0)
			end
			cam.End3D2D()
		end
	end
end

function ENT:Draw()
	self:DrawModel()
	if !self.Seats or self:GetNWBool("locked") then return end
	self:DrawPilotHud()
	self:DrawWeaponSelection()
	if self.engineRpm > 0.2 and self.SmokePos then
		if !self.lastHeatDrawn or self.lastHeatDrawn < CurTime()-0.1 then
			if type(self.SmokePos) == "table" then
				for _, v in self.SmokePos do
					local particle = self.Emitter:Add("sprites/heatwave",self:LocalToWorld(v))
					particle:SetVelocity(self:GetVelocity()+self:GetForward()*-100)
					particle:SetDieTime(0.1)
					particle:SetStartAlpha(255)
					particle:SetEndAlpha(255)
					particle:SetStartSize(40*self.Scale)
					particle:SetEndSize(20*self.Scale)
					particle:SetColor(255,255,255)
					particle:SetRoll(math.Rand(-50,50))
					self.Emitter:Finish()
				end
			else
				local particle = self.Emitter:Add("sprites/heatwave",self:LocalToWorld(self.SmokePos))
				particle:SetVelocity(self:GetVelocity()+self:GetForward()*-100)
				particle:SetDieTime(0.1)
				particle:SetStartAlpha(255)
				particle:SetEndAlpha(255)
				particle:SetStartSize(40*self.Scale)
				particle:SetEndSize(20*self.Scale)
				particle:SetColor(255,255,255)
				particle:SetRoll(math.Rand(-50,50))
				self.Emitter:Finish()
			end
			self.lastHeatDrawn = CurTime()
		end
	end
end


net.Receive("wac.aircraft.updateWeapons", function(length)
	local aircraft = net.ReadEntity()
	local count = net.ReadInt(8)
	for i = 1, count do
		local name = net.ReadString()
		local weapon = net.ReadEntity()
		aircraft.weapons[name] = weapon
		for index, value in pairs(aircraft.Weapons[name].info) do
			weapon[index] = value
		end
		if weapon.clientUpdate then
			weapon:clientUpdate()
		end
	end
end)

