rev1 = nil;
r1 = nil;
r2 = nil;
v1 = nil;
cl = 0.0;
c2 = 0.0;
hpsi = 0.0;
strobe_switch = props.globals.getNode("controls/switches/strobe", 1);
aircraft.light.new("sim/model/Bravo/lighting/strobe", 0.05, 1.50, strobe_switch);
beacon_switch = props.globals.getNode("controls/switches/beacon", 1);
aircraft.light.new("sim/model/Bravo/lighting/beacon", 1.0, 1.0, beacon_switch);

init_controls = func {
setprop("/controls/engines/reverser-position",0.0);
setprop("/environment/turbulence/use-cloud-turbulence","true");
setprop("/sim/current-view/field-of-view",60.0);
setprop("/controls/gear/brake-parking",1.0);
setprop("/instrumentation/annunciator/master-caution",0.0);
setprop("/systems/hydraulic/pump-psi[0]",0.0);
setprop("/systems/hydraulic/pump-psi[1]",0.0);
print("Aircraft systems initialized");
}
settimer(init_controls, 0);




ToggleReverser = func {
rvsr = props.globals.getNode("/controls/engines/reverser-position");
rev1 = rvsr.getValue();
if(rev1 == 0.0 or rev1 == nil){
rev1 = 0.0;
interpolate(rvsr, 1.0, 1.4);
setprop("/controls/engines/engine[0]/reverser","true");
setprop("/controls/engines/engine[1]/reverser", "true");
if(getprop("/gear/gear[2]/wow") == 0.0){
setprop("/instrumentation/annunciator/master-caution",1.0);}
} else {
if (rev1 == 1.0){
interpolate(rvsr, 0.0, 1.4);
setprop("/controls/engines/engine[0]/reverser","false");
setprop("/controls/engines/engine[1]/reverser","false");
setprop("/instrumentation/annunciator/master-caution",0.0);
  }
 }
}

update_systems = func {
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

 force = getprop("/accelerations/pilot-g");
if(force == nil) {force = 1.0;}
eyepoint = (0.99 - (force * 0.01));
if(getprop("/sim/current-view/view-number") < 1){
setprop("/sim/current-view/y-offset-m",eyepoint);
}
hpsi = getprop("/engines/engine[0]/n2");
if(hpsi == nil){hpsi =0.0;}
if(hpsi > 30.0){setprop("/systems/hydraulic/pump-psi[0]",60.0);}
else{setprop("/systems/hydraulic/pump-psi[0]",hpsi * 2);}

hpsi = getprop("/engines/engine[1]/n2");
if(hpsi == nil){hpsi =0.0;}
if(hpsi > 30.0){setprop("/systems/hydraulic/pump-psi[1]",60.0);}
else{setprop("/systems/hydraulic/pump-psi[1]",hpsi * 2);}
settimer(update_systems,0);
}
settimer(update_systems,0);