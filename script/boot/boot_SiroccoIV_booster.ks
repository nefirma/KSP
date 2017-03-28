//boot file for Sirocco IV Booster

set Booster_tag to "sirocco-tank".
set MECOcoef to .9. // coefficient for MECO calculation. 
set safe_altitude to 650. // safe altitude to start suicide burn
set Laser to ship:partstagged("Laser")[0]:getmodule("LaserDistModule"). //LaserMod - altimiter
set laser_height to 3.2. //height of Laser module above ground level with deployed legs => CHECK IT!
set landReq to 2. // landing position: 0 if landing is not required, 1 - RTLS, 2 - land on target => check this settings below
set fuel_type to "LiquidFuel". //type of fuel
set oxidizer_type to "Oxidizer". //type of oxidizer.

switch to 0.
wait 0.5.
run sirocco_booster.