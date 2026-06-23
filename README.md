**Custom DRCs for E&P Customers**  
Custom Design Rule Checks (DRCs) for FPGA E&P customer flows in Vivado. These checks identify clocking issues, netlist problems, partitioning sub-optimalities, and timing violations to improve design closure and QoR.  

**Concepts**  
DRC (Design Rule Check): Automated checks run against a Vivado design to flag potential issues before or after placement.  
SLR (Super Logic Region): A physical partition of a multi-die FPGA. Inter-SLR paths cross die boundaries and are critical for timing.  
Floorplanning: Constraining cells to specific regions (pblocks) or SLRs to guide placement.  
Clock Skew: Timing difference between clock arrivals at different endpoints. Large skew degrades timing closure.  
Fanout: Number of loads driven by a single net. High-fanout nets can cause congestion and timing issues.  

**How to Run**  
All DRC Tcl files must be in <parent dir>.  
source <parent dir>/all.tcl  
file mkdir ./postplace_drcs  
::drc::config -max 100 -odir ./postplace_drcs  
report_drc -ruledecks EmuProto_checks -file ./pre_opt_drcs.rpt  
