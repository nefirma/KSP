//Print data to screen
@lazyglobal off.

set terminal:width to 60.
set terminal:height to 50.

function displayFlightData {

//Title bar
print "------------------- Flight Display 1.5 --------------------"																at (1,1).		
print "Launch Time:             T" + round(missionT - launchT) + "               "												at (3,2).
// Body info
print "Current Body:            " + currentBody() + "               "															at (3,3).
print "Atm Height:              " + atmHeight() + "               "																at (3,4).
print "SL Gravity:              " + round(staticGravity(), 2) + "               "												at (3,5).
print "                                                           "																at (1,6).
print "OrbitalVel :             " + round(SQRT(ABS(SHIP:VELOCITY:ORBIT * SHIP:VELOCITY:ORBIT)),1) + " m/s                     " 		at (3,7).
print "TWR:                     " + round(shipCurrentTWR(), 2) + " / " + round(shipTWR(), 2) + "               "				at (3,8).
// print "                                                           "																at (1,9).
print "Heading:                 " + round(compass_for(ship), 2) + "               "												at (3,10).
print "Pitch:                   " + round(pitch_for(ship), 2) + "               "												at (3,11).
print "Roll:                    " + round(roll_for(ship), 2) + "               "												at (3,12).
//print "  Direction angle:" + round(vang(ship:up:vector, ship:facing:forevector), 2) + "              "				at (3,13).
print "                                                          "																at (1,13).
print "Sea Level Altitude:      " + round(ship:altitude / 1000 , 1) + "km               "										at (3,14).
print "  Current FLIGHT MODE:     " + runmode                         																at (1,15).
print "-----------------------------------------------------------"																at (1,16).
print "                                                           "																at (1,17).
}

function displayLaunchData {
lock UpperTank to ship:partstagged("UpperTank")[0]. // stage 1 fuel tank(s)
lock FuelLeft to UpperTank:resources[0]:amount. 
print "Inclination:             " + round(ORBIT:INCLINATION,1)																AT(3,18).
print "Target Heading:          " + round(head, 2) + "               "														at (3,19).
print "Target Pitch:            " + round(pitch, 2) + "               "															at (3,20).
print "Target Apoapsis:         " + round(orbAlt / 1000) + "km               "											at (3,21).
print "Current Apoapsis:        " + round(ship:apoapsis / 1000, 1) + "km in " + round(eta:apoapsis, 0) + "sec"			at (3,22).
print "L. A. N. :               " + round(ORBIT:LAN) 																		at (3,23).
print "Amount of fuel left:     " + round(FuelLeft, 1) + "  	                   "   													at (3,24).
print "dV left:                 " + round(deltav(), 1) + " m/s                     "														at (3,25).
print "Q      :                 " + round(ship:q,1)                                                                       			at (3,26).
//print "-----------------------------------------------------------"																at (1,23).
print "                                                           "																at (1,27).
}

function displayManeuverData {
parameter node.

print "Inclination:             " + round(ORBIT:INCLINATION,1)																AT(3,18).
print "Maneuver ETA:            " + round(node:eta - (nodeBurnTime(node) / 2), 1) + "s               "							at (3,19).
print "Orbital Velocity:        " + round(getOrbitalVelocity(ship:apoapsis), 1) + "m/s               "							at (3,20).
print "Velocity at Apoapsis:    " + round(getVelocityAtApoapsis(), 1) + "m/s               "									at (3,21).
print "Node DeltaV Reqired:     " + round(node:deltav:mag, 1) + "m/s               "											at (3,22).
print "Estimated Burn Time:     " + round(nodeBurnTime(node), 1) + "s               "											at (3,23).
print "                                                           "																at (1,24).
print "-----------------------------------------------------------"																at (1,25).
print "                                                           "																at (1,26).
}

function displayOrbitData {

print "Inclination:             " + round(ORBIT:INCLINATION,1)																AT(3,18).
print "Apoapsis:                " + round(Ship:Orbit:Apoapsis,0) + "m                 "							at (3,19).
print "Periapsis:               " + round(Ship:Orbit:Periapsis,0) + "m                 "							at (3,20).
print "Eccentricity:           " + round(Ship:Orbit:Eccentricity,2) + "                  "							at (3,21).
print "L. A. N. :               " + round(ORBIT:LAN) 																		at (3,22).
print "Amount of fuel left:     " + round(FuelLeft, 1) + "  	                   "   													at (3,23).
print "dV left:                 " + round(deltav(), 1) + " m/s                     "														at (3,24).
print "                                                           "																at (1,25).
print "-----------------------------------------------------------"																at (1,26).
print "                                                           "																at (1,27).
}




