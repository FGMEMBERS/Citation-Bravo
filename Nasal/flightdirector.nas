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
#2=Nav Arm
#3=Nav Cap
#4=ARP Arm
#5=APR Cap,
#6=BC Arm
#7=BC Cap

# vnav
#- 0=PIT
# 1=VNAV Arm,
#2=VNAV Cap,
#3=ALT Arm
#4=ALT Cap
#5=VS
#6=GS

var lnav_text=["wing-leveler","dg-heading-hold","dg-heading-hold","nav1-hold","dg-heading-hold","nav1-hold","dg-heading-hold","nav1-hold"];
var vnav_text=["pitch-hold","pitch-hold","pitch-hold","pitch-hold","altitude-hold","vertical-speed-hold","gs1-hold"];

var FMS = 0;
var in_range=0;
var Defl = props.globals.getNode("/instrumentation/nav/heading-needle-deflection");
var GSDefl = props.globals.getNode("/instrumentation/nav/gs-needle-deflection");
var AP_hdg = props.globals.getNode("/autopilot/locks/heading",1);
var AP_alt = props.globals.getNode("/autopilot/locks/altitude",1);
var AP_spd = props.globals.getNode("/autopilot/locks/speed",1);
var FD_lnav = props.globals.getNode("/instrumentation/flightdirector/lnav");
var FD_vnav = props.globals.getNode("/instrumentation/flightdirector/vnav");
var FD_pitch = props.globals.getNode("/instrumentation/flightdirector/Pitch",1);
var FD_roll = props.globals.getNode("/instrumentation/flightdirector/Roll",1);
var FD_speed = props.globals.getNode("/instrumentation/flightdirector/spd",1);
var DH = props.globals.getNode("/autopilot/route-manager/min-lock-altitude-agl-ft",1);
var lnav=0;
var vnav=0;


setlistener("/sim/signals/fdm-initialized", func {
    AP_spd.setValue("");
    AP_hdg.setValue("wing-leveler");
    AP_alt.setValue("pitch-hold");
    FD_lnav.setValue(0);
    FD_vnav.setValue(0);
    setprop("/autopilot/locks/passive-mode",1);
    setprop("autopilot/settings/target-altitude-ft",0);
    props.globals.getNode("instrumentation/primus1000/dc550/fms",1).setBoolValue(0);
    FMS=0;
    settimer(update, 5);
    print("Flight Director ...Check");
});

####    FD Controller inputs    ####

setlistener("/instrumentation/flightdirector/lnav", func(ln){
lnav = ln.getValue();
set_lateral_mode();
},0,0);

setlistener("/instrumentation/flightdirector/vnav", func(vn){
vnav=vn.getValue();
set_vertical_mode();
},0,0);

var set_lateral_mode=func(){
if(FMS ==1){
    if(lnav ==2 or lnav ==3)AP_hdg.setValue("true-heading-hold");
    }else{
        AP_hdg.setValue(lnav_text[lnav]);
        }
}

var set_vertical_mode=func(){
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
    if(lnav ==2){
        if(deflection > -7 or deflection < 7){
            if(in_range==1){
            lnav = 3;
            }
        }
    FD_lnav.setValue(lnav);
    }

    if(lnav ==4){
        if(getprop("/instrumentation/nav/nav-loc")==0){
            lnav = 2;
        }else{
        if(deflection > -5 or deflection < 5){
                if(in_range==1)lnav = 5;
                }
            }
    FD_lnav.setValue(lnav);
    }

    if(lnav ==5){
        if(getprop("/instrumentation/nav/has-gs")!=0){
            if(gs_deflection  < 0.5 and gs_deflection > -1.0){
                if(in_range==1)vnav = 6;
                FD_vnav.setValue(vnav);
                }
            }
        }
    }


if(vnav == 3){
var TGALT = getprop("autopilot/settings/target-altitude-ft");
    if(TGALT > DH.getValue()){
        var MyAlt = getprop("position/altitude-ft");
            if(MyAlt > (TGALT -1000) or MyAlt < (TGALT +1000)){
                vnav=4;
                AP_alt.setValue(vnav_text[vnav]);
            }
        }
    }


settimer(update, 0); 
}
