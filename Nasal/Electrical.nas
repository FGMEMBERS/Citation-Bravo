####    Bravo electrical system    #### 
####    Syd Adams    ####
#### Based on Curtis Olson's nasal electrical code ####

var last_time = 0.0;
var ammeter_ave = 0.0;

var OutPuts = "/systems/electrical/outputs/";
var Volts = "/systems/electrical/volts";
var ACVolts = "/systems/electrical/ac-volts";
var Amps = "/systems/electrical/amps";
var BATT = "/controls/electric/battery-switch";
var INVTR = props.globals.getNode("/controls/electric/inverter-switch",1);
var L_ALT = "/controls/electric/engine[0]/generator";
var R_ALT = "/controls/electric/engine[1]/generator";
var EXT  = "/controls/electric/external-power";
var NORM = 0.0357;
var INSTR_DIMMER = props.globals.getNode("/controls/lighting/instruments-norm",1);
var EFIS_DIMMER = props.globals.getNode("/controls/lighting/efis-norm",1);
var ENG_DIMMER = props.globals.getNode("/controls/lighting/engines-norm",1);
var PANEL_DIMMER = props.globals.getNode("/controls/lighting/panel-norm",1);

var strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
aircraft.light.new("controls/lighting/strobe-state", [0.05, 1.30], strobe_switch);
var beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("controls/lighting/beacon-state", [1.0, 1.0], beacon_switch);

Battery = {
    new : func {
    m = { parents : [Battery] };
            m.ideal_volts = arg[0];
            m.ideal_amps = arg[1];
            m.amp_hours = arg[2];
            m.charge_percent = arg[3]; 
            m.charge_amps = arg[4];
    return m;
    },
    
    apply_load : func {
        var amphrs_used = arg[0] * arg[1] / 3600.0;
        percent_used = amphrs_used / me.amp_hours;
        me.charge_percent -= percent_used;
        if ( me.charge_percent < 0.0 ) {
            me.charge_percent = 0.0;
        } elsif ( me.charge_percent > 1.0 ) {
        me.charge_percent = 1.0;
        }
        return me.amp_hours * me.charge_percent;
    },

    get_output_volts : func {
    x = 1.0 - me.charge_percent;
    tmp = -(3.0 * x - 1.0);
    factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_volts * factor;
    },

    get_output_amps : func {
    x = 1.0 - me.charge_percent;
    tmp = -(3.0 * x - 1.0);
    factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_amps * factor;
    }
};	

Alternator = {
    new : func {
    m = { parents : [Alternator] };
            m.rpm_source =  props.globals.getNode(arg[0],1);
            m.rpm_threshold = arg[1];
            m.ideal_volts = arg[2];
            m.ideal_amps = arg[3];
          return m;
    },

    apply_load : func( amps, dt) {
    var factor = me.rpm_source.getValue() / me.rpm_threshold;
    if ( factor > 1.0 ){factor = 1.0;}
    available_amps = me.ideal_amps * factor;
    return available_amps - amps;
    },

    get_output_volts : func {
    var factor = me.rpm_source.getValue() / me.rpm_threshold;
    if ( factor > 1.0 ) {
        factor = 1.0;
        }
    return me.ideal_volts * factor;
    },

    get_output_amps : func {
    var factor = me.rpm_source.getValue() / me.rpm_threshold;
    if ( factor > 1.0 ) {
        factor = 1.0;
        }
    return me.ideal_amps * factor;
    }
};
#var battery = Battery.new(volts,amps,amp_hours,charge_percent,charge_amps);

var battery = Battery.new(24,44,44, 1.0,7.0);

# var alternator = Alternator.new("rpm-source",rpm_threshold,volts,amps);

var alternator1 = Alternator.new("/sim/model/Bravo/n2[0]",20.0,28.5,400.0);
var alternator2 = Alternator.new("/sim/model/Bravo/n2[1]",20.0,28.5,400.0);

#####################################
setlistener("/sim/signals/fdm-initialized", func {
    setprop("systems/electrical/battery-temp", getprop("/environment/temperature-degf"));
    setprop(ACVolts,0);
    settimer(update_electrical,0);
    print("Electrical System ... check");
});

var update_virtual_bus = func( dt ){
    var PWR = getprop("systems/electrical/serviceable");
    var engine0_state = getprop("/engines/engine[0]/running");
    var engine1_state = getprop("/engines/engine[1]/running");
    var alternator1_volts = 0.0;
    var alternator2_volts = 0.0;
    var battery_volts = battery.get_output_volts() * getprop(BATT);
    var alt_load=1;

    var external_volts = 0.0;
    load = 0.0;
    bus_volts = 0.0;
    power_source = nil;

    if (engine0_state){
    alternator1_volts = getprop(L_ALT) * alternator1.get_output_volts();
}
    if (engine1_state){
    alternator2_volts = getprop(R_ALT) * alternator2.get_output_volts();
    }

######## if electrical system is servicable ##########

if(PWR){
    bus_volts = battery_volts;
    power_source = "battery";
    if(alternator1_volts > battery_volts){bus_volts = alternator1_volts;
    power_source = "alternator1";}
    if(alternator2_volts > battery_volts){bus_volts = alternator2_volts;
    power_source = "alternator2";}

    setprop("/engines/engine[0]/amp-v",alternator1.get_output_amps() * alt_load);
    setprop("/engines/engine[1]/amp-v",alternator2.get_output_amps() * alt_load);

    if (getprop(EXT) and ( external_volts > bus_volts) )bus_volts = external_volts * PWR;

    load += electrical_bus(bus_volts);
    load += avionics_bus(bus_volts);
    load+=ac_bus(bus_volts);
    ammeter = 0.0;
    if ( bus_volts > 1.0 ) {
        load += 15.0;

        if ( power_source == "battery" ) {
            ammeter = -load;
            } else {
            ammeter = battery.charge_amps;
            }
        }
    if ( power_source == "battery" ) {
        battery.apply_load( load, dt );
        } elsif ( bus_volts > battery_volts ) {
        battery.apply_load( -battery.charge_amps, dt );
        }

    ammeter_ave = 0.8 * ammeter_ave + 0.2 * ammeter;

   setprop(Amps,ammeter_ave);
   setprop(Volts,bus_volts);
    }
   return load;
}

var electrical_bus = func(){
    bus_volts = arg[0]; 
    var load = 0.0;
    var starter_switch = getprop("/controls/engines/engine[0]/starter");
    var starter_switch1 = getprop("/controls/engines/engine[1]/starter");
    var starter_volts = 0.0;
    if ( starter_switch or starter_switch1) {
        starter_volts = bus_volts;
        }
    setprop(OutPuts~"starter",starter_volts);

    var f_pump0 = getprop("/controls/engines/engine[0]/fuel-pump");
    var f_pump1 = getprop("/controls/engines/engine[0]/fuel-pump");
    if ( f_pump0 or f_pump1 ) {
        setprop(OutPuts~"fuel-pump",bus_volts);
        } else {
        setprop(OutPuts~"fuel-pump",0);
        }

    setprop(OutPuts~"pitot-heat",bus_volts * getprop("/controls/anti-ice/pitot-heat"));
    setprop(OutPuts~"landing-lights",bus_volts * getprop("/controls/lighting/landing-lights[0]"));
    setprop(OutPuts~"recog-lights",bus_volts * getprop("/controls/lighting/recog-lights"));
    setprop(OutPuts~"cabin-lights",bus_volts * getprop("/controls/lighting/cabin-lights"));
    setprop(OutPuts~"wing-lights",bus_volts * getprop("/controls/lighting/wing-lights"));
    setprop(OutPuts~"nav-lights",bus_volts * getprop("/controls/lighting/nav-lights"));
    setprop(OutPuts~"logo-lights",bus_volts * getprop("/controls/lighting/logo-lights"));
    setprop(OutPuts~"taxi-lights",bus_volts * getprop("/controls/lighting/taxi-lights"));
    setprop(OutPuts~"beacon",bus_volts * getprop("/controls/lighting/beacon-state/state"));
    setprop(OutPuts~"strobe",bus_volts * getprop("/controls/lighting/strobe-state/state"));
    setprop(OutPuts~"flaps",bus_volts);
    return load;
}

#### used in Instruments/source code 
# adf : dme : encoder : gps : DG : transponder  
# mk-viii : MRG : tacan : turn-coordinator
# nav[0] : nav [1] : comm[0] : comm[1]
####

var avionics_bus = func(){
    var bus_volts = arg[0];
    var load = 0.0;
    var INSTR = "/instrumentation/";

    if ( getprop("/controls/electric/avionics-switch")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"efis-lights",bus_volts *EFIS_DIMMER.getValue());
    }else{
        setprop(OutPuts~"efis-lights",0);
    }

    if ( getprop("/controls/lighting/instrument-lights")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"instrument-lights",bus_volts *INSTR_DIMMER.getValue());
       setprop(OutPuts~"eng-lights",bus_volts *ENG_DIMMER.getValue());
       setprop(OutPuts~"panel-lights",bus_volts *PANEL_DIMMER.getValue());
    }else{
       setprop(OutPuts~"instrument-lights",0);
       setprop(OutPuts~"eng-lights",0);
       setprop(OutPuts~"panel-lights",0);
    }

    if(getprop(INSTR~"adf/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"adf",bus_volts);
    }else{
        setprop(OutPuts~"adf",0);
    }

    if(getprop(INSTR~"dme/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"dme",bus_volts);
    }else{
        setprop(OutPuts~"dme",0);
    }

    if(getprop(INSTR~"encoder/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"encoder",bus_volts);
    }else{
        setprop(OutPuts~"encoder",0);
    }

    if(getprop(INSTR~"gps/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"gps",bus_volts);
    }else{
        setprop(OutPuts~"gps",0);
    }

    if(getprop(INSTR~"heading-indicator/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"DG",bus_volts);
    }else{
        setprop(OutPuts~"DG",0);
    }

    if(getprop(INSTR~"transponder/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"transponder",bus_volts);
    }else{
        setprop(OutPuts~"transponder",0);
    }

    if(getprop(INSTR~"mk-viii/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"mk-viii",bus_volts);
    }else{
        setprop(OutPuts~"mk-viii",0);
    }

    if(getprop(INSTR~"master-reference-gyro/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"MGR",bus_volts);
    }else{
        setprop(OutPuts~"MGR",0);
    }

    if(getprop(INSTR~"tacan/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"tacan",bus_volts);
    }else{
        setprop(OutPuts~"tacan",0);
    }

    if(getprop(INSTR~"turn-indicator/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"turn-coordinator",bus_volts);
    }else{
        setprop(OutPuts~"turn-coordinator",0);
    }

    if(getprop(INSTR~"nav[0]/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"nav[0]",bus_volts);
    }else{
        setprop(OutPuts~"nav[0]",0);
    }

    if(getprop(INSTR~"nav[1]/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"nav[1]",bus_volts);
    }else{
        setprop(OutPuts~"nav[1]",0);
    }

    if(getprop(INSTR~"comm[0]/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"comm[0]",bus_volts);
    }else{
        setprop(OutPuts~"comm[0]",0);
    }

    if(getprop(INSTR~"comm[1]/serviceable")){
        load +=bus_volts* 0.05;
        setprop(OutPuts~"comm[1]",bus_volts);
    }else{
        setprop(OutPuts~"comm[1]",0);
    }

    return load;
}

var ac_bus = func(){
    bus_volts = arg[0]; 
    load = 0.0;

    if(INVTR.getBoolValue()){
        if(bus_volts > 10.0){
        load =bus_volts* 0.05;
        setprop(ACVolts,115);
        }
    }else{
        setprop(ACVolts,0);
    }
    return load;
}

var update_electrical = func {
    time = getprop("/sim/time/elapsed-sec");
    dt = time - last_time;
    last_time = time;
    update_virtual_bus( dt );
settimer(update_electrical, 0);
}
