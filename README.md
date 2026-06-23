# Custom DRCs for E&P Customers  
Custom Design Rule Checks (DRCs) for FPGA E&P customer flows in Vivado. These checks identify clocking issues, netlist problems, partitioning sub-optimalities, and timing violations to improve design closure and QoR.  

## Concepts    
DRC (Design Rule Check): Automated checks run against a Vivado design to flag potential issues before or after placement.  
SLR (Super Logic Region): A physical partition of a multi-die FPGA. Inter-SLR paths cross die boundaries and are critical for timing.  
Floorplanning: Constraining cells to specific regions (pblocks) or SLRs to guide placement.  
Clock Skew: Timing difference between clock arrivals at different endpoints. Large skew degrades timing closure.  
Fanout: Number of loads driven by a single net. High-fanout nets can cause congestion and timing issues.  

## How to Run  
Place all the DRC TCL files in a dir of your choice (e.g. "/parent/dir").    
source /parent/dir/all.tcl  
file mkdir ./postplace_drcs  
::drc::config -max 100 -odir ./postplace_drcs  
report_drc -ruledecks EmuProto_checks -file ./pre_opt_drcs.rpt  

Finalized DRCs
Clocking

EP_CLK-1 — BUFGCE CE control driven by a very high-fanout clocked startup path

Stage: Pre-place

Severity: CRITICAL WARNING

EP_CLK-2 — Nets with USER_CLOCK_ROOT property set

Stage: Pre-place

Severity: INFO

EP_CLK-3 — Parallel buffers driven by XPLL/CLKOUT0 with different CLOCK_DELAY_GROUP values

Stage: Pre-place

Severity: WARNING

EP_CLK-4 — Missing/mismatch of CLOCK_DELAY_GROUP for MMCM feedback loop and CLKOUT0

Stage: Pre-place

Severity: WARNING

EP_CLK-5 — Nets with CLOCK_BUFFER_TYPE property set

Stage: Pre-place

Severity: ADVISORY

Netlist

EP_OPT-1 — Nets with DONT_TOUCH=1

Stage: Pre-place

Severity: ADVISORY

EP_OPT-3 — Nets with MARK_DEBUG=1

Stage: Pre-place

Severity: ADVISORY

EP_NETL-1 — High fanout nets (≥2,000 and <100K)

Stage: Pre-place

Severity: ADVISORY

EP_NETL-2 — Medium fanout nets (≥200 and <2,000)

Stage: Pre-place

Severity: ADVISORY

EP_NETL-3 — Very high fanout nets (≥100K)

Stage: Pre-place

Severity: ADVISORY

Partitioning

EP_PART-1 — Modules with USER_SLR_ASSIGNMENT property

Stage: Pre-place

Severity: ADVISORY

EP_PART-2 — Modules with USER_SLR_ASSIGNMENT=SLRx (specific SLR)

Severity: ADVISORY

EP_PART-3 — Modules with USER_CLUSTER property

Severity: ADVISORY

EP_PART-4 — Hard Pblocks

Severity: ADVISORY

EP_PART-5 — Inter-SLR paths with sub-optimal partitioning (datapath crosses SLRs unnecessarily)

Stage: Post-place

Severity: ADVISORY

EP_PART-6 — Paths with start/endpoint in same SLR but partitioning causes SLR crossing

Stage: Post-place
