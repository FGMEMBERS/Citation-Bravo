var FDM=0;
var FDMjsb = 0;
var ViewNum=0;
var SndIn = props.globals.getNode("/sim/sound/Cvolume",1);
var SndOut = props.globals.getNode("/sim/sound/Ovolume",1);

var Annun = props.globals.getNode("instrumentation/annunciator",1);
var MstrWarn =props.globals.getNode("instrumentation/annunciator/master-warning",1);
var MstrCaution = props.globals.getNode("instrumentation/annunciator/master-caution",1);

setlistener("/sim/signals/fdm-initialized", func {
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.15);
    MstrWarn.setBoolValue(0);
    MstrCaution.setBoolValue(0);
    Annun.getNode("fuel-lo",1).setBoolValue(0);
    Annun.getNode("grnd-idle",1).setBoolValue(1);
    Annun.getNode("spd-brk",1).setBoolValue(0);
    if(getprop("/sim/flight-model")=="jsb"){FDMjsb=1;}
    settimer(update,1);
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

annunciators = func() {
if(props.globals.getNode("/consumables/fuel/total-fuel-lbs").getValue() < 400){
    Annun.getNode("fuel-lo").setBoolValue(1);
}else{
        Annun.getNode("fuel-lo").setBoolValue(0);
        }

    Annun.getNode("grnd-idle").setBoolValue(props.globals.getNode("gear/gear[1]/wow").getBoolValue());

if(props.globals.getNode("/surface-positions/spoiler-pos-norm").getValue() == 1.0){
    Annun.getNode("spd-brk").setBoolValue(1);
}else{
        Annun.getNode("spd-brk").setBoolValue(0);
        }
}


update = func(){
annunciators();
settimer(update,0);
}