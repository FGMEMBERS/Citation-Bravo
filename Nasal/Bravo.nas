var FDM=0;
var FDMjsb = 0;
var ViewNum=0;
var SndIn = props.globals.getNode("/sim/sound/Cvolume",1);
var SndOut = props.globals.getNode("/sim/sound/Ovolume",1);
var Grd_Idle=1;
var Annun = props.globals.getNode("instrumentation/annunciators",1);
var MstrWarn =Annun.getNode("master-warning",1);
var MstrCaution = Annun.getNode("master-caution",1);
var PWR2 =0;

aircraft.light.new("instrumentation/annunciators", [0.5, 0.5], MstrCaution);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10);
FHmeter.stop();


var cabin_door = aircraft.door.new("/controls/cabin-door", 2);

setlistener("/sim/signals/fdm-initialized", func {
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.15);
    MstrWarn.setBoolValue(0);
    MstrCaution.setBoolValue(0);
    setprop("/instrumentation/clock/flight-meter-hour",0);
    if(getprop("/sim/flight-model")=="jsb"){FDMjsb=1;}
    setprop("/sim/model/start-idling",0);
    setprop("controls/engines/N1-limit",94.0);
    Grd_Idle=getprop("controls/engines/throttle_idle");
    settimer(update_systems,2);
});

setlistener("/sim/model/start-idling", func(idle){
    var run= idle.getBoolValue();
    if(run){
    Startup();
    }else{
    Shutdown();
    }
},0,0);

setlistener("/controls/engines/throttle_idle", func(gidle){
    var gi= gidle.getBoolValue();
    if(gi){
    Grd_Idle=1;
    }else{
    Grd_Idle=0;
    }
},1,0);

setlistener("controls/gear/gear-down", func(grlock){
    var glk= grlock.getBoolValue();
    if(!glk){
    var GLH =getprop("gear/gear[1]/wow");
    var GRH =getprop("gear/gear[2]/wow");
    if(GLH or GRH)setprop("controls/gear/gear-down",1);
    }
},0,0);

setlistener("/sim/current-view/view-number", func(vw){
    ViewNum= vw.getValue();
    if(ViewNum ==0){
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.15);
    }else{
    SndIn.setDoubleValue(0.15);
    SndOut.setDoubleValue(0.75);
    }
},1,0);

setlistener("/gear/gear[1]/wow", func(gr){
    if(gr.getBoolValue()){
    FHmeter.stop();
    Grd_Idle=getprop("/controls/engines/throttle_idle");
    ET.stop();
    }else{
        FHmeter.start();
        ET.start();
        Grd_Idle=0;
            }
},0,0);

setlistener("/controls/engines/engine[0]/starter", func(st1){
    if(st1.getBoolValue()){
        if(getprop("/controls/engines/engine[0]/ignition") !=0){
            setprop("/sim/model/Bravo/start-cycle[0]",1);
        }else{
        setprop("/sim/model/Bravo/start-cycle[0]",0);
        }
    }
},0,0);

setlistener("/controls/engines/engine[1]/starter", func(st2){
    if(st2.getBoolValue()){
        if(getprop("/controls/engines/engine[1]/ignition") !=0){
    setprop("/sim/model/Bravo/start-cycle[1]",1);
    }else{
        setprop("/sim/model/Bravo/start-cycle[1]",0);
        }
    }
},0,0);

setlistener("/sim/model/Bravo/start-cycle[0]", func(cy1){
    var c1=cy1.getBoolValue();
    if(c1){
        setprop("/instrumentation/annunciators/LHign",1);
        setprop("/instrumentation/annunciators/fuel-boost",1);
    }else{
        setprop("/instrumentation/annunciators/LHign",0);
        setprop("/instrumentation/annunciators/fuel-boost",0);
    }
},0,0);

setlistener("/sim/model/Bravo/start-cycle[1]", func(cy2){
    var c2=cy2.getBoolValue();
    if(c2){
        setprop("/instrumentation/annunciators/RHign",1);
        setprop("/instrumentation/annunciators/fuel-boost",1);
    }else{
        setprop("/instrumentation/annunciators/RHign",0);
        setprop("/instrumentation/annunciators/fuel-boost",0);
    }
},0,0);

setlistener("/controls/gear/antiskid", func(as){
    var test=as.getBoolValue();
    if(!test){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("antiskid").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("antiskid").setBoolValue(0);
    }
},0,0);

setlistener("/sim/freeze/fuel", func(ffr){
    var test=ffr.getBoolValue();
    if(test){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("fuel-gauge").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("fuel-gauge").setBoolValue(0);
    }
},0,0);

setlistener("/controls/engines/engine[0]/ignition", func(ig1){
    var ign=ig1.getValue();
    if(ign == 0){
    setprop("/controls/engines/engine[0]/cutoff",1);
    }
},0,0);

setlistener("/controls/engines/engine[1]/ignition", func(ig2){
    var ign=ig2.getValue();
    if(ign == 0){
    setprop("/controls/engines/engine[1]/cutoff",1);
    }
},0,0);



var annunciators_loop = func{
var Tfuel = getprop("/consumables/fuel/total-fuel-lbs");
if(Tfuel != nil){
if( Tfuel< 400){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("fuel-lo").setBoolValue(1 * PWR2);
}else{
        Annun.getNode("fuel-lo").setBoolValue(0);
        }
    }

if(getprop("/gear/gear[0]/position-norm") == 1.0){
    Annun.getNode("gear-N").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gear-N").setBoolValue(0);
}

if(getprop("/gear/gear[1]/position-norm") == 1.0){
    Annun.getNode("gear-L").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gear-L").setBoolValue(0);
}

if(getprop("/gear/gear[2]/position-norm") == 1.0){
    Annun.getNode("gear-R").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gear-R").setBoolValue(0);
}



if(getprop("/controls/electric/engine[0]/generator") == 0){
    MstrWarn.setBoolValue(1 * PWR2);
    Annun.getNode("gen-off").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gen-off").setBoolValue(0);
}

if(getprop("/controls/electric/engine[1]/generator") == 0){
    MstrWarn.setBoolValue(1 * PWR2);
    Annun.getNode("gen-off").setBoolValue(1 * PWR2);
    }else{
    Annun.getNode("gen-off").setBoolValue(0);
}

if(getprop("/systems/electrical/ac-volts") < 5){
    MstrWarn.setBoolValue(1 * PWR2);
    Annun.getNode("ac-fail").setBoolValue(1 * PWR2);
    Annun.getNode("invtr-fail").setBoolValue(1 * PWR2);
}else{
    Annun.getNode("ac-fail").setBoolValue(0);
    Annun.getNode("invtr-fail").setBoolValue(0);
        }

if(getprop("/sim/model/Bravo/n1") < 40){
    Annun.getNode("fuel-psi").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-flow").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-psi").setBoolValue(1 * PWR2);
    Annun.getNode("stby-ps-htr").setBoolValue(1 * PWR2);
    Annun.getNode("aoa-htr").setBoolValue(1 * PWR2);
    Annun.getNode("ps-htr").setBoolValue(1 * PWR2);
}else{
        Annun.getNode("fuel-psi").setBoolValue(0);
        Annun.getNode("hyd-flow").setBoolValue(0);
        Annun.getNode("hyd-psi").setBoolValue(0);
        Annun.getNode("stby-ps-htr").setBoolValue(0);
        Annun.getNode("aoa-htr").setBoolValue(0);
        Annun.getNode("ps-htr").setBoolValue(0);
        }

if(getprop("/sim/model/Bravo/n1[1]") < 40){
    Annun.getNode("fuel-psi").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-flow").setBoolValue(1 * PWR2);
    Annun.getNode("hyd-psi").setBoolValue(1 * PWR2);
}else{
        Annun.getNode("fuel-psi").setBoolValue(0);
        Annun.getNode("hyd-flow").setBoolValue(0);
        Annun.getNode("hyd-psi").setBoolValue(0);
        }

    Annun.getNode("grnd-idle").setBoolValue(Grd_Idle * PWR2);

var spdbrk = getprop("/surface-positions/speedbrake-pos-norm");
if(spdbrk> 0.0){
    Annun.getNode("hyd-psi").setBoolValue(1 * PWR2);
    if(spdbrk == 1.0){
        Annun.getNode("spd-brk").setBoolValue(1 * PWR2);
        Annun.getNode("hyd-psi").setBoolValue(0);
    }
}else{
        Annun.getNode("hyd-psi").setBoolValue(0);
        Annun.getNode("spd-brk").setBoolValue(0);
        }

if(getprop("/controls/cabin-door/position-norm") != 0.0){
    MstrCaution.setBoolValue(1 * PWR2);
    Annun.getNode("cabin-door").setBoolValue(1 * PWR2);
    Annun.getNode("door-seal").setBoolValue(1 * PWR2);
    }else{
        Annun.getNode("cabin-door").setBoolValue(0);
        Annun.getNode("door-seal").setBoolValue(0);
        }
}

var flight_meter = func{
var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
var fminute = fmeter * 0.016666;
var fhour = fminute * 0.016666;
setprop("/instrumentation/clock/flight-meter-hour",fhour);
}

var Startup = func{
setprop("controls/electric/engine[0]/generator",1);
setprop("controls/electric/engine[1]/generator",1);
setprop("controls/electric/avionics-switch",1);
setprop("controls/electric/battery-switch",1);
setprop("controls/electric/inverter-switch",1);
setprop("controls/lighting/instrument-lights",1);
setprop("controls/lighting/nav-lights",1);
setprop("controls/lighting/beacon",1);
setprop("controls/lighting/strobe",1);
setprop("controls/engines/engine[0]/cutoff",0);
setprop("controls/engines/engine[1]/cutoff",0);
setprop("controls/engines/engine[0]/ignition",1);
setprop("controls/engines/engine[1]/ignition",1);
setprop("engines/engine[0]/running",1);
setprop("engines/engine[1]/running",1);
setprop("controls/engines/throttle_idle",1);
}

var Shutdown = func{
setprop("controls/electric/engine[0]/generator",0);
setprop("controls/electric/engine[1]/generator",0);
setprop("controls/electric/avionics-switch",0);
setprop("controls/electric/battery-switch",0);
setprop("controls/electric/inverter-switch",0);
setprop("controls/lighting/instrument-lights",1);
setprop("controls/lighting/nav-lights",0);
setprop("controls/lighting/beacon",0);
setprop("controls/lighting/strobe",0);
setprop("controls/engines/engine[0]/cutoff",1);
setprop("controls/engines/engine[1]/cutoff",1);
setprop("controls/engines/engine[0]/ignition",0);
setprop("controls/engines/engine[1]/ignition",0);
setprop("engines/engine[0]/running",0);
setprop("engines/engine[1]/running",0);
}

var update_systems = func{
var gr1=getprop("gear/gear[0]/position-norm");
var gr2=getprop("gear/gear[1]/position-norm");
var gr3=getprop("gear/gear[2]/position-norm");

var GrWrn = 0;
var Ghorn = 0;
var GLock = 0;
    PWR2 =0;
    if(getprop("systems/electrical/volts") > 2.0)PWR2=1;

    var THR = getprop("/controls/engines/engine/throttle");
    var THR1 = getprop("/controls/engines/engine[1]/throttle");
    if(Grd_Idle==0){
        THR=THR*0.92 +0.080;THR1=THR1*0.92 +0.080;
        }else{
        THR=THR*0.92;THR1=THR1*0.92;
        }
    
    if(!getprop("/controls/engines/engine/cutoff")){
        setprop("/controls/engines/engine/throttle-lever",THR);
        setprop("/sim/model/Bravo/n1[0]",getprop("/engines/engine/n1"));
        setprop("/sim/model/Bravo/n2[0]",getprop("/engines/engine/n2"));
    }else{
        setprop("controls/engines/engine/throttle-lever",0);
        interpolate("/sim/model/Bravo/n1[0]",0,10);
        interpolate("/sim/model/Bravo/n2[0]",0,10);
    }

    if(!getprop("/controls/engines/engine[1]/cutoff")){
        setprop("/controls/engines/engine[1]/throttle-lever",THR1);
        setprop("/sim/model/Bravo/n1[1]",getprop("/engines/engine[1]/n1"));
        setprop("/sim/model/Bravo/n2[1]",getprop("/engines/engine[1]/n2"));
    }else{
        setprop("/controls/engines/engine[1]/throttle-lever",0);
        interpolate("/sim/model/Bravo/n1[1]",0,10);
        interpolate("/sim/model/Bravo/n2[1]",0,10);
    }

if(getprop("/sim/model/Bravo/start-cycle[0]")){
    interpolate("/sim/model/Bravo/n1[0]",50.0,5);
    interpolate("/sim/model/Bravo/n2[0]",45.5,5);
    if(getprop("/sim/model/Bravo/n1[0]") > 49.0){
        setprop("/controls/engines/engine[0]/cutoff",0);
        setprop("/sim/model/Bravo/start-cycle[0]",0);
    }
}

if(getprop("/sim/model/Bravo/start-cycle[1]")){
    interpolate("/sim/model/Bravo/n1[1]",50.0,5);
    interpolate("/sim/model/Bravo/n2[1]",45.5,5);
    if(getprop("/sim/model/Bravo/n1[1]") > 49.0){
        setprop("/controls/engines/engine[1]/cutoff",0);
        setprop("/sim/model/Bravo/start-cycle[1]",0);
    }
}

if(gr1 != 1.0)GrWrn =1;
if(gr2 != 1.0)GrWrn =1;
if(gr3 != 1.0)GrWrn =1;

if(GrWrn ==1){
    if(getprop("engines/engine/n2")<70 or getprop("engines/engine[1]/n2")<70){
        if(getprop("velocities/airspeed-kt") < 150)Ghorn =1;
    }
    if(getprop("/surface-positions/flap-pos-norm") > 0.5)Ghorn =1;

if(gr1 != 0.0)GLock =1;
if(gr2 != 0.0)GLock =1;
if(gr3 != 0.0)GLock =1;
}

setprop("instrumentation/annunciators/gear-unlocked",GLock);
setprop("instrumentation/alerts/gear-horn",Ghorn);

annunciators_loop();
flight_meter();
settimer(update_systems,0);
}

var gearDown = func(v) {
    if(!getprop("gear/gear[1]/wow") or !getprop("gear/gear[2]/wow")){
        if (v < 0) {
        setprop("/controls/gear/gear-down", 0);
        } elsif (v > 0) {
        setprop("/controls/gear/gear-down", 1);
        }
    }
}