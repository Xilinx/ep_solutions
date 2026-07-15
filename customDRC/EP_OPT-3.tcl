# This DRC flags the number of nets with the property MARK_DEBUG=1

# DCRINFO:
#    DRC ID : generate the check ID based on the filename
#    Rule deck
#    DRC Category
#    DRC message
#    DRC severity
set DRCINFO [list \
  [file rootname [file tail [info script]]] \
  {EmuProto_checks} \
  {Optimization Constraints} \
  {Property MARK_DEBUG on nets} \
  {Advisory}
  ]

proc [lindex $DRCINFO 0] {} {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # DRC code
  set nets [get_nets -quiet -hier -filter {MARK_DEBUG==1}]; llength $nets
  if {[llength $nets]} {
    set msg "Property MARK_DEBUG found on [llength $nets] nets"
    set vio [ create_drc_violation -name [info level 0] -msg $msg ]
    lappend vios $vio
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
