#############################################################################
#
# Bendix-King KFC-200 Flight Director.
#
# Written by Curtis Olson
# Started 15 Dec 2005.
#
#############################################################################

#############################################################################
# Global shared variables
#############################################################################

# major modes are:
#
# off - Off: v-bars hidden
# fd - Flight Director: v-bars appear and command level wings + pitch at the
#      time mode was activated.
# hdg - Heading: v-bars command a turn to the heading bug
# appr - Approach: bank and pitch commands capture and track LOC and GS
#        (or just bank if VOR/RNAV)
# bc - Reverse Localizer: bank command to capture and track a reverse LOC
#      course.  GS is locked out.
# arm - Standby mode to compute capture point for nav, appr, or bc.
# cpld - Coupled: Active mode for nav, appr, or bc.
# ga - Go Around: commands wings level and missed approach attitude.
# alt - Altitude hold: commands pitch to hold altitude
# vertical trim - pitch command to adjust altitude at 500 fpm while in alt hold
#                 or pitch attitude at rate of 1 deg/sec when not in alt hold
# ap - Autopilot Engage: AP will attempt to track FD.
# pitch synchronization: manual flight maneuvering without the need to 
#                        disengage/engage the AP/FD, AP maintains pitch axis.
# yd - Yaw Damper: system senses motion around ayw axis and moves rudder to
#                  oppose yaw.

fdmode = "off";
setprop("/instrumentation/kfc200/fdmode", fdmode);
fdmode_last = "off";
vbar_bank = 0.0;
vbar_pitch = 0.0;
nav_dist = 0.0;
last_nav_dist = 0.0;
last_nav_time = 0.0;
tth_filter = 0.0;


#############################################################################
# Use tha nasal timer to call the initialization function once the sim is
# up and running
#############################################################################

INIT = func {
    # default values
    setprop("/instrumentation/kfc200/fdmode", "off");
    setprop("/instrumentation/kfc200/vbar-pitch", 0.0);
    setprop("/instrumentation/kfc200/vbar-roll", 0.0);
}
settimer(INIT, 0);


#############################################################################
# handle KC 290 Mode Controller inputs, and compute correct mode/settings
#############################################################################

handle_inputs = func {
}


#############################################################################
# track and update mode
#############################################################################

update_mode = func {
    fdmode = getprop("/instrumentation/kfc200/fdmode");

    # compute elapsed time since last iteration
    nav_time = getprop("/sim/time/elapsed-sec");
    nav_dt = nav_time - last_nav_time;
    last_nav_time = nav_time;

    if ( fdmode == "nav-arm" ) {
        curhdg = getprop("/orientation/heading-magnetic-deg");
        tgtrad = getprop("/instrumentation/nav/radials/selected-deg");
        tth = getprop("/instrumentation/nav/time-to-intercept-sec");
        if ( tgtrad == nil or tgtrad == "" ) {
            tgtrad = 0.0;
        }
        diff = tgtrad - curhdg;
        if ( diff < -180.0 ) {
            diff += 360.0;
        } elsif ( diff > 180.0 ) {
            diff -= 180.0;
        }

        # standard rate turn is 3 dec/sec
        roll_out_time_sec = abs(diff) / 3.0;

        # print("tth = ", tth, " hdgdiff = ", diff, " rollout = ", roll_out_time_sec );
        if ( roll_out_time_sec >= abs(tth) ) {
            # switch from arm to cpld
            fdmode = "nav-cpld";
        }

    }

    setprop("/instrumentation/kfc200/fdmode", fdmode);
}


#############################################################################
# update the FD vbar position for the various modes
#############################################################################

update_vbar = func {
    aircraft_bank = getprop("/orientation/roll-deg");
    aircraft_pitch = getprop("/orientation/pitch-deg");

    if ( fdmode == "fd" ) {        
        # wings level maintain pitch at time of mode activation
        if ( fdmode_last != "fd" ) {
            vbar_bank = 0.0;
            vbar_pitch = aircraft_pitch;
        }
    } elsif ( fdmode == "hdg" or fdmode == "nav-arm" ) {
        # FIXME: at what angle off of the hdg bug do we start the rollout?
        # bank to track heading bug
        if ( fdmode == "hdg" and fdmode_last != "hdg" ) {
            vbar_pitch = aircraft_pitch;
        }
        if ( fdmode == "nav-arm" and fdmode_last != "nav-arm" ) {
            vbar_pitch = aircraft_pitch;
        }

        bug_error = getprop("/autopilot/internal/fdm-heading-bug-error-deg");

        # max bank = 30, so this means roll out begins at 15 dgs off target hdg
        bank = 2 * bug_error;
        if ( bank < -30.0 ) {
            bank = -30.0;
        }
        if ( bank > 30.0 ) {
            bank = 30.0;
        }
        vbar_bank = bank;
    } elsif ( fdmode == "nav-cpld" ) {
        curhdg = getprop("/orientation/heading-magnetic-deg");
        tgtrad = getprop("/instrumentation/nav/radials/selected-deg");
        toflag = getprop("/instrumentation/nav/to-flag");
        xtrackoffset
            = getprop("/instrumentation/nav/crosstrack-heading-error-deg");
        actrad = 0.0;
        offset = 0.0;
        if ( toflag ) {
            actrad = getprop("/instrumentation/nav/radials/reciprocal-radial-deg");
            offset = (actrad - tgtrad);
        } else {
            actrad = getprop("/instrumentation/nav/radials/actual-deg");
            offset = (tgtrad - actrad);
        }
        if ( offset < -180.0 ) {
            offset += 360.0;
        } elsif ( offset > 180.0 ) {
            offset -= 360.0;
        }

        # set gain
        offset *= 3;
        if ( offset < -90.0 ) { offset = -90.0; }
        if ( offset > 90.0 ) { offset = 90.0; }

        tgthdg = tgtrad + offset;

        diff = tgthdg - curhdg;
        if ( diff < -180.0 ) {
            diff += 360.0;
        } elsif ( diff > 180.0 ) {
            diff -= 180.0;
        }
        # print("* offset = ", offset, " tgthdg = ", tgthdg, " diff = ", diff);

        hdg_error = getprop("/autopilot/internal/nav1-heading-error-deg");
        hdg_error -= xtrackoffset;
        # max bank = 30, so this means roll out begins at 15 dgs off target hdg
        bank = 2 * hdg_error;
        if ( bank < -30.0 ) {
            bank = -30.0;
        }
        if ( bank > 30.0 ) {
            bank = 30.0;
        }
        vbar_bank = bank;

    } else {
        # assume off if nothing else specified, and hide vbars
        vbar_bank = 0.0;
        vbar_pitch= 180.0;
    }

    fdmode_last = fdmode;

    # set vbar properties
    setprop("/instrumentation/kfc200/vbar-roll", aircraft_bank - vbar_bank);
    setprop("/instrumentation/kfc200/vbar-pitch", vbar_pitch - aircraft_pitch);
    
}


#############################################################################
# main update function to be called each frame
#############################################################################

update = func {
    # return;

    # print("kfc-200 update");

    handle_inputs();
    update_mode();
    update_vbar();

    # print( "vbar bank = ", vbar_bank, "(", getprop("/orientation/roll-deg"),
    #        ") pitch = ", vbar_pitch, "(", getprop("/orientation/pitch-deg"),
    #        ")" );

    registerTimer();
}


#############################################################################
# Use tha nasal timer to call ourselves every frame
#############################################################################

registerTimer = func {
    settimer(update, 0);
}
registerTimer();
