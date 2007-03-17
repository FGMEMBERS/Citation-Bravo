var v1 = nil;
var cl = 0.0;
var c2 = 0.0;
var FDM=0;

strobe_switch = props.globals.getNode("controls/switches/strobe", 1);
aircraft.light.new("sim/model/Bravo/lighting/strobe", [0.05, 1.50], strobe_switch);
beacon_switch = props.globals.getNode("controls/switches/beacon", 1);
aircraft.light.new("sim/model/Bravo/lighting/beacon", [1.0, 1.0], beacon_switch);
Reverser = props.globals.getNode("/surface-positions/reverser-norm",1);

setlistener("/sim/signals/fdm-initialized", func {
	Reverser.setValue(0.0);
	setprop("/environment/turbulence/use-cloud-turbulence","true");
	setprop("/instrumentation/annunciator/master-caution",0.0);
});

setlistener("/controls/engines/engine/reverser", func {
    rvrs = cmdarg().getValue();
    interpolate(Reverser,rvrs, 1.4);
});	 

update_gforce = func {
	force = getprop("/accelerations/pilot-g");
	if(force == nil) {force = 1.0;}
	eyepoint = getprop("sim/view/config/y-offset-m") +0.01;
	eyepoint -= (force * 0.01);
	if(getprop("/sim/current-view/view-number") < 1){
		setprop("/sim/current-view/y-offset-m",eyepoint);
		}
	settimer(update_gforce, 0);
}

update_lighting = func {
	cl = getprop("/systems/electrical/outputs/cabin-lights");
	if(cl == nil){cl = 0.0;}
	if( cl > 0.2 ){
		setprop("/sim/model/material/cabin/factor", cl * 0.033);
		}else{setprop("/sim/model/material/cabin/factor", 0.0);}

	cl = getprop("/systems/electrical/outputs/instrument-lights");
	if(cl == nil){cl = 0.0;} 
	if( cl > 0.2 ){
		setprop("/sim/model/material/instruments/factor", cl * 0.033);
		}else{setprop("/sim/model/material/instruments/factor", 0.0);}
}

update_systems = func {
	update_gforce();
	update_lighting();
	settimer(update_systems,0);
} 
	settimer(update_systems,0);

