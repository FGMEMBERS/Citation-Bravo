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
var slaved = 0;
lnav_text=["wing-leveler","dg-heading-hold","nav1-hold","nav1-hold","true-heading-hold","nav1-hold","nav1-hold"];
vnav_text=["pitch-hold","altitude-hold","altitude-hold","pitch-hold","gs1-hold","altitude-hold","vertical-speed-hold","altitude-hold"];
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
    settimer(update, 1);
    print("Flight Director ...Check");
});

####    Mode Controller inputs    ####

setlistener("/instrumentation/flightdirector/lnav", func {
    lnav = cmdarg().getValue();
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
});

setlistener("/instrumentation/flightdirector/vnav", func {
    vnav = cmdarg().getValue();
    if(vnav == 4){
        if (!getprop("/instrumentation/nav/has-gs",1)){
            vnav = 0;
        }
    }
    AP_alt.setValue(vnav_text[vnav]);
    setprop("instrumentation/flightdirector/vertical-mode",vMode[vnav]);
});

setlistener("/instrumentation/flightdirector/spd", func {
    spd = cmdarg().getValue();
    if(spd == 0){AP_spd.setValue("");}
    if(spd == 1){AP_spd.setValue("speed-with-throttle");}
});

setlistener("/instrumentation/nav/slaved-to-gps", func {
    slaved = cmdarg().getBoolValue();
});

setlistener("/instrumentation/nav/radials/selected-deg", func {
    course = cmdarg().getValue();
    if(course == nil){course=0.0;}
    course += mag_offset;
    if(course >360){course -= 360;}
    props.globals.getNode("instrumentation/gps/wp/wp[0]/desired-course-deg").setValue(course);
    props.globals.getNode("instrumentation/gps/wp/wp[1]/desired-course-deg").setValue(course);
},1);

setlistener("/instrumentation/primus1000/dc550/fms", func {
    var test =getprop("/instrumentation/flightdirector/lnav");
    var test1 =getprop("/instrumentation/flightdirector/vnav");
    if(cmdarg().getBoolValue()){
        if(test ==2 or test==3){test=4;}
        if(test1 ==2){test1=1;}
    }else{
        if(test ==4){test=2;}
        if(test1 ==1){test1=2;}
    }
    setprop("/instrumentation/flightdirector/lnav",test);
    setprop("/instrumentation/flightdirector/vnav",test1);
});

handle_inputs = func {
    var nm = 0.0;
    var hdg = 0.0;
    var nav_brg=0.0;
    var ap_hdg=0;
    var track =0;
    track =props.globals.getNode("/orientation/heading-deg").getValue();
    maxroll = props.globals.getNode("/orientation/roll-deg",1).getValue();
    if(maxroll > 45 or maxroll < -45){AP_passive.setBoolValue(1);}
    maxpitch = props.globals.getNode("/orientation/pitch-deg").getValue();
    if(maxpitch > 45 or maxpitch < -45){AP_passive.setBoolValue(1);}
    if(props.globals.getNode("/position/altitude-agl-ft").getValue() < 100){AP_passive.setBoolValue(1);}
    if(WP1.getNode("ID").getValue()!=nil){
            nm = WP1.getNode("course-error-nm").getValue();
            if(nm > 10){nm=10;}
            if(nm < -10){nm=-10;}
        }
    GPS_CDI.setValue(nm);
    hdg =RADIAL.getValue() + mag_offset;
    hdg-=track;
    if(hdg > 180){hdg-=360;}
    if(hdg < -180){hdg+=360;}
    if(slaved){
        FD_deflection.setValue(nm);
        nav_brg= WP1.getNode("bearing-true-deg").getValue();
        if(nav_brg == nil){nav_brg = 0.0;}
        }else{
            FD_deflection.setValue(HDG_deflection.getValue());
            nav_brg= props.globals.getNode("instrumentation/nav/heading-deg").getValue();
            if(nav_brg == nil){nav_brg = 0.0;}
            nav_brg+= mag_offset;
        }
    nav_brg -=track;
    if(nav_brg > 180){nav_brg -=360;}
    if(nav_brg < -180){nav_brg +=360;}
    NAV_BRG.setValue(nav_brg);
    ap_hdg = hdg +(FD_deflection.getValue() *4);
    if(ap_hdg > 180){ap_hdg -= 360;}
    if(ap_hdg < -180){ap_hdg += 360;}
    FD_heading.setValue(ap_hdg);
}

####    update nav gps or nav setting    ####

update = func {
if(GO==0){return;}
    handle_inputs();
    settimer(update, 0); 
    }
