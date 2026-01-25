#Electrical System
var electricsystem=func{
    var master_bat = getprop("/controls/switches/master-bat");
    var master_alt = getprop("/controls/switches/master-alt");
	var battery_status = getprop("/systems/electrical/battery-status");
	var new_battery_status = battery_status;
	var external_volts = 0;
	var external_amps = 0;

	# external power source connected
    if (getprop("/controls/electric/external-power"))
    {
        external_volts = 12;
        external_amps = 60; 
 }
	
	var engine_rpm = getprop("/engines/engine/rpm");
	var ideal_rpm = 550;	
	var ideal_volts = 12;
	var ideal_amps = 60;
	var bus_load = 0;
	var factor = engine_rpm/ideal_rpm;
	if (factor > 1.0) {
		factor = 1.0;
	}


	var alternator_volts = ideal_volts * factor;
	var alternator_amps = ideal_amps * factor;
 
       if ( master_alt == 0 ){
 		var alternator_volts = 0;
		var alternator_amps = 0;
	}


    # determine power source
    	var bus_volts = 0.0;
		var battery_volts = (12.0 * battery_status)/100;
		var battery_amps = (26.0 * battery_status)/100;
    	var power_source = nil;	


    if ( master_bat ) {
        bus_volts = battery_volts;        
		power_source = "battery";
    }
    if ( master_alt and (alternator_volts > bus_volts) ) {
        bus_volts = alternator_volts;
		bus_load += alternator_amps;
        power_source = "alternator";
    }
    if ( !master_bat and (external_volts > bus_volts ) ) {
        bus_volts = external_volts;
		bus_load += external_amps;
        power_source = "external";
    }

    if ( power_source == "battery" ) {
		new_battery_status = battery_status - 0.0001;
		bus_load += battery_amps;
	}

    if ( ( power_source == "alternator" or power_source == "external" ) and ( battery_status < 100.0 ) ) {
		new_battery_status = battery_status + 0.0001;
	}
		
    # Comm-Nav
    if ( getprop("/controls/circuit-breakers/comm1") ) {
        setprop("/systems/electrical/outputs/comm[0]", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/comm[0]", 0.0);
    }

    if ( getprop("/controls/circuit-breakers/comm2") ) {
        setprop("/systems/electrical/outputs/comm[1]", 0.0);
    } else {
        setprop("/systems/electrical/outputs/comm[1]", 0.0);
    }
	
    if ( getprop("/controls/circuit-breakers/nav1") ) {
        setprop("/systems/electrical/outputs/nav[0]", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/nav[0]", 0.0);
    }

    if ( getprop("/controls/circuit-breakers/nav2") ) {
        setprop("/systems/electrical/outputs/nav[1]", 0.0);
    } else {
        setprop("/systems/electrical/outputs/nav[1]", 0.0);
    }

    if ( getprop("/controls/circuit-breakers/adf") ) {
        setprop("/systems/electrical/outputs/adf", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/adf", 0.0);
    }
	
    if ( getprop("/controls/circuit-breakers/audio-mkr") ) {
        setprop("/systems/electrical/outputs/audio-panel", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/audio-panel", 0.0);
    }

    # Transponder
    if ( getprop("/controls/circuit-breakers/transponder") ) {
        setprop("/systems/electrical/outputs/transponder", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/transponder", 0.0);
    }

    # Starter
    if ( getprop("/controls/circuit-breakers/starter") ) {
        setprop("/systems/electrical/outputs/starter", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/starter", 0.0);
    }

    # Stall warning
    if ( getprop("/controls/circuit-breakers/stall-warn") ) {
        setprop("/systems/electrical/outputs/stall-warn", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/stall-warn", 0.0);
    }

    # Warning light
    if ( getprop("/controls/circuit-breakers/warn_lt") ) {
        setprop("/systems/electrical/outputs/warn_lt", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/warn_lt", 0.0);
    }

    # Alternator field
    if ( getprop("/controls/circuit-breakers/alt-field") ) {
        setprop("/systems/electrical/outputs/alt-field", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/alt-field", 0.0);
    }
	
    # Engine Instrument Power: ammeter, fuel, oil press and temperature
    if ( getprop("/controls/circuit-breakers/engine-gages") ) {
        setprop("/systems/electrical/outputs/engine-gages", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/engine-gages", 0.0);
    }
    
    # Interior lights
    if ( getprop("/controls/circuit-breakers/panel_lt") ) {
        setprop("/systems/electrical/outputs/panel-lights", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/panel-lights", 0.0);
    }    

    # Landing Light Power
    if ( getprop("/controls/circuit-breakers/landing_lt") ) {
        setprop("/systems/electrical/outputs/landing-light", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/landing-light", 0.0 );
    }    
    
    # Nav Lights Power
    if ( getprop("/controls/circuit-breakers/nav_lt") ) {
        setprop("/systems/electrical/outputs/nav-lights", bus_volts);
		if ( getprop("/controls/lighting/nav-lights-switch") ) {
			bus_load -= bus_volts / 2.4;
		}
    } else {
        setprop("/systems/electrical/outputs/nav-lights", 0.0);
    }

    # Anti-Collision Lights Power
    if ( getprop("/controls/circuit-breakers/anti-coll_lt") ) {
        setprop("/systems/electrical/outputs/anti-coll-lights", bus_volts); 
 } else {
        setprop("/systems/electrical/outputs/anti-coll-lights", 0.0);
    }

    # Turn Coordinator and directional gyro Power
    if ( getprop("/controls/circuit-breakers/turn-coordinator") ) {
        setprop("/systems/electrical/outputs/turn-coordinator", bus_volts);
        setprop("/systems/electrical/outputs/DG", bus_volts);
    } else {
        setprop("/systems/electrical/outputs/turn-coordinator", 0.0);
        setprop("/systems/electrical/outputs/DG", 0.0);
    }

	setprop("/systems/electrical/suppliers/battery", battery_volts);
	setprop("/systems/electrical/suppliers/alternator", alternator_volts);
	setprop("/systems/electrical/amps", alternator_amps);
	setprop("/systems/electrical/bus_load", bus_load);
	setprop("/systems/electrical/volts", bus_volts);
	setprop("/systems/electrical/battery-status", new_battery_status);

	settimer(electricsystem, 0);
}

setlistener("sim/signals/fdm-initialized", electricsystem);



