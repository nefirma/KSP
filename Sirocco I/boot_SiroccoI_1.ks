@lazyglobal off.
clearscreen.

// This script not optimised, but reasonable worked for me. Work In Progress ;-) 

set config:ipu to 500. //setting ipu for kOS CPU
wait 0.01.
wait until Abort. // The program will wait until you press the Abort button to start 

//configuration
local landReq is 2. // landing position: 0 if landing is not required, 1 - RTLS, 2 - land on target => check this settings below

function has_file { // function that checks if a file exists on the hard drive
	parameter name.
	local allFiles is 0.
	list files in allFiles.
	for file in allFiles {
		if file:name = name {
			return true.
		}
	}
	return false.
}

// downloading needed function libraries
if not has_file("lib_navball.ks") { 
	copypath("0:/lib_navball.ks","").
}
if not has_file("telemetry.ks") {
	copypath ("0:/telemetry.ks","").
}
if not has_file("flight_display.ks") {
	copypath ("0:/flight_display.ks","").
}
if not has_file("functions.ks") {
	copypath("0:/functions.ks","").
}
if not has_file("land_lib.ks") {
	copypath("0:/land_lib.ks","").
}

run lib_navball. // running libraries
run telemetry.
run flight_display.
run functions.
run land_lib.

//setting up variables
local pitch is 90.
local runmode is 1.
local tval is 0.
local clearRequired is false.
local velLat is 0. // change in latitude since last physics tick
local velLng is 0. // change in longitude...
local dt is 0. // delta time (time between physics ticks)
local steerPitch is 0. // pitch offset
local steerYaw is 0. // yaw offset
local steer is up. // steering direction
local curAlt is 0. // current altitude (basically same as ship:altitude)
local missionT is 0. // current time
local launchT is 0. // time until/since launch
local startT is 0. // time when the program started
local oldT is 0. // time of last physics tick
local prevPos is 0. // geoposition of last physics tick
local curPos is 0. // current geoposition
local impactTime is 0. // time untill crossing the landing altitude
local impactPos is 0. // landing position but before accounting for planet rotation
local landingPos is 0. // landing position
local landingSite is 0. // geoposition of landing site
local landingAltitude is 0. // sea level altitude of the landing site
local stageApo is 0. // not important anymore, its the apoapsis at the moment of stage separation
local desPitch is 10. // pitch during boostback
// local lqdFuel is core:part:parent:resources[0]. // selecting liquid fuel in stage 1 tank
local lqdFuel is 0.
local booster_tank is "sirocco-tank".
LOCK lqdFuel to FuelTank("sirocco-tank","check"). //Fuel left in the BOOSTER stage => tanks have to have specific tag name
local geoDistance is 0.
local steeringDir to 0.
local steeringPitch to 0.
local MECO is 0. // Main Engine Cutoff (how much fuel needs to be left for boostback and landing)

// laser module at the bottom to fine measures booster altutude at final approach
local finedist is 0. //distance from last
local Vdist is 0. //calculated real altitude by laser
local Laser to ship:partstagged("Laser")[0]:getmodule("LaserDistModule").

// shoud we Return To Launch Site?
local LaunchSite is ship:geoposition. //RTLS

if landReq = 0 { // setting the landing site
	set landingSite to 0. 
} else if landReq = 1 { //RTLS
	setkuniverse(). // change default KUniverse settings for this launch. After complete this script we'll change it back. Also you can use FMRS mod to split ascending 2nd stage and booster.
	set landingSite to LaunchSite.		
} else if landReq = 2 { //Land on target
	setkuniverse(). // change default KUniverse settings for this launch. After complete this script we'll change it back. Also you can use FMRS mod to split ascending 2nd stage and booster.
	set landingSite to target:geoposition.		
}

// set landingAltitude to ROUND(MAX(0.001,(landingSite:terrainheight))).

if landingSite = 0 { 
	set MECO to 0.
} else {
	lock MECO to 10 + (groundspeed * .4). // amount of fuel needed for boostback and landing. 
}
local staging is false.
//when lqdFuel:amount <= MECO then { set lqdFuel:enabled to false. HUDTEXT("Booster MECO. ", 10, 1, 30, yellow, false).	wait 1. } // cutting liquid fuel when MECO reached (this cause launch script to stage)
when alt:radar > 1000 and lqdFuel <= MECO then { FuelTank("sirocco-tank","close"). HUDTEXT("Booster MECO. ", 10, 1, 30, yellow, false).	wait 1. } // cutting liquid fuel when MECO reached (this cause launch script to stage)
when alt:radar < 200 and runmode > 2 then { legs on. } // deploying landing legs

// preparing final touch


// Lets get some math out of the way, shall we? 
lock shipLatLng to SHIP:GEOPOSITION. //This is the ship's current location above the surface

local radar to 0.
LOCK radar to terrainDist().
local targetDist is 0.
local targetDir is 0.
LOCK targetDist to geoDistance(landingSite, ADDONS:TR:IMPACTPOS).
LOCK targetDir to geoDir(ADDONS:TR:IMPACTPOS, landingSite).
local cardVelCached to 0.
set cardVelCached to cardVel().
local targetDistold to 0.
local shipProVec is 0.
local launchPadVect is 0.
local rotateBy is 0.
local steeringVect is 0.
local loopCount is 0.
local steeringArrow to 0.
local retroArrow to 0.
local lpArrow to 0.
set steeringArrow to VECDRAW().
set steeringArrow:VEC to heading(steeringDir,steeringPitch):VECtoR.
set steeringArrow:SCALE to 10.
set steeringArrow:COLOR to RGB(1.0,0,0).
set retroArrow to VECDRAW().
set retroArrow:VEC to RETROGRADE:VECtoR.
set retroArrow:SCALE to 10.
set retroArrow:COLOR to RGB(0,1.0,0).
set lpArrow to VECDRAW().
set lpArrow:VEC to RETROGRADE:VECtoR.
set lpArrow:SCALE to 10.
set lpArrow:COLOR to RGB(0,0,1.0).


// preparing PID loops
// --- landing loops ---
local laser_height to 1.8. //height of Laser module above ground level with deployed legs
lock finedist to Laser:GETFIELD("Distance").
lock Vdist to (finedist-laser_height) * sin(vang(up:vector,ship:facing:topvector)). //vertical distance between legs and landing surface. Measured by Laser
local climbPID is 0.
local hoverPID is 0.
local eastVelPID is 0.
local northVelPID is 0.
local eastPosPID is 0.
local northPosPID is 0.

set climbPID to PIDLOOP(0.2, 0.01, 0.005, 0, 1). //Controls vertical speed
set hoverPID to PIDLOOP(1, 0.01, 0.0, -15, 15). //Controls altitude by changing climbPID setpoint
set hoverPID:setPOINT to 5. // to slow down ABOVE landing pad
set eastVelPID to PIDLOOP(3, 0.01, 0.0, -20, 20). //Controls horizontal speed by tilting rocket
set northVelPID to PIDLOOP(3, 0.01, 0.0, -20, 20).
set eastPosPID to PIDLOOP(1700, 0, 100, -15, 15). //Controls horizontal position by changing velPID setpoints
set northPosPID to PIDLOOP(1700, 0, 100, -15, 15).
set eastPosPID:setPOINT to landingSite:lng.
set northPosPID:setPOINT to landingSite:lat.


// Altitude control during suicide burn
local AltVel_PID is pidloop(0.2, 0, 0.04, -19, 19). // was 280 /calculating desired velocity during landing
local VelThr_PID is pidloop(0.05, 0.01, 0.005, 0, 1). // adjusting thrust to reach that velocity

// --- END landing loops ---

// final preparation - setting up for launch

set startT to time:seconds.
set oldT to startT.
set prevPos to ship:geoposition.



wait 0.001. // waiting 1 physics tick to avoid errors

// ----------------================ Magic. Do not touch! ================----------------

until runmode = 0 {
	// stuff that needs to update before every iteration
	set missionT to time:seconds.
	set dt to missionT - oldT.
	set curPos to ship:geoposition.
	set curAlt to ship:altitude.
	set velLat to (prevPos:lat - curPos:lat)/dt.
	set velLng to (prevPos:lng - curPos:lng)/dt.
	if runmode >= 2 {

	
//		set impactTime to timetoAltitude(landingAltitude). // time untin impact
//		set impactPos to body:geopositionof(positionat(ship, time:seconds + impactTime)). // position of impact
//		set landingPos to latlng(impactPos:lat, impactPos:lng - impactTime * 0.01666666). // adding planet rotation
	}


	// The main code
	if runmode = 1 // keep checking if stage 1 separated
	{
		// displaying data about fuel

		print "Amount of fuel left: " + round(lqdFuel, 2) + "          " at (3,20).
		print "Fuel cut-off amount: " + round(MECO, 2) + "          " at (3,21).
						
		if engineFlameout() {  // check flameout, indicating staging
			set stageApo to ship:apoapsis.
			if stageApo < 20000 { set desPitch to 35. }
			if stageApo < 70000 and groundspeed > 800 { set desPitch to 0. } // changing boostback pitch depending on speed/distance
			wait 2. // waiting 1 second to make sure that ship has completed staging
			FuelTank("sirocco-tank","open"). // enabling fuel again
			rcs on.
			set runmode to 2.
			set clearRequired to true. // clearing screen
		}
	}
	else if runmode = 2
	{
		sas off.
		set SHIP:CONTROL:NEUTRALIZE to true.		
		wait 0.2.
//		toggle AG1. //shutdown outer engines 
		lock throttle to 0.1. 
		lock steering to heading(landingSite:heading, -30). 
		HUDTEXT("Booster separation complete. ", 10, 1, 30, yellow, false).
		set runmode to 2.1.
	}
	else if runmode = 2.1
	{
		set steeringDir to targetDir - 180. //point towards landing site
		set steeringPitch to 0.
		LOCK steer to heading(steeringDir,steeringPitch).
//		set lqdFuel:enabled to true. // enabling fuel again		
		set runmode to 3. 	
	}
	else if runmode = 3
	{
		if ADDONS:TR:HASIMPACT = true { //If ship will hit ground
			set steeringDir to targetDir - 180. //point towards landing site
			set steeringPitch to 0.
			if vang(heading(steeringDir,steeringPitch):VECtoR, SHIP:FACING:VECtoR) < 20 {  //wait until pointing in right direction
				set tval to targetDist / 5000 + 0.2.
			} else {
				set tval to 0.
			}
			if targetDist < 450 and targetDist > targetDistold { //check if we will hit ground next to landing site 
					wait 0.2.
					set tval to 0.
					set runMode to 3.5.
			}
			set targetDistold to targetDist.
		}	
	}
	else if runmode = 3.5 //let's stabilze Booster before re-entry
	{
		set steeringDir to targetDir - 180. //point towards landing site
		set steeringPitch to 0.
		LOCK steer to heading(steeringDir,0).
		wait 10.
		RCS off.
		toggle brakes. //extend Grid Fins, switch off RCS => during descend we'll use aerodynamics only		
		set runmode to 4. 	
	} 
	else if runMode = 4  //Glide rocket to landing site.
	{
		set shipProVec to (SHIP:VELOCITY:SURFACE * -1):NORMALIZED.
		if SHIP:VERTICALSPEED < -10 { 
			set launchPadVect to (landingSite:POSITION - ADDONS:TR:IMPACTPOS:POSITION):NORMALIZED. //vector with magnitude 1 from impact to launchpad
			if geoDistance(SHIP:GEOPOSITION, landingSite) < 100 and curAlt < 15000 { //When it is low and over the launch pad
				set rotateBy to MIN(targetDist*2, 5). //how many degrees to rotate the steeringVect
				set steeringVect to shipProVec * 20. //velocity vector lengthened
			} else { // if it's in early approach
				set rotateBy to MIN(targetDist*2, 15). //how many degrees to rotate the steeringVect
				set steeringVect to shipProVec * 40. //velocity vector lengthened
			}
			set loopCount to 0.
			until (rotateBy - vang(steeringVect, shipProVec)) < 3 { //until steeringVect gets close to desired angle
				if vang(steeringVect, shipProVec) > rotateBy { //stop from overshooting
					BREAK.
				}
				set loopCount to loopCount + 1.
				if loopCount > 100 {
					BREAK.
				}
				set steeringVect to steeringVect - launchPadVect. //essentially rotate steeringVect in small increments by subtracting the small vector.
			}
			set steeringArrow:VEC to steeringVect:NORMALIZED. //RED
			set retroArrow:VEC to shipProVec. //GREEN
			set lpArrow:VEC to launchPadVect:NORMALIZED. //BLUE
			LOCK steer to steeringVect:DIRECTION.
		} else {
			LOCK steer to (shipProVec):DIRECTION.
		}

		when radar < 650 AND SHIP:VERTICALSPEED < -20 THEN {//When there is barely enough time to slow down.
			RCS on.
			set runmode to 5.
		}
	}
	else if runmode = 5 // Suicide burn (slowing down to safe speed)
	{
		if not Laser:getfield("Enabled") {
			Laser:setfield("Enabled",true).
		}		
		SET eastVelPID:MINOUTPUT TO -5.
		SET eastVelPID:MAXOUTPUT TO 5.
		SET northVelPID:MINOUTPUT TO -5.
		SET northVelPID:MAXOUTPUT TO 5.
		SET steeringDir TO 0.
		SET steeringPitch TO 90.
		LOCK STEERING TO HEADING(steeringDir,steeringPitch).
		SET cardVelCached TO cardVel().
		steeringPIDs().

		set AltVel_PID:setpoint to radar+20. // landing burn
		If radar > Vdist { //in case we over water use radar altitude instead of laser
			set VelThr_PID:setpoint to AltVel_PID:update(missionT, radar+20). //Vdist). //lower ship down while flying to landing site
		} else {
			set VelThr_PID:setpoint to AltVel_PID:update(missionT, Vdist).
		}
		set tval to VelThr_PID:update(missionT, verticalspeed).
		when ship:verticalspeed > -20 then { // when stop falling
			RCS on.
			set runmode to 7.
		}
	}
	else if runmode = 6 // Approaching at safe speed
	{

	
	
	}
	else if runmode = 7 // In case we misss a bit - powered flight to landing site 
	{
		set eastVelPID:MINOUTPUT to -15.
		set eastVelPID:MAXOUTPUT to 15.
		set northVelPID:MINOUTPUT to -15.
		set northVelPID:MAXOUTPUT to 15.
		set cardVelCached to cardVel().
		If radar > Vdist { //in case we over water use radar altitude instead of laser
			set climbPID:setPOINT to hoverPID:UPDATE(TIME:SECONDS, Vdist). //lower ship down while flying to landing site
		} else {
			set climbPID:setPOINT to hoverPID:UPDATE(TIME:SECONDS, radar).
		}
		set tval to climbPID:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
		
		LOCK steer to heading(steeringDir,steeringPitch).
		steeringPIDs().

		when geoDistance(SHIP:GEOPOSITION, landingSite) < 7 then { //When it is over the launch pad
			set runmode to 8.
		}
	}
	else if runmode = 8 // final touchdown at safe speed
	{
		set eastVelPID:MINOUTPUT to -5.
		set eastVelPID:MAXOUTPUT to 5.
		set northVelPID:MINOUTPUT to -5.
		set northVelPID:MAXOUTPUT to 5.
		set cardVelCached to cardVel().
		steeringPIDs().
		set climbPID:setPOINT to MAX((Vdist-0.1), 1.8) * -1.
		PRINT "climbPID:setPOINT: " + climbPID:setPOINT at(3,39).
		set tval to climbPID:UPDATE(TIME:SECONDS, SHIP:VERTICALSPEED).
		if (ship:status = "Landed") or (Vdist<1.8) { // checking if we have landed already
			set runmode to 0.
			LOCK throttle to 0.
			set SHIP:CONTROL:pilotmainthrottle to 0.			
			set steer to up.
		}
	}
	
	
	// stuff that needs to update after every iteration
	if clearRequired {
		clearscreen.
		set clearRequired to false.
	}
	displayFlightData().
	if runmode >= 3 and runmode <> 3.5 {
		lock throttle to max(0, min(1, tval)).
		lock steering to steer.
	}

	
	if runmode >= 2.2 {
//		print "    " + round(landingSite, 5) + "          " at (3,23).
		print "Landing Position LONG: " + round(landingSite:lng, 5) + "          " at (3,24).
		print "Landing Position LAT:     " + round(landingSite:lat, 5) + "          " at (3,25).
//		print "Delta LONG:                       " + round((abs(landingSite:lng) - abs(landingPos:lng)), 5) + "          " at (3,26).
//		print "Delta LAT:                           " + round((landingPos:lat - landingSite:lat), 5) + "          " at (3,27).
		print "Target Dist:          " + round(targetDist, 0) + "m     " at (3, 28).
//		print "Steer Pitch:          " + round(steerPitch, 2) + "     " at (3, 29).
//		print "Steer Yaw:            " + round(steerYaw, 2) + "     " at (3, 30).
//		print "Impact Time:          " + round(impactTime, 0) + "s     " at (3, 31).
		print "Altitude:             " + round(radar,0) + "m			" at (3, 32).
		print "Laser Altitude:       " + round(Vdist,1) + "m			" at (3, 33).
	}

	// setting variables to new values
	set oldT to missionT.
	set prevPos to curPos.
	wait 0.001. // waiting 1 physics tick
}

unlock all. // we are done!
print "restore KUniverse" at (3,40).
resetkuniverse().

