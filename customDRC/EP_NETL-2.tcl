# This DRC flags medium fanout nets (>=200 & <2000)

# DCRINFO:
#    DRC ID : generate the check ID based on the filename
#    Rule deck
#    DRC Category
#    DRC message
#    DRC severity

set thresholdMin 200 ;  catch { set thresholdMin [::drc::get_value medium_fanout $thresholdMin] }
set thresholdMax 2000 ; catch { set thresholdMax [::drc::get_value high_fanout $thresholdMax] }

set DRCINFO [list \
  [file rootname [file tail [info script]]] \
  {EmuProto_checks} \
  {Netlist Checks} \
  "Net with medium fanout (>=$thresholdMin & <$thresholdMax)" \
  {Warning}
  ]

proc [lindex $DRCINFO 0] {} {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # Get threshold
  set thresholdMin 200 ;  catch { set thresholdMin [::drc::get_value medium_fanout $thresholdMin] }
  set thresholdMax 2000 ; catch { set thresholdMax [::drc::get_value high_fanout $thresholdMax] }
  # DRC code
  set hfn [get_nets -quiet -hierarchical -top_net_of_hierarchical_group -segment -filter [format { NAME =~  "*" && TYPE == "SIGNAL" && ( FLAT_PIN_COUNT >= %s && FLAT_PIN_COUNT < %s) } $thresholdMin $thresholdMax ] ] ; llength $hfn
  if {[llength $hfn]} {
    set L [list]
    foreach net $hfn fpin [get_property -quiet FLAT_PIN_COUNT $hfn] {
      lappend L [list $net [expr $fpin -1] ]
    }
    set L [lsort -index 1 -decreasing -integer $L]
    foreach elm $L {
      foreach {net fo} $elm { break }
      set driver [get_pins -quiet -leaf -of $net -filter {DIRECTION==OUT}]
      set msg "Net %ELG has a medium fanout (fanout=$fo / driver=[get_property -quiet REF_NAME $driver]/[get_property -quiet REF_PIN_NAME $driver])"
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
