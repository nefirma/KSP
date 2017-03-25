//boot file for Sirocco IV Upper stage

//launch settings
set orbAlt to 150. // Default target altitude 100
set _Inclination to 8.//default orbit inclination 0
set _LAN to 89. //Default LAN
set endTurnAltitude to 47000. //altitudeof Gravity Turn end 

//Specific settings
set UpperStage_tag to "upper-tank".
set fuel_type to "LiquidFuel". //type of fuel
set oxidizer_type to "Oxidizer". //type of oxidizer.

switch to 0.
wait 0.5.
run sirocco_upperstage.