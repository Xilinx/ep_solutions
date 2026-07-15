# This DRC flags the parallel buffers driven by XPLL/CLKOUT0 that are missing the CLOCK_DELAY_GROUP property or have different CLOCK_DELAY_GROUP values

# DCRINFO:
#    DRC ID : generate the check ID based on the filename
#    Rule deck
#    DRC Category
#    DRC message
#    DRC severity
set DRCINFO [list \
  [file rootname [file tail [info script]]] \
  {EmuProto_checks} \
  {Clocking Checks} \
  {Missing CLOCK_DELAY_GROUP for XPLL feedback loop} \
  {Warning}
  ]

proc [lindex $DRCINFO 0] {} {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # DRC code
  foreach xpll [get_cells -quiet -hier -filter {REF_NAME==XPLL}] {
    # XPLL/CLKOUT0
    set clkout0 [get_pins -quiet -of $xpll -filter {IS_CONNECTED && REF_PIN_NAME==CLKOUT0}]
    if {$clkout0 != {}} {
      set bufgce_out [get_pins -quiet -filter {REF_PIN_NAME==O} -of [get_cells -quiet -of [get_pins -quiet -leaf -of [get_nets -quiet -of $clkout0] -filter {REF_PIN_NAME==I}]]]
      if {[llength $bufgce_out] >= 2} {
        set cdg [get_property -quiet CLOCK_DELAY_GROUP [get_nets -quiet -of $bufgce_out]]
        if {[lsort -unique $cdg] == {{}}} {
          # Add one %ELG per net in the list
          set msg "Property CLOCK_DELAY_GROUP is missing on the XPLL/CLKOUT0 nets: [string repeat {%ELG } [llength [get_nets -quiet -of $bufgce_out]]]"
          set vio [ create_drc_violation -name [info level 0] -msg $msg [get_nets -quiet -of $bufgce_out] ]
          lappend vios $vio
        } elseif {[llength [lsort -unique $cdg]] > 1} {
          set msg "Property CLOCK_DELAY_GROUP has different values ([lsort -unique $cdg]) on the XPLL/CLKOUT0 nets: [string repeat {%ELG } [llength [get_nets -quiet -of $bufgce_out]]]"
          set vio [ create_drc_violation -name [info level 0] -msg $msg [get_nets -quiet -of $bufgce_out] ]
          lappend vios $vio
        } else {
        }
      }
    }
  }
  catch { puts " -I- [lindex [info level 0] end] completed in [expr [clock seconds] -$start] seconds" }
  if {[llength $vios] > 0} {
    return -code error $vios
  } else {
    return {}
  }
}

catch {
  delete_drc_check [lindex $DRCINFO 0]
}

catch {
  create_drc_check -name [lindex $DRCINFO 0] -hiername [lindex $DRCINFO 2] \
    -desc [lindex $DRCINFO 3] -rule_body [lindex $DRCINFO 0] -severity [lindex $DRCINFO 4]
}

catch { 
  create_drc_ruledeck [lindex $DRCINFO 1]
}

catch {
  add_drc_checks -ruledeck [lindex $DRCINFO 1] [lindex $DRCINFO 0]
}

catch {
  # Remove DRCs from default ruledeck (2026.1 and above)
  remove_drc_checks -quiet [get_drc_checks -quiet EP_*] -ruledeck {default}
}
