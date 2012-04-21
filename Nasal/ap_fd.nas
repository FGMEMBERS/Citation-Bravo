#############################################################################
# Flight Director/Autopilot controller.
# HDG:# Heading Bug hold - Low Bank can be selected
# NAV:# Arm & Capture VOR , LOC or FMS
# APR : (ILS approach)# Arm & Capture VOR APR , LOC or BC# Also arm and capture GS
# BC :# Arm & capture localizer backcourse# Nav also illuminates
# VNAV:# Arm and capture VOR/DME or FMS vertical profile# profile entered in MFD VNAV menu
# ALT:# Hold current Altitude or PFD preset altitude
# VS:# Hold current vertical speed# adjustable with pitch wheel
# SPD :# Hold current speed with pitch# adjustable with pitch wheel
#
#############################################################################
var count=0;
var count1=0;
var default_vertical="PIT";
var default_lateral="ROL";
var lateral=props.globals.getNode("autopilot/locks/heading");
var vertical=props.globals.getNode("autopilot/locks/altitude");
var nav_armed = props.globals.getNode("autopilot/locks/heading-armed");
var vrt_armed = props.globals.getNode("autopilot/locks/altitude-armed");
var bc_1 = props.globals.getNode("instrumentation/nav/back-course-btn");
var AP = props.globals.initNode("autopilot/locks/AP-status","","STRING");
var bank_limit=props.globals.initNode("autopilot/locks/bank-limit",27,"INT");
var bank_min=14;
var bank_max=27;
var AP_max_pitch=40;
var AP_min_pitch=-30;
var AP_max_roll=45;
var crs_cap_deg=5;
var NAVSRC= getprop("autopilot/locks/nav-src");

setlistener("/sim/signals/fdm-initialized", func {
    init();
    print("Flight Director ...Check");
    settimer(update_fd, 2);
});

setlistener("/sim/signals/reinit", func {
    init();
});

setlistener("autopilot/locks/nav-src",func(Nv){
    NAVSRC=Nv.getValue();
},1,0);

var init = func {
    setprop("autopilot/settings/target-altitude-ft",10000);
    setprop("autopilot/settings/heading-bug-deg",0);
    setprop("autopilot/settings/vertical-speed-fpm",0);
    setprop("autopilot/settings/target-pitch-deg",0);
}

var monitor_nav_armed = func{
    var Ntest =nav_armed.getValue();
        if(Ntest !=""){
            if(NAVSRC=="NAV1"){
                if(getprop("instrumentation/nav/in-range")){
                var dfl=math.abs(getprop("instrumentation/nav/heading-needle-deflection"));
                if(dfl < crs_cap_deg){
                    lateral.setValue(Ntest);
                    nav_armed.setValue("");
                    }
                }
            }elsif(NAVSRC=="NAV2"){
                if(getprop("instrumentation/nav[1]/in-range")){
                var dfl=math.abs(getprop("instrumentation/nav[1]/heading-needle-deflection"));
                if(dfl < crs_cap_deg){
                    lateral.setValue(Ntest);
                    nav_armed.setValue("");
                }
            }
        }
    }
}

var monitor_vrt_armed = func{
    var Vmd=vrt_armed.getValue();
    if( Vmd =="GS"){
        if(lateral.getValue()=="LOC"){
            if(getprop("instrumentation/nav/gs-in-range")){
                var cap = getprop("instrumentation/nav/gs-needle-deflection");
                if(cap < 1.0 and cap > -1.0){
                    vertical.setValue("GS");
                    vrt_armed.setValue("");
                }
            }
        }
    }elsif( Vmd =="ASEL"){
        var acap=12* getprop("velocities/vertical-speed-fps");
        acap=acap< 0 ?-acap : acap;
        var myalt=getprop("instrumentation/altimeter/indicated-altitude-ft");
        var altset = 100 * getprop("autopilot/settings/asel"); 
        var alt_test = myalt-altset;
        alt_test=alt_test< 0 ?-alt_test : alt_test;
        if(alt_test < acap){
            vertical.setValue("ALT");
            vrt_armed.setValue("");
        }
    }
}

var monitor_ap_limits = func{
    if(AP.getValue()=="AP ENG"){
        var roll = math.abs(getprop("orientation/roll-deg"));
        var pitch=getprop("orientation/pitch-deg");
        var DH = getprop("instrumentation/altimeter/dh");
        if(getprop("instrumentation/altimeter/indicated-altitude-ft")<DH)AP.setValue("AP FAIL");
        if(roll>AP_max_roll)AP.setValue("AP FAIL");
        if(pitch>AP_max_pitch or pitch < AP_min_pitch)AP.setValue("AP FAIL");
    }
}

var setRoll = func{
    lateral.setValue("ROL");
    setprop("autopilot/settings/target-roll-deg",0);
}

var setPitch = func{
    vertical.setValue("PIT");
    setprop("autopilot/settings/target-pitch-deg",getprop("orientation/pitch-deg"));
}

var pitchwheel = func(b){
    var dir = b;
    var md=vertical.getValue();

    if(md=="PIT"){
        var pt = getprop("autopilot/settings/target-pitch-deg");
        pt += dir * 0.1;
        if(pt>20)pt=20;
        if(pt<-10)pt=-10;
        setprop("autopilot/settings/target-pitch-deg",pt);
    }elsif(md=="VS"){
        var pt = getprop("autopilot/settings/vertical-speed-fpm");
        pt += dir * 100;
        if(pt>5000)pt=20;
        if(pt<-5000)pt=-10;
        setprop("autopilot/settings/vertical-speed-fpm",pt);
    }elsif(md=="IAS"){
        var pt = getprop("autopilot/settings/target-speed-kt");
        pt += dir;
        if(pt>350)pt=350;
        if(pt<120)pt=120;
        setprop("autopilot/settings/target-speed-kt",pt);
    }elsif(md=="MACH"){
        var pt = getprop("autopilot/settings/target-speed-mach");
        pt += dir;
        if(pt>0.90)pt=0.90;
        if(pt<0.40)pt=0.40;
        setprop("autopilot/settings/target-speed-mach",pt);
    }
}

### controller inputs   ###

var inputs = func(btn,mode){
    if(mode==0){
        var current_mode=lateral.getValue();
        if(btn=="hdg"){
            if(current_mode != "HDG")lateral.setValue("HDG") else setRoll();
        }
        if(btn=="nav"){
            if(NAVSRC=="NAV1"){
                if(getprop("instrumentation/nav/data-is-valid")){
                    if(getprop("instrumentation/nav/nav-loc"))nav_armed.setValue("LOC") else nav_armed.setValue("VOR");
                    lateral.setValue("HDG");
                }
            }elsif(NAVSRC=="NAV2"){
                if(getprop("instrumentation/nav[1]/data-is-valid")){
                    if(getprop("instrumentation/nav[1]/nav-loc"))nav_armed.setValue("LOC") else nav_armed.setValue("VOR");
                    lateral.setValue("HDG");
                }
            }elsif(NAVSRC=="FMS"){
                lateral.setValue("LNAV");
            }
        }
        if(btn=="bc"){
            if(current_mode == "LOC")bc_1.setValue(1- bc_1.getValue()) else bc_1.setValue(0);
        }
    }elsif(mode==1){
        var current_mode=vertical.getValue();
        if(btn=="spd"){
        var myalt= getprop("instrumentation/altimeter/indicated-altitude-ft");
        var myias= getprop("instrumentation/airspeed-indicator/indicated-speed-kt");
        var mymach= getprop("instrumentation/altimeter/indicated-mach");
            if(current_mode == ""){
                if(myalt>28900 and myias>120 ){
                    vertical.setValue("MACH");
                    setprop("autopilot/settings/target-speed-mach",mymach);
                }elsif(myalt<28900 and myias>120 ){
                    vertical.setValue("IAS");
                    setprop("autopilot/settings/target-speed-kt",myias);
                }
            }else{
                vertical.setValue("");
             }
        }
        if(btn=="vs"){
            if(current_mode != "VS"){
                vertical.setValue("VS");
                setprop("autopilot/settings/vertical-speed-fpm",int(getprop("instrumentation/vertical-speed-indicator/indicated-speed-fpm")));
            }else setPitch();
        }
        if(btn=="apr"){
            if(getprop("instrumentation/nav/data-is-valid") and getprop("instrumentation/nav/nav-loc")){
                if(getprop("instrumentation/nav/has-gs")){
                    nav_armed.setValue("LOC");
                    vrt_armed.setValue("GS");
                }
            }
        }
        if(btn=="alt"){
            if(current_mode != "ALT"){
                setprop("autopilot/settings/target-altitude-ft",getprop("instrumentation/altimeter/mode-c-alt-ft"));
                vertical.setValue("ALT")
            }else setPitch();
        }
        if(btn=="ga"){
            AP.setValue(0);
            lateral.setValue("LVL");
            vertical.setValue("GA");
        }
    }elsif(mode==2){
         if(btn=="test"){
            # test lights
        }
        if(btn=="ap"){
            var ap_stat=AP.getValue();
             setprop("autopilot/settings/target-pitch-deg",getprop("orientation/pitch-deg"));
            setprop("autopilot/settings/target-roll-deg",0);
            if(ap_stat !="AP ENG") {
                AP.setValue("AP ENG");
                setprop("autopilot/locks/yaw-damper",1);
            }else AP.setValue("");
        }
    }
}

var update_nav=func{
    var sgnl = "- - -";
    var gs =0;
    if(NAVSRC == "NAV1"){
        if(getprop("instrumentation/nav/data-is-valid"))sgnl="VOR1";
        setprop("autopilot/internal/in-range",getprop("instrumentation/nav/in-range"));
        setprop("autopilot/internal/gs-in-range",getprop("instrumentation/nav/gs-in-range"));
        var dst=getprop("instrumentation/nav/nav-distance") or 0;
        dst*=0.000539;
        setprop("autopilot/internal/nav-distance",dst);
        setprop("autopilot/internal/nav-id",getprop("instrumentation/nav/nav-id"));
        if(getprop("instrumentation/nav/nav-loc"))sgnl="LOC1";
        if(getprop("instrumentation/nav/has-gs"))sgnl="ILS1";
        if(sgnl=="ILS1")gs = 1;
        setprop("autopilot/internal/gs-valid",gs);
        setprop("autopilot/internal/nav-type",sgnl);
        course_offset("instrumentation/nav[0]/radials/selected-deg");
        setprop("autopilot/internal/to-flag",getprop("instrumentation/nav/to-flag"));
        setprop("autopilot/internal/from-flag",getprop("instrumentation/nav/from-flag"));
        setprop("autopilot/internal/cdi",getprop("instrumentation/nav/heading-needle-deflection"));
        setprop("autopilot/internal/gs-deflection",getprop("instrumentation/nav/gs-needle-deflection-norm"));
    }elsif(NAVSRC == "NAV2"){
        if(getprop("instrumentation/nav[1]/data-is-valid"))sgnl="VOR2";
        setprop("autopilot/internal/in-range",getprop("instrumentation/nav[1]/in-range"));
        setprop("autopilot/internal/gs-in-range",getprop("instrumentation/nav[1]/gs-in-range"));
        var dst=getprop("instrumentation/nav[1]/nav-distance") or 0;
        dst*=0.000539;
        setprop("autopilot/internal/nav-distance",dst);
        setprop("autopilot/internal/nav-id",getprop("instrumentation/nav[1]/nav-id"));
        if(getprop("instrumentation/nav[1]/nav-loc"))sgnl="LOC2";
        if(getprop("instrumentation/nav[1]/has-gs"))sgnl="ILS2";
        if(sgnl=="ILS2")gs = 1;
        setprop("autopilot/internal/gs-valid",gs);
        setprop("autopilot/internal/nav-type",sgnl);
        course_offset("instrumentation/nav[1]/radials/selected-deg");
        setprop("autopilot/internal/to-flag",getprop("instrumentation/nav[1]/to-flag"));
        setprop("autopilot/internal/from-flag",getprop("instrumentation/nav[1]/from-flag"));
        setprop("autopilot/internal/cdi",getprop("instrumentation/nav[1]/heading-needle-deflection"));
        setprop("autopilot/internal/gs-deflection",getprop("instrumentation/nav[1]/gs-needle-deflection-norm"));
    }elsif(NAVSRC == "FMS"){
        setprop("autopilot/internal/nav-type","FMS1");
        setprop("autopilot/internal/in-range",1);
        setprop("autopilot/internal/gs-in-range",0);
        setprop("autopilot/internal/nav-distance",getprop("/autopilot/route-manager/wp[0]/dist") or 0);
        setprop("autopilot/internal/nav-id",getprop("/autopilot/route-manager/wp[0]/id")  or "---");
        setprop("autopilot/internal/nav-ttw",getprop("/autopilot/route-manager/wp[0]/eta") or 0.0);
        course_offset("instrumentation/gps/wp/wp[1]/bearing-mag-deg");
        setprop("autopilot/internal/to-flag",getprop("instrumentation/gps/wp/wp[1]/to-flag"));
        setprop("autopilot/internal/from-flag",getprop("instrumentation/gps/wp/wp[1]/from-flag"));
        setprop("autopilot/internal/cdi",0);
        setprop("autopilot/internal/gs-deflection",0);
    }
}

var course_offset = func(src){
    var crs_set=getprop(src);
    var myhdg=getprop("orientation/heading-magnetic-deg");
    var crs_offset= crs_set - myhdg;
    if(crs_offset>180)crs_offset-=360 elsif(crs_offset<-180)crs_offset+=360;
    setprop("autopilot/internal/course-offset",crs_offset);
    crs_offset+=getprop("autopilot/internal/cdi") or 0;
    if(crs_offset>180)crs_offset-=360 elsif(crs_offset<-180)crs_offset+=360;
    setprop("autopilot/internal/ap_crs",crs_offset);
    setprop("autopilot/internal/selected-crs",crs_set);
}

var calc_pointer = func(num){
       var maghdg=getprop("orientation/heading-magnetic-deg");
    var ptr = getprop("instrumentation/dc550/navptr["~num~"]");
    var myhdg = 0;
    if(ptr==1){
        myhdg= getprop("instrumentation/nav["~num~"]/heading-deg") - getprop("orientation/heading-deg");
        if(myhdg>180)myhdg-=360;
        if(myhdg<-180)myhdg+=360;
     }elsif(ptr==2){
        myhdg= getprop("instrumentation/kr-87/outputs/needle-deg");
    }elsif(ptr==3){
        myhdg= getprop("instrumentation/gps/wp/wp[1]/bearing-mag-deg")-getprop("orientation/heading-magnetic-deg");
        if(myhdg>180)myhdg-=360;
        if(myhdg<-180)myhdg+=360;
    }
    setprop("autopilot/internal/nav-ptr["~num~"]",myhdg);
}

################################
var update_fd = func {
    if(count==0){
        monitor_ap_limits();
    }elsif(count==1){
        monitor_nav_armed();
    }elsif(count==2){
    monitor_vrt_armed();
    }elsif(count==3){
    update_nav();
    }
    count+=1;
    if(count>3)count=0;
    calc_pointer(count1);
    count1 = 1- count1;
    settimer(update_fd, 0);
}
