
function matchTWR {
	parameter expTWR.

	if (shipTWR() > 0) AND (expTWR > 0) {
		return MAX(0, MIN(1, expTWR / shipTWR())).
	} else {
		return 0.
	}
}

function getGravAccConst {
	return 9.80665.
}

function getOrbitalVelocity {
	parameter alt.
	
	return body:radius * sqrt(staticGravity() / (body:radius + alt)).
}

function getObtPeriodAtAlt {
	parameter alt.
	local semimajoraxis is body:radius+alt.
	
	return (constant():PI*2) * sqrt(semimajoraxis^3 / (body:mu)).
}

function getVelocityAtApoapsis {
	return sqrt(((1-obt:eccentricity) * body:mu) / ((1+obt:eccentricity) * obt:semimajoraxis)).
}

function getVelocityAtPeriapsis {
	return sqrt(((1+obt:eccentricity) * body:mu) / ((1-obt:eccentricity) * obt:semimajoraxis)).
}

function getCircularizationDeltaV {
	parameter apo.
	
	return getOrbitalVelocity(apo) - getVelocityAtApoapsis().
}

function nodeBurnTime {
	parameter node.
	return node:deltav:mag / shipAcc().
}

function convAngle {
	parameter angle.
	if angle < 0 {
		set angle to angle + 360.
	}
	return angle.
}
function terrainHeight { //GEOPOSITION:TERRAINHEIGHT doesn't see water
	if SHIP:GEOPOSITION:TERRAINHEIGHT > 0{
		RETURN SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.
	} else {
		RETURN SHIP:ALTITUDE.
	}
}

function atmoHeight {
	if SHIP:BODY:ATM:EXISTS {  //checking atmosphere
		return SHIP:BODY:ATM:HEIGHT.
	} else {
		return 0.
	}	
}

// launch to specific Inclination and LAN
FUNCTION Close360 {
	PARAMETER val1.
	PARAMETER val2.
	PARAMETER closeVal.
	
	SET degDist TO SET180(val1 - val2).
	
	IF ABS(degDist) <= closeVal { RETURN 1. }
	RETURN 0.
}

FUNCTION SET360 {
	PARAMETER val.
	UNTIL val >= 0 { SET val TO val + 360. }
	UNTIL val <= 360 { SET val TO val - 360. }
	RETURN val.
}

FUNCTION SET180 {
	PARAMETER val.
	UNTIL val > -180 { SET val TO val + 360. }
	UNTIL val <= 180 { SET val TO val - 360. }
	RETURN val.
}

FUNCTION updateConsole
{
	CLEARSCREEN.
	PRINT ConsoleReport AT (0, 0).
	
	PRINT "Apoapsis     : " + SHIP:APOAPSIS AT (0, 2).
	PRINT "Periapsis    : " + SHIP:PERIAPSIS AT (0, 3).
	PRINT "OrbitalVel   : " + SQRT(ABS(SHIP:VELOCITY:ORBIT * SHIP:VELOCITY:ORBIT)) AT (0, 4).
	PRINT "Inclination  : " + ORBIT:INCLINATION AT (0, 6).
	PRINT "L. A. N.     : " + ORBIT:LAN AT (0, 7).
}

FUNCTION getLaunchAngleOffset { //how many degrees off from nearest desired orbital insertion
	PARAMETER _Inclination.
	PARAMETER _LAN.
	
	SET AngularPosition TO SET360(ORBIT:LAN + ORBIT:ARGUMENTOFPERIAPSIS + ORBIT:TRUEANOMALY).
	IF (ABS(LATITUDE) < ABS(_Inclination)) {
		SET beta TO getOrbitAngle(_Inclination).
		SET delY TO ARCTAN(SIN(LATITUDE) * TAN(beta)).
		SET AscCross TO SET360(_LAN + delY).
		SET DesCross TO SET360(_LAN + 180 - delY).
		SET d1 TO SET180(AscCross - angularPosition) * SIN(90 - beta).
		SET d2 TO SET180(DesCross - angularPosition) * SIN(90 - beta).
		SET d to d1. SET glaAscending TO 1.
		IF (ABS(d2) < ABS(d1)) { SET d to d2. SET glaAscending TO 0. }
	
		RETURN d.
	} ELSE {
		IF (_Inclination < 1) { RETURN 0. } //IF launch time doesn't make a difference
		ELSE IF (LATITUDE > 0) { RETURN SET180(_LAN + 90 - angularPosition). } //IF latitude > inc. launch high
		ELSE { RETURN SET180(_LAN + 90 - angularPosition). } //IF latitude > inc. launch low
	}
}

FUNCTION getOrbitAngle { //orbital angle relative to the north pole at current latitude
	PARAMETER _Inclination.
	IF (ABS(LATITUDE) < ABS(_Inclination)) { RETURN ARCSIN(COS(_Inclination) / COS(LATITUDE)). }
	ELSE { RETURN 90. }
}

//EngThrustIsp return total thrust and mean ISP for all active engines
FUNCTION EngThrustIsp
{
	set ens to list().
	ens:clear.
	set ens_thrust to 0.
	set ens_isp to 0.

	list engines in myengines.
		
	for en in myengines {
		if en:ignition = true and en:flameout = false {
			ens:add(en).
		}
	}
	//collect thrust and ISP
	for en in ens {
		set ens_thrust to ens_thrust + en:availablethrust.
		set ens_isp to ens_isp + en:isp.
	}
	//return total thrust and mean ISP
	if ens:length>0 { 
		return list(ens_thrust, ens_isp/ens:length).
	} else {	
		return list(0, 0).	
	}
}

function booster_ISP //return mean ISP in booster stage with landing engines only.
{

	local stage_engines is list().	
	local eng is 0.
	local eng_isp is 0.
	
	set stage_engines to ship:partstagged(landing_engines_tag).

	for eng in stage_engines {
		set eng_isp to eng_isp + eng:isp.  //total ISP of landing engines
	}	
	return eng_isp/stage_engines:length. 
}

FUNCTION deltaVbooster //for booster!
{   
    // fuel name list
    LOCAL fuels IS list().
    fuels:ADD("LiquidFuel").
    fuels:ADD("Oxidizer").
    fuels:ADD("SolidFuel").
    fuels:ADD("MonoPropellant").

    // fuel density list (order must match name list)
    LOCAL fuelsDensity IS list().
    fuelsDensity:ADD(0.005).
    fuelsDensity:ADD(0.005).
    fuelsDensity:ADD(0.0075).
    fuelsDensity:ADD(0.004).

    // initialize fuel mass sums
    LOCAL fuelMass IS 0.

    // calculate total fuel mass
    FOR r IN STAGE:RESOURCES
    {
        LOCAL iter is 0.
        FOR f in fuels
        {
            IF f = r:NAME
            {
                SET fuelMass TO fuelMass + fuelsDensity[iter]*r:AMOUNT.
            }.
            SET iter TO iter+1.
        }.
    }.  

    // thrust weighted average isp
    LOCAL thrustTotal IS 0.
    LOCAL mDotTotal IS 0.
//    LIST ENGINES IN engList. 
	set engList to ship:partstagged(landing_engines_tag).	
    FOR eng in engList
    {
        IF eng:IGNITION
        {
            LOCAL t IS eng:maxthrust*eng:thrustlimit/100. // if multi-engine with different thrust limiters
            SET thrustTotal TO thrustTotal + t.
            IF eng:ISP = 0 SET mDotTotal TO 1. // shouldn't be possible, but ensure avoiding divide by 0
            ELSE SET mDotTotal TO mDotTotal + t / eng:ISP.
        }.
    }.
    IF mDotTotal = 0 LOCAL avgIsp IS 0.
    ELSE LOCAL avgIsp IS thrustTotal/mDotTotal.

    // deltaV calculation as Isp*g0*ln(m0/m1).
    LOCAL deltaV IS avgIsp*9.81*ln(booster_drymass()+FuelTank(Booster_tag,"mass")/booster_drymass()).//ln(SHIP:MASS / (SHIP:MASS-fuelMass)).

	RETURN deltaV.
}.

function FuelTank //check fuel amount, open/close fuel valve
{
	parameter
		stage_tag, //tag for fuel tank
		command. //check/close/open/mass
	local Fa is 0. //amount of fuel
	local FM is 0. //mass of fuel
	local OxM is 0. //mass of oxidizer
	local stage_tag_list is ship:partstagged(stage_tag).
	local stage_fuel is list().
	local stage_fuel_size is stage_fuel:length.
	local tank is 0.
	local tank1 is 0.
	
	for parts in stage_tag_list{ //collect all tanks to list stage_fuel (like lqdFuel)
		stage_fuel:add(stage_tag_list[tank]:resources).
		set tank to tank +1.
	}
	
	set stage_fuel_size to stage_fuel:length.

	until tank1 = stage_fuel_size {	
		for res in stage_fuel[tank1]{
			if res:name = fuel_type {			
				if command = "check" { 
					set Fa to Fa + res:amount.  //F1 = total fuel amount in all tanks
				} else if command = "close" {
					set res:enabled to false. //close fuel valve
				} else if command = "open" {
					set res:enabled to true. //open fuel valve					
				} else if command = "mass" { 
					set FM to FM + (res:amount)*(res:density).  //FM = total fuel amount in all tanks
				}
			}
			if res:name = oxidizer_type {			
				if command = "mass" { 
					set OxM to OxM + (res:amount)*(res:density).  //OxM = total fuel amount in all tanks
				}
			}			
		}
		set tank1 to tank1 + 1.
	}
	if command = "check" { return Fa.
	} else if command = "mass" { return FM+OxM. }.
}

function booster_drymass
{
	local current_stage is stage:number. 
	local all_parts is 0.
	local M is 0. //total drymass
	list parts in all_parts.
	for part in all_parts {
		if part:stage = current_stage {
			set M to M + part:drymass.
		}
	}
	return M. 
}

function SetKUniverse
{
	set config:ipu to 500.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:unload to 250000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:load to 240000.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:pack to 230000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:unpack to 220000.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:unload to 250000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:load to 240000.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:pack to 230000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:unpack to 220000.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:unload to 250000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:load to 240000.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:pack to 230000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:unpack to 220000.
	wait 0.01.
}

function ReSetKUniverse
{
	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:unload to 22500.
	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:load to 2250.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:pack to 25000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:flying:unpack to 2000.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:unload to 2500.
	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:load to 2250.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:pack to 350.
	set KUNIVERSE:DEFAULTLOADDISTANCE:orbit:unpack to 200.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:unload to 15000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:load to 2250.
	wait 0.01.

	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:pack to 10000.
	set KUNIVERSE:DEFAULTLOADDISTANCE:suborbital:unpack to 200.
	wait 0.01.
}

function circularize {
  local th to 0. // в этой переменной будет необходимый уровень тяги
  local Vcircdir to vxcl( up:vector, velocity:orbit ):normalized. // направление круговой скорости такое же, как у горизонтальной компоненты орбитальной скорости
  local Vcircmag to sqrt(body:mu / body:position:mag). // mu - это гравитационный параметр планеты, произведение массы на гравитационную постоянную
  local Vcirc to Vcircmag*Vcircdir.
  local need_deltaV to Vcirc - velocity:orbit.
  local ThrIsp to EngThrustIsp(). //EngThrustIsp возвращает суммарную тягу и средний Isp по всем активным двигателям.
  local  AThr to ThrIsp[0]/(ship:mass). //Ускорение, которое сообщают ракете активные двигатели при тек. массе. 
  
  // начинаем прожиг, поворачивая ракету постоянно в сторону маневра
  lock steering to lookdirup( need_deltaV, up:vector).
  wait until vang( facing:vector, need_deltaV ) < 1. // убеждаемся, что прожиг начинается в нужной ориентации
  lock throttle to th.
  until need_deltaV:mag < 0.05 {
    set Vcircdir to vxcl( up:vector, velocity:orbit ):normalized.
    set Vcircmag to sqrt(body:mu / body:position:mag).
    set Vcirc to Vcircmag*Vcircdir.
    set need_deltaV to Vcirc - velocity:orbit.
    if vang( facing:vector, need_deltaV ) > 5 { 
      set th to 0. // если сильно не туда смотрим, надо глушить двигатель
    }
    else {
     set th to min(max(need_deltaV:mag/(AThr*5), 0.0001),1). // снижаем тягу, если приращение скорости нужно небольшое
	//      set th to min( 1, need_deltaV:mag * ship:mass / ship:availablethrust ). // снижаем тягу, если приращение скорости нужно небольшое
    }
    wait 0.1.
	displayManeuverData(mN).
  }
  set th to 0.
  set ship:control:pilotmainthrottle to 0.
  unlock throttle.
}