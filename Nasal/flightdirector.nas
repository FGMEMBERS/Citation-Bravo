#############################################################################
# Flight Director/Autopilot controller.
#Syd Adams
#############################################################################

# 0 - Off: v-bars hidden
# lnav -0=W-LVL,1=HDG,2=VOR,3=LOC,4=LNAV,5=VAPP,6=BC
# vnav - 0=PIT,1=ALT,2=ASEL,3=GA,4=GS, 5= VNAV,6 = VS,7=FLC
var MTR2KT=0.000539956803;
var GPS_CDI=props.globals.getNode("/instrumentation/gps/cdi-deflection",1);
var GO = 0;
var alt_select = 0.0;
var current_alt=0.0;
var current_heading = 0.0;
var lnav = 0.0;
var vnav = 0.0;
var spd = 0.0;
var alt_alert = 0.0;
var course = 0.0;
var lp = aircraft.lowpass.new(0.5);

lnav_text=["wing-leveler","dg-heading-hold","nav1-hold","nav1-hold","true-heading-hold","nav1-hold","nav1-hold"];
vnav_text=["pitch-hold","altitude-hold","altitude-hold","pitch-hold","gs1-hold","pitch-hold","vertical-speed-hold","altitude-hold"];
var mag_offset=0;
var lMode=[" ","HDG","VOR","LOC","LNAV","VAPP","BC"];
var vMode=[" ","ALT","ASEL","GA","GS","VNAV","VS","FLC"];
var FMS = props.globals.getNode("/instrumentation/primus1000/dc550",1);
AP_hdg = props.globals.getNode("/autopilot/locks/heading",1);
AP_alt = props.globals.getNode("/autopilot/locks/altitude",1);
AP_spd = props.globals.getNode("/autopilot/locks/speed",1);
AP_lnav = props.globals.getNode("/instrumentation/flightdirector/lnav",1);
FD_deflection = props.globals.getNode("/instrumentation/flightdirector/crs-deflection",1);
FD_heading = props.globals.getNode("/instrumentation/flightdirector/hdg-deg",1);
FD_pitch = props.globals.getNode("/instrumentation/flightdirector/Pitch",1);
FD_roll = props.globals.getNode("/instrumentation/flightdirector/Roll",1);
HDG_deflection = props.globals.getNode("/instrumentation/nav/heading-needle-deflection",1);
AP_vnav = props.globals.getNode("/instrumentation/flightdirector/vnav",1);
AP_speed = props.globals.getNode("/instrumentation/flightdirector/spd",1);
AP_passive = props.globals.getNode("/autopilot/locks/passive-mode",1);
BC_btn = props.globals.getNode("/instrumentation/nav/back-course-btn",1); 
GPS_on = props.globals.getNode("/instrumentation/gps/serviceable",1);
WP1 = props.globals.getNode("/instrumentation/gps/wp/wp[1]",1);
RADIAL =props.globals.getNode("/instrumentation/nav/radials/selected-deg",1);
NAV_BRG = props.globals.getNode("/instrumentation/flightdirector/nav-mag-brg",1);

setlistener("/sim/signals/fdm-initialized", func {
    current_alt = props.globals.getNode("/instrumentation/altimeter/indicated-altitude-ft").getValue();
    alt_select = props.globals.getNode("/autopilot/settings/target-altitude-ft").getValue();
    AP_speed.setValue(0);
    AP_lnav.setValue(0);
    AP_vnav.setValue(0);
    AP_passive.setBoolValue(1);
    BC_btn.setValue(0);
    course = props.globals.getNode("/instrumentation/nav/radials/selected-deg").getValue();
    slaved = props.globals.getNode("/instrumentation/nav/slaved-to-gps").getBoolValue();
    props.globals.getNode("instrumentation/gps/wp/wp[0]/desired-course-deg").setValue(course);
    props.globals.getNode("instrumentation/gps/wp/wp[1]/desired-course-deg").setValue(course);
    GPS_on.setBoolValue(1);
    mag_offset=props.globals.getNode("/environment/magnetic-variation-deg").getValue();
    GO = 1;
    settimer(update, 2);
    print("Flight Director ...Check");
});

####    Mode Controller inputs    ####

setlistener("/instrumentation/flightdirector/lnav", func(ln){
    lnav = ln.getValue();
    var Vn=getprop("/instrumentation/flightdirector/vnav");
    if(Vn==nil){Vn=0;}
    if(lnav == 0 or lnav ==nil){
        BC_btn.setBoolValue(0);
    }
    if(lnav == 1){
        BC_btn.setBoolValue(0);
        if(Vn ==4 ){Vn = 0;}
    }
    if(lnav == 2){
        if(getprop("/instrumentation/primus1000/dc550/fms")){
        lnav=4;
        }
    }
    if(lnav == 3){BC_btn.setBoolValue(0);
        if(!getprop("instrumentation/nav/nav-loc")){
            lnav=2;
        }
    }
    if(lnav == 5){BC_btn.setBoolValue(0);
        if(getprop("instrumentation/nav/has-gs")){
            Vn=4;
        }
    }
    if(lnav == 6){BC_btn.setBoolValue(1);
        if(Vn==4){Vn = 0;}
    }
    AP_hdg.setValue(lnav_text[lnav]);
    setprop("instrumentation/flightdirector/lateral-mode",lMode[lnav]);
    setprop("instrumentation/flightdirector/vnav",Vn);
},0,0);

setlistener("/instrumentation/flightdirector/vnav", func(vn){
    vnav = vn.getValue();
    if(vnav == 4){
        if (!getprop("/instrumentation/nav/has-gs",1)){
            vnav = 0;
        }
    }
    if(vnav == 5){
        if (!getprop("/instrumentation/nav/has-gs",1)){
            vnav = 0;
        }else{
        setprop("/autopilot/settings/target-pitch-deg",0);
        }
    }
    AP_alt.setValue(vnav_text[vnav]);
    setprop("instrumentation/flightdirector/vertical-mode",vMode[vnav]);
},0,0);

setlistener("/instrumentation/flightdirector/spd", func(sp){
    spd = sp.getValue();
    if(spd == 0){AP_spd.setValue("");}
    if(spd == 1){AP_spd.setValue("speed-with-throttle");}
},0,0);

setlistener("/instrumentation/nav/radials/selected-deg", func(rd){
    course = rd.getValue();
    if(course == nil){course=0.0;}
    course += mag_offset;
    if(course >360){course -= 360;}
    props.globals.getNode("instrumentation/gps/wp/wp[0]/desired-course-deg").setValue(course);
    props.globals.getNode("instrumentation/gps/wp/wp[1]/desired-course-deg").setValue(course);
},0,0);

setlistener("/instrumentation/primus1000/dc550/fms", func(fms){
    var test =getprop("/instrumentation/flightdirector/lnav");
    var test1 =getprop("/instrumentation/flightdirector/vnav");
    if(fms.getBoolValue()){
        if(test ==2 or test==3){test=4;}
        if(test1 ==2){test1=1;}
    }else{
        if(test ==4){test=2;}
        if(test1 ==1){test1=2;}
    }
    setprop("/instrumentation/flightdirector/lnav",test);
    setprop("/instrumentation/flightdirector/vnav",test1);
},0,0);

var handle_inputs = func {
      
    var maxroll = getprop("/orientation/roll-deg");
    var maxpitch = getprop("/orientation/pitch-deg");

    if(maxroll > 45 or maxroll < -45)AP_passive.setBoolValue(1);
    if(maxpitch > 45 or maxpitch < -45)AP_passive.setBoolValue(1);
    if(getprop("/position/altitude-agl-ft") < 100)AP_passive.setBoolValue(1);



}

####    update nav gps or nav setting    ####

var update = func {
if(GO==0){return;}
    handle_inputs();
    settimer(update, 0); 
    }
