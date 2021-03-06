aircraft.livery.init("Aircraft/Citation-Bravo/Models/Liveries");
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

var MC_vor_btn=0;
var MC_apt_btn=0;
var vor_id=[0,1,0];
var vor_sym=[0,1,1];
var apt_id=[0,1,0];
var apt_sym=[0,1,1];

#Jet Engine Helper class
# ie: var Eng = JetEngine.new(engine number);
var JetEngine = {
    new : func(eng_num){
        m = { parents : [JetEngine]};
        m.ITTlimit=8.9;
        m.fdensity = getprop("consumables/fuel/tank/density-ppg") or 6.72;
        m.eng = props.globals.initNode("engines/engine["~eng_num~"]");
        m.controls = props.globals.initNode("controls/engines/engine["~eng_num~"]");
        m.running = m.eng.initNode("running",0,"BOOL");
        m.itt=m.eng.initNode("itt-norm",0.0);
        m.itt_c=m.eng.initNode("itt-celcius",0.0);
        m.n1 = m.eng.initNode("n1");
        m.n2 = m.eng.initNode("n2");
        m.fan = m.eng.initNode("fan",0.0);
        m.cycle_up = 0;
        m.turbine = m.eng.initNode("turbine",0.0);
        m.throttle_lever = m.controls.initNode("throttle-lever",0.0);
        m.throttle = m.controls.initNode("throttle",0.0);
        m.ignition = m.controls.initNode("ignition",1);
        m.cutoff = m.controls.initNode("cutoff",1,"BOOL");
        m.engine_off=1;
        m.fuel_out = m.eng.initNode("out-of-fuel",0,"BOOL");
        m.starter = m.controls.initNode("starter");
        m.fuel_pph=m.eng.initNode("fuel-flow_pph",0.0);
        m.fuel_gph=m.eng.initNode("fuel-flow-gph");
        m.hpump=props.globals.initNode("systems/hydraulics/pump-psi["~eng_num~"]",0.0);
        
        m.Lfuel = setlistener(m.fuel_out, func (fl) {m.shutdown(fl.getValue())},1,0);
        m.Lign = setlistener(m.ignition, func (ig) {m.shutdown(1-ig.getValue())},1,0);
        m.CutOff = setlistener(m.cutoff, func (ct){m.engine_off=ct.getValue()},1,0);
        return m;
    },
#### update ####
    update : func{
        if(!me.engine_off){
            var thr = me.throttle.getValue();
            me.fan.setValue(me.n1.getValue());
            me.turbine.setValue(me.n2.getValue());
            if(getprop("controls/engines/grnd_idle"))thr *=0.92;
            me.throttle_lever.setValue(thr);
        }else{
            me.throttle_lever.setValue(0);
            if(me.starter.getBoolValue())me.cycle_up=me.ignition.getValue();
            if(me.cycle_up){
                me.spool_up(15);
            }else{
                var tmprpm = me.fan.getValue();
                if(tmprpm > 0.0){
                    tmprpm -= getprop("sim/time/delta-sec") * 2;
                    me.fan.setValue(tmprpm);
                    me.turbine.setValue(tmprpm);
                }
            }
        }
    me.fuel_pph.setValue(me.fuel_gph.getValue()*me.fdensity);
    var hpsi =me.fan.getValue();
    if(hpsi>60)hpsi = 60;
    me.hpump.setValue(hpsi);
    me.itt_c.setValue(me.fan.getValue() * me.ITTlimit);
    },

    spool_up : func(scnds){
        if(!me.engine_off){
            return;
        }else{
            var n1=me.n1.getValue() ;
            var n1factor = n1/scnds;
            var n2=me.n2.getValue() ;
            var n2factor = n2/scnds;
            var tmprpm = me.fan.getValue();
            tmprpm += getprop("sim/time/delta-sec") * n1factor;
            var tmprpm2 = me.turbine.getValue();
            tmprpm2 += getprop("sim/time/delta-sec") * n2factor;
            me.fan.setValue(tmprpm);
            me.turbine.setValue(tmprpm2);
            if(tmprpm >= me.n1.getValue()){
                me.cutoff.setBoolValue(0);
                me.cycle_up=0;
            }
        }
    },

    shutdown : func(b){
        if(b!=0){
            me.cutoff.setBoolValue(1);
        }
    }
};


aircraft.light.new("instrumentation/annunciators", [0.5, 0.5], MstrCaution);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10,1);
var Grd_Idle=props.globals.getNode("controls/engines/grnd-idle",1);
Grd_Idle.setBoolValue(1);
var LHeng= JetEngine.new(0);
var RHeng= JetEngine.new(1);

#######################################
setlistener("/sim/signals/fdm-initialized", func {
    SndIn.setDoubleValue(0.75);
    SndOut.setDoubleValue(0.15);
    MstrWarn.setBoolValue(0);
    MstrCaution.setBoolValue(0);
    if(getprop("/sim/flight-model")=="jsb"){FDMjsb=1;}
    setprop("/sim/model/start-idling",0);
    setprop("controls/engines/N1-limit",94.0);
    settimer(update_systems,2);
});

setlistener("/gear/gear[1]/wow", func(ww){
    if(ww.getBoolValue()){
        FHmeter.stop();
        Grd_Idle.setBoolValue(1);
    }else{
        FHmeter.start();
        Grd_Idle.setBoolValue(0);
    }
},0,0);

setlistener("sim/model/autostart", func(strt){
    if(strt.getBoolValue()){
        Startup();
    }else{
        Shutdown();
    }
},0,0);

setlistener("controls/gear/gear-down", func(grlock){
    var glk= grlock.getBoolValue();
    if(!glk){
    var GLH =getprop("gear/gear[1]/wow");
    var GRH =getprop("gear/gear[2]/wow");
    if(GLH or GRH)setprop("controls/gear/gear-down",1);
    }
},0,0);

setlistener("/sim/current-view/internal", func(vw){
    if(vw.getBoolValue()){
        SndIn.setDoubleValue(0.75);
        SndOut.setDoubleValue(0.10);
    }else{
        SndIn.setDoubleValue(0.10);
        SndOut.setDoubleValue(0.75);
    }
},1,0);

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


var annunciators_loop = func{
    setprop("/instrumentation/annunciators/LHign",LHeng.cycle_up);
    setprop("/instrumentation/annunciators/fuel-boost",LHeng.cycle_up);
    setprop("/instrumentation/annunciators/RHign",RHeng.cycle_up);
    setprop("/instrumentation/annunciators/fuel-boost",RHeng.cycle_up);

    var Tfuel = getprop("/consumables/fuel/total-fuel-lbs");
        if( Tfuel< 400){
                MstrCaution.setBoolValue(1 * PWR2);
                Annun.getNode("fuel-lo").setBoolValue(PWR2);
            }else{
                Annun.getNode("fuel-lo").setBoolValue(0);
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

    if(getprop("engines/engine[0]/fan") < 40){
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

    if(getprop("engines/engine[1]/fan") < 40){
        Annun.getNode("fuel-psi").setBoolValue(1 * PWR2);
        Annun.getNode("hyd-flow").setBoolValue(1 * PWR2);
        Annun.getNode("hyd-psi").setBoolValue(1 * PWR2);
    }else{
        Annun.getNode("fuel-psi").setBoolValue(0);
        Annun.getNode("hyd-flow").setBoolValue(0);
        Annun.getNode("hyd-psi").setBoolValue(0);
    }

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


var FHupdate = func(tenths){
        var fmeter = getprop("/instrumentation/clock/flight-meter-sec");
        var fhour = fmeter/3600;
        setprop("instrumentation/clock/flight-meter-hour",fhour);
        var fmin = fhour - int(fhour);
        if(tenths !=0){
            fmin *=100;
        }else{
            fmin *=60;
        }
        setprop("instrumentation/clock/flight-meter-min",int(fmin));
    }

controls.gearDown = func(v) {
    if (v < 0) {
        if(!getprop("gear/gear[1]/wow"))setprop("/controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("/controls/gear/gear-down", 1);
    }
}

mfd_btn = func(btn) {
    var s_prop = "instrumentation/mc-800/menu-selected";
    var select =getprop(s_prop);;
    var menu = getprop("instrumentation/mc-800/menu");
    if(menu==0){
        if(btn==2){
            setprop("instrumentation/mc-800/menu",1);
        }elsif(btn==3){
            setprop("instrumentation/mc-800/menu",4);
        }elsif(btn==4){
            var epgw = getprop("instrumentation/mk-viii/serviceable");
            setprop("instrumentation/mk-viii/serviceable",1-epgw);
        }
    }elsif(menu==1){
        if(btn==1){
            setprop("instrumentation/mc-800/menu",0);
            setprop(s_prop,"");
        }elsif(btn==2){
            setprop("instrumentation/mc-800/menu",2);
        }elsif(btn==3){
            setprop("instrumentation/mc-800/menu",3);
        }
    }elsif(menu==2){
        if(btn==1){
            setprop("instrumentation/mc-800/menu",0);
            setprop(s_prop,"");
        }
    }elsif(menu==3){
        if(btn==1){
            setprop("instrumentation/mc-800/menu",0);
            setprop(s_prop,"");
        }elsif(btn==2){
            if(select!="TO")setprop(s_prop,"TO") else setprop(s_prop,"");
        }elsif(btn==3){
            if(select!="ST EL")setprop(s_prop,"ST EL") else setprop(s_prop,"");
        }elsif(btn==4){
            if(select!="VANG")setprop(s_prop,"VANG") else setprop(s_prop,"");
        }elsif(btn==5){
            if(select!="VS")setprop(s_prop,"VS") else setprop(s_prop,"");
        }
    }elsif(menu==4){
        if(btn==1){
            setprop("instrumentation/mc-800/menu",0);
            setprop(s_prop,"");
        }elsif(btn==3){
            setprop("instrumentation/mc-800/menu",5);
        }elsif(btn==4){
            setprop("instrumentation/mc-800/menu",6);
        }
    }elsif(menu==5){
        if(btn==1){
            setprop("instrumentation/mc-800/menu",0);
            setprop(s_prop,"");
        }elsif(btn==2){
            if(select!="V1")setprop(s_prop,"V1") else setprop(s_prop,"");
        }elsif(btn==3){
            if(select!="VR")setprop(s_prop,"VR") else setprop(s_prop,"");
        }elsif(btn==4){
            if(select!="V2")setprop(s_prop,"V2") else setprop(s_prop,"");
        }
    }elsif(menu==6){
        if(btn==1){
            setprop("instrumentation/mc-800/menu",0);
            setprop(s_prop,"");
        }elsif(btn==2){
            if(select!="VREF")setprop(s_prop,"VREF") else setprop(s_prop,"");
        }elsif(btn==2){
            if(select!="VAPP")setprop(s_prop,"VAPP") else setprop(s_prop,"");
        }
    }
}


var mc800_btn = func(btn){
    if(btn=="vor"){
        MC_vor_btn+=1;
        if(MC_vor_btn>2)MC_vor_btn=0;
        setprop("instrumentation/mc-800/vor",vor_sym[MC_vor_btn]);
        setprop("instrumentation/mc-800/vor-id",vor_id[MC_vor_btn]);
    }elsif(btn=="apt"){
        MC_apt_btn+=1;
        if(MC_apt_btn>2)MC_apt_btn=0;
        setprop("instrumentation/mc-800/apt",apt_sym[MC_apt_btn]);
        setprop("instrumentation/mc-800/apt-id",apt_id[MC_apt_btn]);
    }
}

########## MAIN ##############

var update_systems = func{
    LHeng.update();
    RHeng.update();
    FHupdate(0);

    if(getprop("velocities/airspeed-kt") > 40) setprop("controls/cabin-door/open",0);

    var GrWrn = 0;
    var Ghorn = 0;
    var GLock = 0;
    PWR2 =0;
    if(getprop("systems/electrical/right-bus") > 2.0)PWR2=1;
    if(getprop("systems/electrical/left-bus") > 2.0)PWR2=1;
    
    if(!getprop("controls/gear/gear-down/")){
        GrWrn =1;
    }
    
    if(GrWrn ==1){
        if(getprop("engines/engine/n2")<70 or getprop("engines/engine[1]/n2")<70){
            if(getprop("velocities/airspeed-kt") < 150){
                if(getprop("position/altitude-agl-ft")<5000){
                    if(getprop("/surface-positions/flap-pos-norm") < 0.35)Ghorn =1;
                }
            }
        }
    }

    setprop("instrumentation/annunciators/gear-unlocked",GLock);
    setprop("instrumentation/alerts/gear-horn",Ghorn);

    annunciators_loop();
    settimer(update_systems,0);
}

