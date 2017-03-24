	// initialisation
@lazyglobal off.
clearscreen.
set ship:control:pilotmainthrottle to 0.

set config:ipu to 500. //setting ipu for kOS CPU
wait 0.01.

wait until Abort. // The program will wait until you press the Abort button to start 
unlock all.
wait 1.

//configuration
// parameter orbAlt is 150. // Default target altitude 100
// parameter _Inclination is 8.//default orbit inclination 0
// parameter _LAN is 89. //Default LAN
// parameter turnEnd is 47000. //Default altitude to zero pitch
// parameter turnExp is 1.67. //Default turn expanent

// requiring libraries

function has_file {
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
if not has_file("maneuvers.ks") {
	copypath("0:/maneuvers.ks","").
}
if not has_file("lib_navball.ks") { 
	copypath("0:/lib_navball.ks","").
}
if not has_file("telemetry.ks") {
	copypath("0:/telemetry.ks","").
}
if not has_file("flight_display.ks") {
	copypath("0:/flight_display.ks","").
}
if not has_file("functions.ks") {
	copypath("0:/functions.ks","").
}
//if not has_file("settings.ks") {
//	copypath("0:/settings.ks","").
//}

//run settings. 
run telemetry.ks. // general telemetry library
run flight_display.ks.
run lib_navball.ks.
run functions.ks.
run maneuvers.ks.

// setting the ship to a known state

rcs off.
sas off.

// declaring variables

set orbAlt to orbAlt * 1000.
local launch is 0.
local pitch is 90.
local runmode is 1.
local tval is 0.
local clearRequired is false.
local mN is 0.
local burnTo is 0.
local nD is 0.
local steer is up.
local curAlt is 0.
local missionT is 0.
local startT is 0.
local launchT is 0.
local head is 0.
local glaAscending to 0.
local atmoHeight is 0.

local ascentSteer is 0.
local angleLimit is 90.
local angleToPrograde is 0.
local ascentSteerLimited is 0.

local logtime to time:seconds.
local LaunchSite is ship:geoposition.

//ApoBurn
local Vh to 0.
local Vz to 0.
local Rad to 0.
local Vorb to 0.
local g_orb to 0.
local ThrIsp to 0.
local AThr to 0.
local ACentr to 0.
local DeltaA to 0.

//Orbit circularization
local StopBurn to false.
local ThrIsp is 0.
local AThr is 0.
local V1 is 0.
local V2 is 0.
local vecCorrection is 0.

// preparing PID loops

// --- ascending loops ---

local PitThr_PID is pidloop(0.1, 0.001, 0.05, 0.2, 1).
local ApoThr_PID is pidloop(0.2, 0, 0.1, 0, 1).

// --- END ascending loops ---

// final preparation
set startT to time:seconds.
set launchT to startT + 10.

lock throttle to max(0, min(1, tval)).
lock steering to steer.


if ship:status <> "Landed" and ship:altitude > 10000{ 
	set runmode to 4.
	set launch to 1. 
}

// Fairing separation when above 95% of atmosphere height 
IF SHIP:BODY:ATM:EXISTS {
	WHEN ALTITUDE > atmoHeight()*0.95 THEN {
		TOGGLE AG2. 
	}.
}.

//waiting for launch window. Depends on inclination, LAN and latitude of launching site
if launch = 0 {
	until ABS(getLaunchAngleOffset(_Inclination, _LAN)) < 1 OR _Inclination < LATITUDE {
		print "Waiting for launch window... : " + getLaunchAngleOffset(_Inclination, _LAN) at (0,0).
		Wait 4.
		if not(warp = 3) {
			set warp to 3.
		}
	}
}
set warp to 0.

wait 3.

wait 0.001. // waiting 1 physics tick
clearscreen.
// ----------------================ Main loop starts here ================----------------

until runmode = 0 {
	
	// stuff that needs to update before every iteration
	set missionT to time:seconds.
	set curAlt to ship:altitude.
	
	// runmodes
	
	if runmode = 1 // Engine ignition
	{
		if alt:radar > 200 {
			set runmode to 3.
		} else if missionT >= launchT - 1 {
			stage. // launch tower
			set tval to 0.3.
			wait 0.5.
//			stage. //ignition!
//			set turnEnd TO 0.128*atmoHeight()*shipCurrentTWR() + 0.5*atmoHeight(). // Based on testing
//			set turnExp TO MAX(1/(2.5*shipCurrentTWR() - 1.7), 0.25). // Based on testing	or -1.35 instead of -1.7	
			set tval to 1.
			set runmode to 2.
		}
	}
	else if runmode = 2 // Liftoff!!
	{
		if missionT >= launchT {
			wait 2.
			gear off.
			set runmode to 3.
		}
	}
	else if runmode = 3 // Initiating pitch-over
	{
		if curAlt >= 20000 { //we passed dense air
			set runmode to 4.
		} else {
			if airspeed >= 60 { // airspeed to start pitching
				set pitch to 88.
			}
			if airspeed >= 70 { // from that speed rocket will continue pitching relative to altitude
				set pitch to max(0, 88 * (1 - ship:altitude / endTurnAltitude)).  // here you may ajust ascending profile
				set ascentSteer to heading(head, pitch).
				// TODO Gravity Turn Angle = 90 * (Current Alt / Desired Alt) ^ 0.4
				// Don't pitch too far off surface prograde while under high dynamic pressrue maxQ
				if ship:q > 0 { 
					set angleLimit to max(3, min(90, 5*ln(0.9/ship:q))).
				} else { 
					set angleLimit to 90.
				}
				set angleToPrograde to vang(SHIP:SRFPROGRADE:VECTOR,ascentSteer:VECTOR).
				if angleToPrograde > angleLimit {
					set ascentSteerLimited to (angleLimit/angleToPrograde * (ascentSteer:VECTOR:NORMALIZED - SHIP:SRFPROGRADE:VECTOR:NORMALIZED)) + SHIP:SRFPROGRADE:VECTOR:NORMALIZED.
					set ascentSteer to ascentSteerLimited:DIRECTION.
				}
				set steer to ascentSteer.

			}
			//controlling thrust level 
			set PitThr_PID:setpoint to 22 + (ship:altitude / 600). 
			set tval to PitThr_PID:update(time:seconds, eta:apoapsis).
			if airspeed < 100 { // 100% thust until 100m/s
				set tval to 1.
			}
		}
	}
	else if runmode = 4 // initiating gravity turn
	{
		if curAlt >= 55000 or ship:apoapsis > (orbAlt * 0.98) { 
			set runmode to 5.
		} else {
//			set pitch to max(0,90*((1-ship:altitude/turnEnd)^turnExp)).
			set pitch to max(0, 88 * (1 - ship:altitude / endTurnAltitude)). 
//				set pitch to max(0,88*((1-ship:altitude/turnEnd)^turnExp)).
 			if tval <= 0.99 {  // speed up!
				set tval to tval + 0.01.
			} else {
				set tval to 1.
			}
		}
	}
	else if runmode = 5 // Deploy fairings and antenna
	{
		set runmode to 6.
	}
	else if runmode = 6 // continue until desired apoapsis and cut the throttle
	{
		set tval to 1.
		sas off.
		set pitch to 2. //was 0
 		if ship:apoapsis >= orbAlt  { 
			set tval to 0.
			set runmode to 7.
		}
	}
	else if runmode = 7 // coast until above the atmosphere, warp if needed
	{
		if ship:apoapsis > atmHeight() and curAlt < atmHeight() {
			if not(warpmode = "PHYSICS") {
				set warpmode to "PHYSICS".
			}
			//if not(warp = 3) {
			//	set warp to 3.
			//}
		} else if ship:apoapsis < atmHeight() + 500 {
			if not(warp = 0) {
				set warp to 0.
			}
			set runmode to 6. // if ship apoapsis fals into the atmosphere, go back to runmode 6
		} else if curAlt >= atmHeight() {
			if not(warp = 0) {
				set warp to 0.
			}

			set runmode to 8.
		}
	}
	else if runmode = 8 // tuning after leaving atmosphere
	{
		if curAlt >= atmHeight() {
			if ship:apoapsis < orbAlt { 
				set ApoThr_PID:setpoint to orbAlt + 10.
				set tval to ApoThr_PID:update(time:seconds, ship:apoapsis).
			} else {
				set tval to 0.
				set runmode to 9.
			}
		} else {
			set runmode to 7.
		}
	}
	else if runmode = 9 //ready for circularization, check Apo, set maneuver data
	{
		if ship:verticalspeed > 0 { //if we are still ascending - go to next Apo and rise Pe
			set mN to node(time:seconds + eta:apoapsis, 0, 0, getCircularizationDeltaV(ship:apoapsis)).
			add mN.  
			set burnTo to mN:burnvector.
			RCS ON.
			lock steering to burnTo.
			set runmode to 10.
//			print " WAITING APOAPSIS...                                  "																at (1,28).
//			wait 0.1.
		} 
		else  //in case we missed Apo... so make perfect circularization now
		{ 
			until StopBurn
			{
				set ThrIsp to EngThrustIsp(). //EngThrustIsp возвращает суммарную тягу и средний Isp по всем активным двигателям.
				set AThr to ThrIsp[0]/(ship:mass). //Ускорение, которое сообщают ракете активные двигатели при тек. массе. 
				set V1 to ship:velocity:orbit.		
				set V2 to VXCL(Ship:UP:vector, ship:velocity:orbit):NORMALIZED*sqrt(ship:body:Mu/(ship:body:radius+ship:altitude)).
				set vecCorrection to V2-V1.
				RCS ON.
				LOCK Steering to vecCorrection.
				if VANG(vecCorrection, ship:facing:forevector)<0.5 {
					if AThr>0 {
						LOCK Throttle to  min(max(vecCorrection:MAG/(AThr*5), 0.0001),1).	
					}
				}
				displayOrbitData().				
				if vecCorrection:MAG<0.1	{
						set StopBurn to true.
				}
			}

			LOCK Throttle to 0.
			set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.
			UNLOCK Steering.			
			set runmode to 12.
		}
	}
	else if runmode = 10 //WARP to APOAPSIS
	{

		if (SHIP:ALTITUDE > 70000) and (ETA:APOAPSIS > 60) and (VERTICALSPEED > 0) {
            if WARP = 0 {        // If we are not time warping
                wait 1.         //Wait to make sure the ship is stable
//              SET WARP TO 2. //Be really careful about warping
            }
        } else if ETA:APOAPSIS < 30 {
            SET WARP to 0.
			wait 1.
			RCS ON.
			lock steering to burnTo.
			UNTIL ETA:Apoapsis < 10. //wait until Apo
            set runmode to 11.
        }
    }
	else if runmode = 11 //Burn to raise Periapsis
	{
		until StopBurn
		{
			set tval to 1. //circularization burn
			local Vh to VXCL(Ship:UP:vector, ship:velocity:orbit):mag.	//Horizontal velocity
			local Vz to ship:verticalspeed. // Vertical velocity
			local Rad to ship:body:radius+ship:altitude. // Orbit radius
			local Vorb to sqrt(ship:body:Mu/Rad). //Vo - Orbital velocity
			local ACentr to Vh^2/Rad. //centripetal acceleration
			set DeltaA to gravity(ship:altitude)-ACentr-Max(Min(Vz,2),-2). //Difference between Gravity, centripetal acceleration and vertical velocity
			local Fi to arcsin(DeltaA/shipAcc()). // Calculating pitch to preserve vertical velocity to zero. 
			local dVh to getOrbitalVelocity(ship:altitude)-Vh. //Difference between current horizontal velocity and orbital velocity.
			if dVh<0 { 
				set StopBurn to true.				
				set runmode to 12.
			}
			else if dVh<100		
				set tval to Max(dVh/100, 0.01).

			LOCK Steering to Heading(head, Fi). //Setting heading (to reach desired inclination) and pitch (to preserve altitude)
			displayManeuverData(mN).
		}
	}
	else if runmode = 12 { //Final touches
        set TVAL to 0. //Shutdown engine.
//		toggle ag7. //time to deploy panels etc.
        unlock steering.
		clearscreen.
        print "SHIP SHOULD NOW BE IN SPACE!".
        set runmode to 0.
		unlock all.
		wait 3.
	}
	// stuff that needs to update after every iteration
	if engineFlameout() {
		lock throttle to 0.
		wait 0.2.
		stage.
		wait 1.
		lock throttle to tval.
	}
	if clearRequired {
		clearscreen.
		set clearRequired to false.
	}
	displayFlightData().
	displayLaunchData().
	
	
	log round((time:seconds-logtime),2) + "," + round((launchSite:POSITION - ship:geoposition:POSITION):MAG,2) + "," + round(ship:altitude,2) + "," to "testflight.csv".

// Calculating heading to reach desired inclination
	set head to getOrbitAngle(_Inclination) - 0.115 * (90 - getOrbitAngle(_Inclination)).
	if (ABS(ORBIT:INCLINATION) > ABS(_Inclination)) { set head to getOrbitAngle(_Inclination). }
	if (glaAscending = 0) { set head to 180 - head. }
	
	set steer to heading(head, pitch).
	
	wait 0.001. // waiting 1 physics tick
}

unlock all.





