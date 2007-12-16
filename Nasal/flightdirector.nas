#############################################################################
# Flight Director/Autopilot controller.
# Syd Adams
# HDG:
# Heading Bug hold - Low Bank can be selected
#
# NAV:
# Arm & Capture VOR , LOC or FMS
#
# APR : (ILS approach)
# Arm & Capture VOR APR , LOC or BC
# Also arm and capture GS
#
# BC :
# Arm & capture localizer backcourse
# Nav also illuminates
#
# VNAV:
# Arm and capture VOR/DME or FMS vertical profile
# profile entered in MFD VNAV menu
#
# ALT:
# Hold current Altitude or PFD preset altitude
#
# VS:
# Hold current vertical speed
# adjustable with pitch wheel
#
# SPD :
# Hold current speed 
# adjustable with pitch wheel
#
#############################################################################

# lnav 
#0=W-LVL
#1=HDG,
#2=VOR Arm
#3=VOR Cap
#4=LOC Arm
#5=LOC Cap
#6=FMS Cap
#7=APR Arm
#8=BC Arm
#9=BC Cap

# vnav
#- 0=PIT
# 1=VNAV Arm,
#2=VNAV Cap,
#3=ALT hold
#4=ASEL
#5=VS
#6=GS Arm
#7=GS Cap


var lnav_text=["wing-leveler","dg-heading-hold","dg-heading-hold","nav1-hold","dg-heading-hold","nav1-hold","true-heading-hold","","dg-heading-hold","nav1-hold"];
var vnav_text=["pitch-hold","vs-hold","vs-hold","altitude-hold","vertical-speed-hold","vertical-speed-hold","","gs1-hold"];

var FMS = 0;
var lnav=0;
var vnav=0;
var in_range=0;
var Defl = props.globals.getNode("/instrumentation/nav/heading-needle-deflection");
var GSDefl = props.globals.getNode("/instrumentation/nav/gs-needle-deflection");
var AP_hdg = props.globals.getNode("/autopilot/locks/heading",1);
var AP_alt = props.globals.getNode("/autopilot/locks/altitude",1);
var AP_spd = props.globals.getNode("/autopilot/locks/speed",1);
var FD_lnav = props.globals.getNode("/instrumentation/flightdirector/lnav",1);
FD_lnav.setIntValue(0);
var FD_vnav = props.globals.getNode("/instrumentation/flightdirector/vnav",1);
FD_vnav.setIntValue(0);
var FD_pitch = props.globals.getNode("/instrumentation/flightdirector/Pitch",1);
var FD_roll = props.globals.getNode("/instrumentation/flightdirector/Roll",1);
var FD_asel = props.globals.getNode("/instrumentation/flightdirector/Asel",1);
var FD_speed = props.globals.getNode("/instrumentation/flightdirector/spd",1);
var DH = props.globals.getNode("/autopilot/route-manager/min-lock-altitude-agl-ft",1);


setlistener("/sim/signals/fdm-initialized", func {
    AP_spd.setValue("");
    AP_hdg.setValue(lnav_text[0]);
    AP_alt.setValue(vnav_text[0]);
    setprop("/autopilot/locks/passive-mode",1);
    setprop("autopilot/settings/target-altitude-ft",0);
    props.globals.getNode("instrumentation/primus1000/dc550/fms",1).setBoolValue(0);
    FMS=0;
    settimer(update, 5);
    print("Flight Director ...Check");
});

####    FD Controller inputs    ####
#### LATERAL MODE####
var set_lateral_mode=func{
    if(lnav==2){
        if(getprop("/instrumentation/nav/nav-loc")!=0)lnav=4;
        if(FMS==1)lnav = 6;
        }
    if(lnav==7){
    if(getprop("/instrumentation/nav/nav-loc")!=0){
        if(getprop("instrumentation/nav/has-gs"))FD_vnav.setValue(6);
        lnav=4;
        }else{
        lnav=2;
        }
    }
    FD_lnav.setValue(lnav);
    AP_hdg.setValue(lnav_text[lnav]);
}

#### VERTICAL MODE####
var set_vertical_mode=func{
setprop("autopilot/settings/vertical-speed-fpm",getprop("velocities/vertical-speed-fps") * 60);
setprop("autopilot/settings/target-pitch-deg",getprop("orientation/pitch-deg"));
if(vnav==3){
if(getprop("autopilot/settings/target-altitude-ft") < DH.getValue())vnav=0;
    }
if(vnav==6){
vnav_text[6]=getprop("autopilot/locks/altitude");
    }
FD_vnav.setValue(vnav);
AP_alt.setValue(vnav_text[vnav]);
}

setlistener("/instrumentation/primus1000/dc550/fms", func(fms){
    if(fms.getBoolValue()){
        FMS=1;
        }else{
        FMS=0;
        FD_lnav.setValue(0);
        FD_vnav.setValue(0);
        }
},0,0);

setlistener("/instrumentation/flightdirector/lnav", func(ln){
lnav=ln.getValue();
set_lateral_mode();
},0,0);

setlistener("/instrumentation/flightdirector/vnav", func(vn){
vnav=vn.getValue();
set_vertical_mode();
},0,0);


####    update nav gps or nav setting    ####

var update = func {

var dst = getprop("instrumentation/nav/nav-distance");
    if(dst == nil or dst >30000){
    in_range=0;
    }else{
    in_range=1;
    }
    
    var APoff = getprop("/autopilot/locks/passive-mode");
    if(APoff == 0){
    var maxroll = getprop("/orientation/roll-deg");
    var maxpitch = getprop("/orientation/pitch-deg");
    if(maxroll > 45 or maxroll < -45)APoff = 1;
    if(maxpitch > 45 or maxpitch < -45)APoff = 1;
    if(getprop("/position/altitude-agl-ft") < DH.getValue())APoff = 1;
    setprop("/autopilot/locks/passive-mode", APoff);
}


if(FMS==0){
    var deflection = Defl.getValue();
    var gs_deflection = GSDefl.getValue();
    var capture = 0;
    
    if(lnav ==2 or lnav==4){
        if(deflection > -7 or deflection < 7){
            if(in_range==1){
                lnav+=1;
                }
            }
        FD_lnav.setValue(lnav);
    }

    if(lnav ==5){
        if(vnav==6){
            if(gs_deflection  < 1.0 and gs_deflection > -1.0){
                if(in_range==1)vnav = 7;
                FD_vnav.setValue(vnav);
                }
            }
        }
    }


if(vnav == 4){
var TGALT = getprop("autopilot/settings/target-altitude-ft");
    if (TGALT > DH.getValue()){
    var MyAlt = getprop("position/altitude-ft");
        if(MyAlt > (TGALT -1000) or MyAlt < (TGALT +1000)){
            vnav=3;
            }
        }else{
        vnav=0;
        }
    AP_alt.setValue(vnav_text[vnav]);
    FD_vnav.setValue(vnav);
    }


settimer(update, 0); 
}
