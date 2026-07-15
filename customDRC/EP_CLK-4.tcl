# This DRC flags some missing or mismatch of CLOCK_DELAY_GROUP property for the MMCM feedback loop and CLKOUT0

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
  {Missing CLOCK_DELAY_GROUP for MMCM feedback loop} \
  {Warning}
  ]

proc [lindex $DRCINFO 0] {} {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # DRC code

  # The MMCM feedback loop should have a CLOCK_DELAY_GROUP with CLKOUT0
  foreach mmcm [get_cells -quiet -hier -filter {REF_NAME==MMCME5}] {
    set clkout0 [get_pins -quiet -of $mmcm -filter {IS_CONNECTED && REF_PIN_NAME==CLKOUT0}]
    set fbin [get_pins -quiet -of $mmcm -filter {IS_CONNECTED && REF_PIN_NAME==CLKFBIN}]
    if {$clkout0 != {}} {
      set bufgce_out [get_pins -quiet -filter {REF_PIN_NAME==O} -of [get_cells -quiet -of [get_pins -quiet -leaf -of [get_nets -quiet -of $clkout0] -filter {REF_PIN_NAME==I}]]]
      if {[llength $bufgce_out] > 0} {
        # Only keep non empty strings for CLOCK_DELAY_GROUP
        set cdg_clkout0 [lsearch -all -inline -not -exact [lsort -unique [get_property -quiet CLOCK_DELAY_GROUP [get_nets -quiet -of $bufgce_out]]] {}]
        set cdg_fb [get_property -quiet CLOCK_DELAY_GROUP [get_nets -quiet -of $fbin]]
        if {($cdg_fb == {}) && ($cdg_clkout0 == {})} {
          set msg "Property CLOCK_DELAY_GROUP is missing for the MMCM feedback loop and CLKOUT0 clocks (%ELG)"
          set vio [ create_drc_violation -name [info level 0] -msg $msg $mmcm ]
          lappend vios $vio
        } elseif {$cdg_fb == {}} {
          set msg "Property CLOCK_DELAY_GROUP is missing for MMCM feedback loop net %ELG (%ELG)"
          set vio [ create_drc_violation -name [info level 0] -msg $msg [get_nets -quiet -of $fbin] $mmcm ]
          lappend vios $vio
        } else {
          if {[lsearch -exact $cdg_clkout0 $cdg_fb]==-1} {
            set msg "Mismatch of the property CLOCK_DELAY_GROUP between the MMCM feedback loop (CDG=$cdg_fb) and the CLKOUT0 clocks (CDG=$cdg_clkout0) (MMCM:%ELG)"
            set vio [ create_drc_violation -name [info level 0] -msg $msg $mmcm ]
            lappend vios $vio
          }
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
