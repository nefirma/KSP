
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

FUNCTION getOrbitAngle { //orbital angle relative to the north pole at current longitude
	PARAMETER _Inclination.
	IF (ABS(LATITUDE) < ABS(_Inclination)) { RETURN ARCSIN(COS(_Inclination) / COS(LATITUDE)). }
	ELSE { RETURN 90. }
}

//EngThrustIsp возвращает суммарную тягу и средний Isp по всем активным двигателям.
FUNCTION EngThrustIsp
{
	//создаем пустой лист ens
  set ens to list().
  ens:clear.
  set ens_thrust to 0.
  set ens_isp to 0.
	//запихиваем все движки в лист myengines
  list engines in myengines.
	
	//забираем все активные движки из myengines в ens.
  for en in myengines {
    if en:ignition = true and en:flameout = false {
      ens:add(en).
    }
  }
	//собираем суммарную тягу и Isp по всем активным движкам
  for en in ens {
    set ens_thrust to ens_thrust + en:availablethrust.
    set ens_isp to ens_isp + en:isp.
  }
  //Тягу возвращаем суммарную, а Isp средний.
  IF ens:length>0
	RETURN LIST(ens_thrust, ens_isp/ens:length).
  ELSE	
	RETURN LIST(0, 0).	
}

function FuelTank //check fuel amount, open/close fuel valve
{
	parameter
		stage_tag, //tag for fuel tank
		command. //check/close/open
		
	local F1 is 0.
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
			if res:name = "LiquidFuel" {			
				if command = "check" { 
					set F1 to F1 + res:amount.  //F1 = total fuel amount in all tanks
				} else if command = "close" {
					set res:enabled to false. //close fuel valve
				} else if command = "open" {
					set res:enabled to true. //open fuel valve					
				}
			}
		}
		set tank1 to tank1 + 1.
	}
	if command = "check" { return F1. }
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