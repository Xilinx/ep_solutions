# This DRC detects BUFGCE cells where the CE control comes from a register clocked by a high fanout clock net, which can lead to startup issues (fanout > 2000).

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
  {Startup logic driven by HFN clock} \
  {Warning}
  ]

proc [lindex $DRCINFO 0] {} {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # DRC code
  # Cache for net fanout to avoid redundant queries
  set netFanoutCache [dict create] 
  # Get all BUFGCE cells and their CE pins
  set bufgces [get_cells -quiet -hier -filter {REF_NAME == BUFGCE}]
  set pins [get_pins -quiet -of_objects $bufgces -filter {REF_PIN_NAME == CE && !IS_TIED}]
  foreach pin $pins {
    # Get unique clock pins driving this CE pin
    set clkpins [lsort -unique [all_fanin $pin -flat -startpoints_only]]
    foreach clkpin $clkpins {
      set net [get_nets -quiet -of $clkpin]
      if {![llength $net]} { continue }
      # Check net fanout with caching
      if {[dict exists $netFanoutCache $net]} {
        set fanout [dict get $netFanoutCache $net]
      } else {
        set fanout [get_property -quiet FLAT_PIN_COUNT $net]
        dict set netFanoutCache $net $fanout
      }
      # Flag if fanout exceeds threshold (subtract 1 to exclude the driving register)
      if {$fanout > 2000} {
        set msg "BUFGCE/CE pin %ELG is driven by a register with HFN clock net (fanout=[expr {$fanout - 1}])"
        lappend vios [create_drc_violation -name [info level 0] -msg $msg $pin]
        break
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
