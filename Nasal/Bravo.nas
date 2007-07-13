var FDM=0;
var FDMjsb = 0;
var ViewNum=0;
var SndIn = props.globals.getNode("/sim/sound/Cvolume",1);
var SndOut = props.globals.getNode("/sim/sound/Ovolume",1);

var Annun = props.globals.getNode("instrumentation/annunciator",1);
var MstrWarn =props.globals.getNode("instrumentation/annunciator/master-warning",1);
var MstrCaution = props.globals.getNode("instrumentation/annunciator/master-caution",1);

aircraft.light.new("instrumentation/annunciator", [0.5, 0.5], MstrCaution);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10);
FHmeter.stop();

var cabin_door = aircraft.door.new("/controls/cabin-door", 2);

setlistener("/sim/signals/fdm-initialized", func {
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.15);
    MstrWarn.setBoolValue(0);
    MstrCaution.setBoolValue(0);
    Annun.getNode("batt",1).setBoolValue(0);
    Annun.getNode("ac-fail",1).setBoolValue(0);
    Annun.getNode("fire-det-fail",1).setBoolValue(0);
    Annun.getNode("oil-fltr-bp",1).setBoolValue(0);
    Annun.getNode("fuel-gauge",1).setBoolValue(0);
    Annun.getNode("fuel-boost",1).setBoolValue(0);
    Annun.getNode("oil-fltr-bp",1).setBoolValue(0);
    Annun.getNode("fuel-lo",1).setBoolValue(0);
    Annun.getNode("lo-fuel-psi",1).setBoolValue(0);
    Annun.getNode("fuel-fltr-bp",1).setBoolValue(0);
    Annun.getNode("gen-off",1).setBoolValue(0);
    Annun.getNode("invtr-fail",1).setBoolValue(0);
    Annun.getNode("antiskid",1).setBoolValue(0);
    setprop("/instrumentation/clock/flight-meter-hour",0);
    Annun.getNode("grnd-idle",1).setBoolValue(1);
    Annun.getNode("spd-brk",1).setBoolValue(0);
    Annun.getNode("hyd-flow",1).setBoolValue(0);
    Annun.getNode("hyd-psi",1).setBoolValue(0);
    Annun.getNode("cabin-door",1).setBoolValue(0);
    if(getprop("/sim/flight-model")=="jsb"){FDMjsb=1;}
    settimer(update_systems,1);
});

setlistener("/sim/current-view/view-number", func {
    ViewNum= cmdarg().getValue();
    if(ViewNum ==0){
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.15);
    }else{
    SndIn.setDoubleValue(0.15);
    SndOut.setDoubleValue(0.75);
    }
});

setlistener("/gear/gear[1]/wow", func {
    if(cmdarg().getBoolValue()){
    FHmeter.stop();
    }else{FHmeter.start();}
});

setlistener("/controls/engines/engine[0]/starter", func {
    if(cmdarg().getBoolValue()){
        if(getprop("/systems/electrical/volts") > 15){
    setprop("/sim/model/Bravo/start-cycle[0]",1);
    }else{
        setprop("/sim/model/Bravo/start-cycle[0]",0);
        }
    }
});

setlistener("/controls/engines/engine[1]/starter", func {
    if(cmdarg().getBoolValue()){
        if(getprop("/systems/electrical/volts") > 15){
    setprop("/sim/model/Bravo/start-cycle[1]",1);
    }else{
        setprop("/sim/model/Bravo/start-cycle[1]",0);
        }
    }
});

setlistener("/sim/model/Bravo/start-cycle[0]", func {
    if(cmdarg().getBoolValue()){
        setprop("/controls/engines/engine[0]/ignition",1);
        setprop("/instrumentation/annunciator/fuel-boost",1);
    }else{
        setprop("/controls/engines/engine[0]/ignition",0);
        setprop("/instrumentation/annunciator/fuel-boost",0);
    }
});

setlistener("/sim/model/Bravo/start-cycle[1]", func {
    if(cmdarg().getBoolValue()){
        setprop("/controls/engines/engine[1]/ignition",1);
        setprop("/instrumentation/annunciator/fuel-boost",1);
    }else{
        setprop("/controls/engines/engine[1]/ignition",0);
        setprop("/instrumentation/annunciator/fuel-boost",0);
    }
});

setlistener("/controls/electric/engine/generator", func {
    var test=cmdarg().getBoolValue();
    if(!test){
    MstrWarn.setBoolValue(1);
    Annun.getNode("gen-off").setBoolValue(1);
    }else{
    Annun.getNode("gen-off").setBoolValue(0);
    }
});

setlistener("/controls/electric/engine[0]/generator", func {
    var test=cmdarg().getBoolValue();
    if(!test){
    MstrWarn.setBoolValue(1);
    Annun.getNode("gen-off").setBoolValue(1);
    }else{
    Annun.getNode("gen-off").setBoolValue(0);
    }
});

setlistener("/controls/gear/antiskid", func {
    var test=cmdarg().getBoolValue();
    if(!test){
    MstrCaution.setBoolValue(1);
    Annun.getNode("antiskid").setBoolValue(1);
    }else{
    Annun.getNode("antiskid").setBoolValue(0);
    }
});

setlistener("/sim/freeze/fuel", func {
    var test=cmdarg().getBoolValue();
    if(test){
    MstrCaution.setBoolValue(1);
    Annun.getNode("fuel-gauge").setBoolValue(1);
    }else{
    Annun.getNode("fuel-gauge").setBoolValue(0);
    }
});


annunciators_loop = func{

if(getprop("/consumables/fuel/total-fuel-lbs") < 400){
    MstrCaution.setBoolValue(1);
    Annun.getNode("fuel-lo").setBoolValue(1);
}else{
        Annun.getNode("fuel-lo").setBoolValue(0);
        }


if(props.globals.getNode("/systems/electrical/ac-volts").getValue() ==0){
    MstrWarn.setBoolValue(1);
    Annun.getNode("ac-fail").setBoolValue(1);
    Annun.getNode("invtr-fail").setBoolValue(1);
}else{
    Annun.getNode("ac-fail").setBoolValue(0);
    Annun.getNode("invtr-fail").setBoolValue(0);
        }

if(getprop("/sim/model/Bravo/n1") < 30){
    Annun.getNode("lo-fuel-psi").setBoolValue(1);
    Annun.getNode("hyd-flow").setBoolValue(1);
    Annun.getNode("hyd-psi").setBoolValue(1);
}else{
        Annun.getNode("lo-fuel-psi").setBoolValue(0);
        Annun.getNode("hyd-flow").setBoolValue(0);
        Annun.getNode("hyd-psi").setBoolValue(0);
        }

if(getprop("/sim/model/Bravo/n1[1]") < 30){
    Annun.getNode("lo-fuel-psi").setBoolValue(1);
    Annun.getNode("hyd-flow").setBoolValue(1);
    Annun.getNode("hyd-psi").setBoolValue(1);
}else{
        Annun.getNode("lo-fuel-psi").setBoolValue(0);
        Annun.getNode("hyd-flow").setBoolValue(0);
        Annun.getNode("hyd-psi").setBoolValue(0);
        }

    Annun.getNode("grnd-idle").setBoolValue(props.globals.getNode("gear/gear[1]/wow").getBoolValue());

if(props.globals.getNode("/surface-positions/speedbrake-pos-norm").getValue() == 1){
    Annun.getNode("spd-brk").setBoolValue(1);
}else{
        Annun.getNode("spd-brk").setBoolValue(0);
        }

if(getprop("/controls/cabin-door/position-norm") != 0.0){
    MstrCaution.setBoolValue(1);
    Annun.getNode("cabin-door").setBoolValue(1);
}else{
        Annun.getNode("cabin-door").setBoolValue(0);
        }


}

flight_meter = func{
var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
var fminute = fmeter * 0.016666;
var fhour = fminute * 0.016666;
setprop("/instrumentation/clock/flight-meter-hour",fhour);
}

update_systems = func{
    if(!getprop("/controls/engines/engine/cutoff")){
        setprop("/controls/engines/engine/throttle-lever",getprop("/controls/engines/engine/throttle"));
        setprop("/sim/model/Bravo/n1[0]",getprop("/engines/engine/n1"));
    }else{
        setprop("controls/engines/engine/throttle-lever",0);
        interpolate("/sim/model/Bravo/n1[0]",0,10);
    }

    if(!getprop("/controls/engines/engine[1]/cutoff")){
        setprop("/controls/engines/engine[1]/throttle-lever",getprop("controls/engines/engine[1]/throttle"));
        setprop("/sim/model/Bravo/n1[1]",getprop("/engines/engine[1]/n1"));
    }else{
        setprop("/controls/engines/engine[1]/throttle-lever",0);
        interpolate("/sim/model/Bravo/n1[1]",0,10);
    }

if(getprop("/sim/model/Bravo/start-cycle[0]")){
    interpolate("/sim/model/Bravo/n1[0]",55.0,6);
    if(getprop("/sim/model/Bravo/n1[0]") > 54.0){
        setprop("/controls/engines/engine[0]/cutoff",0);
        setprop("/controls/engines/engine[0]/ignition",0);
        setprop("/sim/model/Bravo/start-cycle[0]",0);
    }
}

if(getprop("/sim/model/Bravo/start-cycle[1]")){
    interpolate("/sim/model/Bravo/n1[1]",55.0,6);
    if(getprop("/sim/model/Bravo/n1[1]") > 54.0){
        setprop("/controls/engines/engine[1]/cutoff",0);
        setprop("/controls/engines/engine[1]/ignition",0);
        setprop("/sim/model/Bravo/start-cycle[1]",0);
    }
}



annunciators_loop();
flight_meter();
settimer(update_systems,0);
}