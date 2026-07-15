# This DRC flags the number of nets with the property CLOCK_BUFFER_TYPE set

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
  {Property CLOCK_BUFFER_TYPE on nets} \
  {Advisory}
  ]

proc [lindex $DRCINFO 0] {} {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # DRC code
  set nets [get_nets -quiet -hier -filter {CLOCK_BUFFER_TYPE!={}}] ; llength $nets
  if {[llength $nets]} {
    foreach net $nets {
      set driver [get_pins -quiet -leaf -of $net -filter {DIRECTION==OUT}]
      set driverslr [get_slrs -quiet -of [get_cells -quiet -of $driver]]
      set loads [get_cells -quiet -of [get_pins -quiet -leaf -of $net -filter {DIRECTION==IN}]]
      set slrs [lsort -unique [get_slrs -quiet -of $loads]]
      set value [get_property -quiet CLOCK_BUFFER_TYPE $net]
      set fanout {n/a}
      catch { set fanout [expr [get_property -quiet FLAT_PIN_COUNT $net] -1] }
      set msg "Property CLOCK_BUFFER_TYPE=$value found on net %ELG (fanout=$fanout / driver=[get_property -quiet REF_NAME $driver] / driver SLR='$driverslr' / loads SLRs='$slrs')"
      set vio [ create_drc_violation -name [info level 0] -msg $msg $net ]
      lappend vios $vio
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
