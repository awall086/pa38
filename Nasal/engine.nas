# =============================== DEFINITIONS ===========================================

# set the update period

var UPDATE_PERIOD = 0.3;

# =============================== Hobbs meter =======================================

# this property is saved by aircraft.timer
var hobbsmeter_engine = aircraft.timer.new("/sim/time/hobbs/engine[0]", 60, 1);

var init_hobbs_meter = func(index, meter) {
    setlistener("/engines/engine[" ~ index ~ "]/running", func {
        if (getprop("/engines/engine[" ~ index ~ "]/running")) {
            meter.start();
            print("Hobbs system started");
        } else {
            meter.stop();
            print("Hobbs system stopped");
        }
    }, 1, 0);
};

init_hobbs_meter(0, hobbsmeter_engine);

var update_hobbs_meter = func {
    # in seconds
    var hobbs_engine = getprop("/sim/time/hobbs/engine[0]") or 0.0;

    var hobbs = 0;
	hobbs = hobbs_engine / 3600.0;

    setprop("/instrumentation/hobbs-meter/digits0", math.mod(int(hobbs * 100), 10));
	setprop("/instrumentation/hobbs-meter/digits1", math.mod(int(hobbs * 10), 10));
    # rest of digits
    setprop("/instrumentation/hobbs-meter/digits2", math.mod(int(hobbs), 10));
    setprop("/instrumentation/hobbs-meter/digits3", math.mod(int(hobbs / 10), 10));
    setprop("/instrumentation/hobbs-meter/digits4", math.mod(int(hobbs / 100), 10));
    setprop("/instrumentation/hobbs-meter/digits5", math.mod(int(hobbs / 1000), 10));
};

setlistener("/sim/time/hobbs/engine[0]", update_hobbs_meter, 1, 0);

# ========== primer stuff ======================

# Toggles the state of the primer
var pumpPrimer = func {
    var push = getprop("/controls/engines/engine/primer-lever") or 0;

    if (push) {
        var pump = getprop("/controls/engines/engine/primer") or 0;
        setprop("/controls/engines/engine/primer", pump + 1);
        setprop("/controls/engines/engine/primer-lever", 0);
    }
    else {
        setprop("/controls/engines/engine/primer-lever", 1);
    }
};

# Primes the engine automatically. This function takes several seconds
var autoPrime = func {
    var p = getprop("/controls/engines/engine/primer") or 0;
    if (p < 3) {
        pumpPrimer();
        settimer(autoPrime, 1);
    }
};

# Mixture will be calculated using the primer during 5 seconds AFTER the pilot used the starter
# This prevents the engine to start just after releasing the starter: the propeller will be running
# thanks to the electric starter, but carburator has not yet enough mixture
var primerTimer = maketimer(5, func {
    setprop("/controls/engines/engine/use-primer", 0);
    # Reset the number of times the pilot used the primer only AFTER using the starter
    setprop("/controls/engines/engine/primer", 0);
    print("Primer reset to 0");
    primerTimer.stop();
});

# ========== carburetor icing ======================

var carb_icing_function = maketimer(1.0, func {
	var carb_heat = getprop("/controls/anti-ice/engine[0]/carb-heat");
	var eng_rpm = getprop("/engines/engine[0]/rpm");
	var cht_degf = getprop("/engines/engine[0]/cht-degf");
    var airtempF = getprop("/environment/temperature-degf");

	if ( eng_rpm > 0 ) 
		var carb_temp = ((((airtempF - (66 - (eng_rpm/100))) + (cht_degf/20) + (15 * carb_heat)) - 32) * 5) / 9;
	else
		var carb_temp = 0.0;
	setprop("/engines/engine[0]/carb_temp", carb_temp);
	
    if (getprop("/engines/engine[0]/carb_icing_allowed")) {
        var rpm = getprop("/engines/engine[0]/rpm");
        var dewpointC = getprop("/environment/dewpoint-degc");
        var dewpointF = dewpointC * 9.0 / 5.0 + 32;
        var oil_temp = getprop("/engines/engine[0]/oil-temperature-degf");
        var egt_degf = getprop("/engines/engine[0]/egt-degf");
        var engine_running = getprop("/engines/engine[0]/running");
        var carb_ice = getprop("/engines/engine[0]/carb_ice");


        # the formula below attempts to model the graph found in the POH which relates air temperature, dew point and RPM to icing
        # conditions. The outputs of carb_icing_formula ranges from 0.65 to -0.35 (positive means ice is accumulating, negative
        # means that ice is melting)
        var factorX = 13.2 - 3.2 * math.atan2 ( ((rpm - 2000.0) * 0.008), 1);
        var factorY = 7.0 - 2.0 * math.atan2 ( ((rpm - 2000.0) * 0.008), 1);
        var carb_icing_formula = (math.exp( math.pow((0.6 * airtempF + 0.3 * dewpointF - 42.0),2) / (-2 * math.pow(factorX,2))) * math.exp( math.pow((0.3 * airtempF - 0.6 * dewpointF + 14.0),2) / (-2 * math.pow(factorY,2))) - 0.35)  * engine_running;

        # the efficacy of carb heat depends on the EGT. With a typical EGT of ~1500, the carb_heat_rate will be around -1.5.
        # This value is an educated guess of the RL effect, and should melt ice regardless of the icing rate
        if (getprop("/controls/engines/engine[0]/carb-heat"))
            var carb_heat_rate = -0.001 * egt_degf;
        else
            var carb_heat_rate = 0.0;

        # a warm engine will accumulate less ice than a cold one, which is what oil temp factor is used for. oil_temp_factor
        # ranges from 0 to aprox -0.2 (at 250 oF). These values are educated guesses of the RL effect
        var oil_temp_factor = oil_temp / -1250;

        # the final rate of icing or melting is then calculated by all these effects together
        var carb_icing_rate = carb_icing_formula + carb_heat_rate + oil_temp_factor;

        # since the carb_icing_rate gives an arbitrary final value, the rate is then scaled down by 0.00001 to ensure ice
        # accumulates as slowly as expected
        carb_ice = carb_ice + carb_icing_rate * 0.00001;
        carb_ice = std.max(0.0, std.min(carb_ice, 1.0));

        # this property is used to lower the RPM of the engine as ice accumulates (more ice in the carburator == less power)
        var vol_eff_factor = std.max(0.0, 0.85 - 1.72 * carb_ice);

        setprop("/engines/engine[0]/carb_ice", carb_ice);
        setprop("/engines/engine[0]/carb_icing_rate", carb_icing_rate);
        setprop("/engines/engine[0]/volumetric-efficiency-factor", vol_eff_factor);
        setprop("/engines/engine[0]/oil_temp_factor", oil_temp_factor);
    }
    else {
        setprop("/engines/engine[0]/carb_ice", 0.0);
        setprop("/engines/engine[0]/carb_icing_rate", 0.0);
        setprop("/engines/engine[0]/volumetric-efficiency-factor", 0.85);
        setprop("/engines/engine[0]/oil_temp_factor", 0.0);
    };
});

# ========== engine coughing ======================

var engine_coughing = func(){

    var coughing = getprop("/engines/engine[0]/coughing");
    var running = getprop("/engines/engine[0]/running");

    if (coughing and running) {
        # the code below kills the engine and then brings it back to life after 0.25 seconds, simulating a cough
        setprop("/engines/engine[0]/kill-engine", 1);
        settimer(func {
            setprop("/engines/engine[0]/kill-engine", 0);
        }, 0.25);
    };

    # basic value for the delay (interval between consecutive coughs), in case no fuel contamination nor carb ice are present
    var delay = 2;

    # if coughing due to carb ice melting, then cough depends on quantity of ice in the carburettor
    var carb_ice = getprop("/engines/engine[0]/carb_ice");
    if (carb_ice > 0) {
        # if carb_ice is near 0, then interval is between 17 and 20 seconds, but if carb_ice is near the
        # engine stopping value of 0.3, then interval falls to around 0.5 and 3.5 seconds
        delay = 3.0 * rand() + 17 - 41.25 * carb_ice;
    };

    coughing_timer.restart(delay);

}

var coughing_timer = maketimer(1, engine_coughing);

# ====== Engine starting actions ======
var engine_starting = props.globals.initNode("/engines/engine/starting", 0, "BOOL");
setlistener("/engines/engine/running", func(ngn){
    if (ngn.getValue() and !getprop("/engines/engine[0]/coughing")) {
        engine_starting.setValue(1);
        var timer = maketimer(1, func(){
            engine_starting.setValue(0);
        });
        timer.singleShot = 1; # timer will only be run once
        timer.start();
    } else {
        engine_starting.setValue(0);
    }
},0,0);

setlistener("/engines/engine/starting", func(ngn){
    # Eye-candy: when engine starts, let the view shake a bit
    if (ngn.getValue() and getprop("/sim/current-view/internal")) {
        var curX = getprop("/sim/current-view/x-offset-m");
        var xtimer = maketimer(0.05, func(){
            interpolate("/sim/current-view/x-offset-m", curX-0.0015+rand()*0.003, 0.05);
        });
        xtimer.start();
        var curY = getprop("/sim/current-view/y-offset-m");
        var ytimer = maketimer(0.05, func(){
            interpolate("/sim/current-view/y-offset-m", curY-0.0015+rand()*0.003, 0.05);
        });
        ytimer.start();
        var stoptimer = maketimer(0.8, func(){
           xtimer.stop();
           ytimer.stop();
           interpolate("/sim/current-view/x-offset-m", curX, 0.1);
           interpolate("/sim/current-view/y-offset-m", curY, 0.1);
        });
        stoptimer.singleShot = 1;
        stoptimer.start();
    }
}, 0, 0);

# ========== Main loop ======================

var update = func {
	#this block should be moved out of nasal and into jsbsim or autopilot logic
    var leftTankUsable  = 0;
    var rightTankUsable = 0;
	var LeftTankSelected = 0;
	var RightTankSelected = 0;
	var TankSelected = getprop("/controls/fuel/fuel-selector");
	if ( TankSelected == 1 ) {
		LeftTankSelected = 1;
	}
	if ( TankSelected == 2 ) {
		RightTankSelected = 1;
	}
    if ( LeftTankSelected and ( getprop("/consumables/fuel/tank[1]/level-gal_us") > 0 ) ) { leftTankUsable = 1; }
    if ( RightTankSelected and ( getprop("/consumables/fuel/tank[2]/level-gal_us") > 0 ) ) { rightTankUsable  = 1; }
    var outOfFuel = !(leftTankUsable or rightTankUsable);

    # We use the mixture to control the engines, so set the mixture
    var usePrimer = getprop("/controls/engines/engine/use-primer") or 0;

    var engine_running = getprop("/engines/engine/running");

    if (outOfFuel and (engine_running or usePrimer)) {
        print("Out of fuel!");
        gui.popupTip("Out of fuel!");
    }
    elsif (usePrimer and !engine_running and getprop("/engines/engine/oil-temperature-degf") <= 75) {
        # Mixture is controlled by start conditions
        var primer = getprop("/controls/engines/engine/primer");
        if (!getprop("/fdm/jsbsim/fcs/mixture-primer-cmd") and getprop("/controls/switches/starter") and getprop("/controls/switches/master-bat")) {
            if (primer < 3) {
                print("Use the primer!");
                gui.popupTip("Use the primer!");
            }
            elsif (primer > 6) {
                print("Flooded engine!");
                gui.popupTip("Flooded engine!");
            }
            else {
                print("Check the throttle!");
                gui.popupTip("Check the throttle!");
            }
        }
    }
    
};

setlistener("/controls/switches/starter", func {
    var v = getprop("/controls/switches/starter") or 0;
    if (v == 0) {
        print("Starter off");
        # notice the starter will be reset after 5 seconds
        primerTimer.restart(5);
    }
    else {
        print("Starter on");
        setprop("/controls/engines/engine/use-primer", 1);
        if (primerTimer.isRunning) {
            primerTimer.stop();
        }
    }
}, 1, 0);

var engine_timer = maketimer(UPDATE_PERIOD, func { update(); });

setlistener("/sim/signals/fdm-initialized", func {
    engine_timer.start();
	carb_icing_function.start();
    coughing_timer.start();
});
