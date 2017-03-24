# Kerbal Space Program
# SIROCCO REUSABLE* LIFTER FAMILY
### * - VTVL (Vertical Take-Off and Vertical Landing), powered by kOS

Sirocco is a two stages lifter with re-usable booster (first stage).  

Sirocco family use Russian engines from RealEngines mod pack and come in various versions:

- **Sirocco I - may lift up to 3.5T to LKO (150km)**
- **Sirocco IV - may lift up to 20T to LKO (150km)** 
- Sirocco V - under development
- Sirocco VII - under development
- Sirocco X - under development

##You may set desired orbit (altitude, inclination and LAN) and landing site (none/RTLS/VL@target).## 

### Requirement Mods:
1. kOS - https://ksp-kos.github.io/KOS/downloads_links.html
2. Trajectories - https://github.com/neuoy/KSPTrajectories/releases
3. LaserDist - https://github.com/Dunbaratu/LaserDist/releases
4. Kerbal Reusability Expansion - https://spacedock.info/mod/841/Kerbal%20Reusability%20Expansion

### Installation:
1. Copy "script" folder to your /KSP/Ships folder as is.
2. Copy *.craft files from "VAB" to VAB folder under your saves folder. 
3. If you need barge you may copy "Big Barge.craft" to your SPH folder. You have to manually put this craft to desired location. Auto-script not implemented yet.

### Pre-launch steps:
1. Check boot_Sirocco#_booster.ks for booster configuration: Landing options, MECO etc. Just follow comments
2. Ckeck boot_Sirocco#_upperstage.ks for overall launch configuration such as Orbit Altitude, Inclination, LAN

### Launch:
0. If you decide to use landing site difference from the Launch site (barge as an example) - select it as target.
1. Hit Abort to start launch sequence. Both terminals will open. First one for 1st stage, booster and second one for upper stage. 
2. Depending of your orbital parameters script will wait for launch window (inclination and LAN). As soon it became reasonable close to ideal time - 10 seconds launch sequence will begin. Remeber, that inclination may be not less than launch site latitude.

Ascending, 1st stage:
1. After lift-off script wait until rocket will hit 60m/s and start pitching over. After passing 100m/s auto-throttle will start reduce throttle leveler to reach optimum airspeed during initial ascending up to 10 km to reduce air drag looses. 
2. Keep your eyes on MECO sections - when Fuel cut-off amount: reach Amount of fuel left: script will cut-off main engines and start staging sequence. During that moment you may switch from upper stage to booster and leave upper stage continue ascending in fully automatic mode up to Apoapsis. Booster for returning back to launch site (or landing at barge etc) REQUIRED to keep you focused (active vessel) on 1st stage (requirements came from Trajectories mod states). Normally upper stage will reach Apoapsis and need your attentions in couple of minutes, so you have enough time to follow Booster and switch to Upper stage after booster successfully landed. Anyway, I’m strongly recommend to use FMRS mod to be able switch between two stages.

Returning of 1st stage "Booster" to the launch or other landing site:
1. After separation, Booster will flip over, point to the launch site and start burning with central engine only. After this burn, fuel tank usually mostly empty, except just a few drops (120-160 units). In normal condition it’s enough to pointing with RCS and for suicide burn just at the landing site. If no - check your parameters in boot_Sirocco#_booster.ks at MECO section. 
2. During descend script will use only aerodynamics, no RCS. Normally Booster will pointing in right direction and start gliding at 35-40km altitude. During descend Booster will oscillating but keeping TargetDist in reasonable numbers (start with 500m and 10-15 at the end). If you want to reduce this oscillating etc - play with numbers in PID-loop section of Sirocco_booster.ks
3. Below 2000m ("safe_altitude" in boot_sirocco_booster.ks) script will start control vertical speed and switch on precision landing guidance mode - LaserMod will start measurement distance between rocket and surface. You have to know, that this Laser DO NOT measure distance to the WATER, so in case of barge landing your Booster should be above landing site at that moment. 
4. After touch down, script will shutdown engine, reset to default settings KUniverse and halt.

Upper stage:
1. After separation, will burn up to reach desired Apoapsis and cut-off engine. During coasting above atmosphere it may loose a bit velocity but will restore it above 70km.
2. While Upper stage coasting above atmosphere you may use WARP (check script at that section). Script will calculate estimate data for burn at Apo regarding keeping to parameters - inclination and altitude.
3. During this burn script will continuously calculate desired pitch to preserve altitude. After complete script will shut down.
	
Built in the VAB in KSP version 1.2.2.

This script use a lot of parts of codes from other authors which clearly mark it you are free to use part or whole script for your own purposes. Same mark I would like to set here, on this project - you are free to download, change a bit, rewrite it all or use it to inspire yourself! During this project I spent a lot of time with fun and learning a lot of new staff for me.
If you have any questions, suggestions - please write it in the comment sections!
