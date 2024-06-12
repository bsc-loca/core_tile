// Set simulation defines
+define+SIMULATION
+define+SIM_COMMIT_LOG
+define+SIM_COMMIT_LOG_DPI
+define+SIM_KONATA_DUMP
+define+SARG_BYPASS_LSQ
-F ../standalone_config.f

// Load Sargantana RTL
-F ../filelist.f

// Load behavioral models
-F models/filelist.f

// Load Debug Module + JTAG
-F bsc-dm/filelist.f

// Load testbench
sim_top.sv
