# This file includes multiple custom DRCs

proc CUSTOM_DRC_PART { drccheck } {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # DRC code
  switch $drccheck {
    EP_TIMING-1 {
      # This DRC flags the timing paths that have no timing exception, a high number of logic levels and a small path requirement
      set paths [filter -quiet [::drc::get spaths] {SLACK<0 && LOGIC_LEVELS>=20 && REQUIREMENT<10 && EXCEPTION=={}}] ; llength $paths
    }
    EP_TIMING-2 {
      # This DRC flags the inter-SLR timing paths with no timing exception.
      # Both startpoint/endpoints are pblocked inside different SLRs
      set paths [filter -quiet [::drc::get spaths] {SLACK<0 && EXCEPTION=={}}] ; llength $paths
    }
    EP_TIMING-3 {
      # This DRC flags the inter-SLR timing paths with a sub-optimal MCP multiplier.
      # Both startpoint/endpoints are pblocked inside different SLRs
      set paths [filter -quiet [::drc::get spaths] {SLACK<0 && EXCEPTION=~{MultiCycle*}}] ; llength $paths
    }
    EP_PART-5 {
      # This DRC flags the inter-SLR timing paths with sub-optimal partitioning: the datapath logic unnecessarily crosses SLRs.
      # The sub-optimality is based on the SLR assigment of the datapath logic versus the SLR location of the startpoint/endpoint.
      # Both startpoint/endpoints are pblocked inside different SLRs
      set paths [filter -quiet [::drc::get spaths] {SLACK<0}] ; llength $paths
    }
    EP_PART-6 {
      # This DRC flags the timing paths that have the startpoint/endpoint inside the same SLR but the partitioning results in SLR crossing.
      # The partitioning result in the path being inter-SLR instead of intra-SLR.
      # Both startpoint/endpoints are pblocked inside the same SLRs
      set paths [filter -quiet [::drc::get spaths] {SLACK<0}] ; llength $paths
    }
    EP_PART-7 -
    EP_PART-8 {
      # EP_PART-7: this DRC flags the timing paths that have a single-cell sub-optimality crossing SLR.
      # EP_PART-8: this DRC flags the timing paths that have a multi-cells sub-optimality crossing SLR.
      # Non-optimal LUT partitioning
      set paths [filter -quiet [::drc::get spaths] {SLACK<0}] ; llength $paths
    }
    default {
      puts " -E- Unsupported check $drccheck"
      return -code ok
    }
  }
# Debug
# set paths $::drc::db(spaths)

  set vioPaths [list]
  if {[llength $paths]} {
    set pathnum 0
    for {set pathidx 0} {$pathidx < [llength $paths]} {incr pathidx} {
      if {[llength $paths] == 1} {
        set path $paths
      } else {
        set path [lindex $paths $pathidx]
      }
      set slack          [::drc::get setup:slack:$path]
      set lvl            [::drc::get setup:lvl:$path]
      set req            [::drc::get setup:req:$path]
      set exception      [::drc::get setup:exception:$path]
      set skew           [::drc::get setup:skew:$path]
      set sp             [::drc::get setup:sp:$path]
      set sppin          [::drc::get setup:sppin:$path]
      set sppb           [::drc::get setup:sppb:$path]
      set spclk          [::drc::get setup:spclk:$path]
      set spslr          [::drc::get setup:spslr:$path]
      set sploc          [::drc::get setup:sploc:$path]
      set spisfixed      [::drc::get setup:spisfixed:$path]
      set ep             [::drc::get setup:ep:$path]
      set eppin          [::drc::get setup:eppin:$path]
      set eppb           [::drc::get setup:eppb:$path]
      set epclk          [::drc::get setup:epclk:$path]
      set epslr          [::drc::get setup:epslr:$path]
      set eploc          [::drc::get setup:eploc:$path]
      set episfixed      [::drc::get setup:episfixed:$path]
      set nets           [::drc::get setup:nets:$path]
      set crossing       [::drc::get setup:crossing:$path]
      set crossing_spep  [::drc::get setup:crossing_spep:$path]
      set cells          [::drc::get setup:cells:$path]
      set nets           [::drc::get setup:nets:$path]
      set pblocks        [::drc::get setup:pblocks:$path]
      set slrs           [::drc::get setup:slrs:$path]
      # Tag startpoint/endp;oint with '*' when they are pblocked or have a fixed LOC
      if {($sppb != {}) || $spisfixed} { set sptag {*} } else { set sptag {} }
      if {($eppb != {}) || $episfixed} { set eptag {*} } else { set eptag {} }
      # Unique list of SLRs for the datapath
      set dp_slrs [lsort -unique [lsearch -all -inline -not -exact $slrs {}]]
      # Unique list of Pblocks for the datapath
      set dp_pblocks [lsort -unique [lsearch -all -inline -not -exact $pblocks {}]]
      # Tag datapath with '*' when all the cells are pblocked
      if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ([llength [lsearch -all -inline -not -exact [lrange $pblocks 1 end-1] {}]] == [llength [lrange $cells 1 end-1]])} { set dptag {*} } else { set dptag {} }
#       if {[llength $dp_pblocks] == [llength $cells]} { set dptag {*} } else { set dptag {} }
      switch $drccheck {
        EP_TIMING-1 {
          incr pathnum
          set msg "$drccheck: path #[::drc::fpathnum $pathnum] with a tight path requirement, high number of logic levels and no timing exception: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception')"
          set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
          lappend vioPaths $path
          lappend vios $vio
        }
        EP_TIMING-2 {
          # Count the number of pblocked instances on the path (exclude empty strings '{}')
#           set count [llength [lsearch -all -inline -not -exact $pblocks {}] ]
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr != $epslr)} {
            incr pathnum
            lappend vioPaths $path
            set msg "$drccheck: inter-SLR path #[::drc::fpathnum $pathnum] with startpoint & endpoint floorplanned in different SLRs and no timing exception: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
          }
        }
        EP_TIMING-3 {
          # Get the MCP multiplier
          if {![regexp -nocase {MultiCycle.*([0-9]+)\s*$} $exception - multiplier]} {
            # No MCP
            continue
          }
          # The number of crossings between the startpoint and endpoint must be less or equal than the MCP multiplier minus 1
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr != $epslr) && ($crossing_spep > [expr $multiplier -1])} {
            incr pathnum
            lappend vioPaths $path
            set msg "$drccheck: inter-SLR path #[::drc::fpathnum $pathnum] with startpoint & endpoint floorplanned in different SLRs and a MCP multiplier that might be too small ($multiplier) for the number of crossings ($crossing_spep) between the startpoint & endpoint: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
          }
        }
        EP_PART-5 {
          # List of SLRs for the datapath
          set L [lsort -unique [lsearch -all -inline -not -exact $slrs {}]]
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr != $epslr) && ($crossing > $crossing_spep)} {
            incr pathnum
            lappend vioPaths $path
            set msg "$drccheck: inter-SLR path #[::drc::fpathnum $pathnum] with startpoint & endpoint floorplanned and some datapath cells are placed inside a non-optimal SLR(s): %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
          }
        }
        EP_PART-6 {
          # List of SLRs for the datapath
          set L [lsort -unique [lsearch -all -inline -not -exact $slrs {}]]
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr == $epslr) && ($crossing >= 1)} {
            incr pathnum
            lappend vioPaths $path
            set msg "$drccheck: inter-SLR path #[::drc::fpathnum $pathnum] with startpoint & endpoint floorplanned inside the same SLR and some datapath cells are placed inside a non-optimal SLR(s): %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
          }
        }
        EP_PART-7 {
          if {($lvl == 0) || ([llength $slrs] <= 2)} {
            # Level=0 => skip path
            continue
          }
          # List of SLRs for the datapath
          set L [lsort -unique [lsearch -all -inline -not -exact $slrs {}]]
          for {set idx 1} {$idx < [expr [llength $slrs] -1]} {incr idx} {
            # Get the SLR index (0 instead of SLR0)
            set slr [lindex $slrs $idx]
            set slr_before [lindex $slrs [expr $idx -1] ]
            set slr_after [lindex $slrs [expr $idx +1] ]
            if {[::drc::isOptimalSLRPart $slr_before $slr $slr_after] == 0} {
              incr pathnum
              # The ordered list of SLRs points to a non-optimal partitioning
              lappend vioPaths $path
              set msg "$drccheck: inter-SLR path #[::drc::fpathnum $pathnum] with single-cell SLR-crossing sub-optimality: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
              set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
              lappend vios $vio
              # Stop at first single non-optimality found
              break
            }
          }
        }
        EP_PART-8 {
# puts "\n<path><$path><lvl:$lvl>"
          if {($lvl == 0) || ([llength $slrs] <= 2)} {
            # Level=0 => skip path
# puts "skip path <lvl:$lvl><slrs:$slrs>"
            continue
          }
          # List of SLRs for the datapath
          set L $slrs
          # Remove consecutive duplicate elements in the ordered list of SLRs
#           set slrs [remove_consecutive_duplicates $slrs]
# puts "<slrs:$slrs>"
          if {[llength $slrs] <= 3} {
            # Skip path
            continue
          }
          for {set idx 1} {$idx < [expr [llength $slrs] -2]} {incr idx} {
# puts "for:<idx:$idx>"
            # Get the SLR index (0 instead of SLR0)
            set slr [lindex $slrs $idx]
            set slr_before [lindex $slrs [expr $idx -1] ]
            set idx2 0
            set multi 0
            # Search for consecutive SLRs from $slr, with 2 or more consecutive SLRs
            # For example: SLR0 SLR0  or   SLR1 SLR1 SLR1
            # Compact these consecutive SLRs into a single one and keep track of the match with $multi=1
            while {1} {
              set slr_after [lindex $slrs [expr $idx + $idx2 +1] ]
              if {($slr_after == $slr)} {
                # At least 2 consecutive cells inside the same SLR $slr => multi-cells
                set multi 1
              }
# puts "while:<[join [list $slr_before $slr $slr_after] {:}]><idx:$idx><idx2:$idx2><slr_after:$slr_after><multi:$multi>"
              if {$slr_after != $slr} {
# puts "break:<$slr_after != $slr><multi:$multi>"
                break
              }
              if {[expr $idx + $idx2] >= [expr [llength $slrs] -2]} {
# puts "break:<[expr $idx + $idx2] >= [expr [llength $slrs] -2]><multi:$multi>"
                # If the max number of SLRs has been reach, stop
                # and force $multi=0 since the topology cannot trigger a violation
                set multi 0
                break
              }
              # Forward looking of the next SLR
              incr idx2
            }
            if {$multi} {
              # If multi-cells has been detected => update the variable $idx
              # to point to the next SLR that needs to be analyzed after the consecutive SLRs
              incr idx $idx2
            }
# puts "<[join [list $slr_before $slr $slr_after] {:}]><idx:$idx><idx2:$idx2><multi:$multi>"
            if {$multi && ([::drc::isOptimalSLRPart $slr_before $slr $slr_after] == 0)} {
              incr pathnum
              # The ordered list of SLRs points to a non-optimal partitioning
              lappend vioPaths $path
              set msg "$drccheck: inter-SLR path #[::drc::fpathnum $pathnum] with multi-cell(s) SLR-crossing sub-optimality: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / SLRs pattern='$slrs' / SLRs list='$dp_slrs' / total crossings=$crossing )"
# puts "<msg:$msg>"
              set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
              lappend vios $vio
              # Stop at first multi-cells non-optimality found
              break
            }
          }
        }
        default {
          puts " -E- Unsupported check $drccheck"
          continue
        }
      }
    }
  }
  if {[llength $vioPaths]} {
    if {$::drc::params(gui) == 1} {
      report_timing -quiet -of $vioPaths -name $drccheck
    }
    if {$::drc::params(rpt) == 1} {
      report_timing -quiet -of $vioPaths -file ${::drc::params(outputDir)}/${drccheck}.rpt
      puts " -I- Custom DRC $drccheck: [file normalize ${::drc::params(outputDir)}/${drccheck}.rpt]"
    }
  }
  catch { puts " -I- $drccheck completed in [expr [clock seconds] -$start] seconds" }
  if {[llength $vios] > 0} {
    return -code error $vios
  } else {
    return {}
  }
}


::drc::create_custom_drc {EP_TIMING-1} {CUSTOM_DRC_PART} \
                         {Timing Constraint} \
                         {Paths with missing MCP} \
                         {Warning}

::drc::create_custom_drc {EP_TIMING-2} {CUSTOM_DRC_PART} \
                         {Timing Constraint} \
                         {Inter-slr paths with missing MCP  (startpoint/endpoint floorplanned inside different SLRs)} \
                         {Warning}

::drc::create_custom_drc {EP_TIMING-3} {CUSTOM_DRC_PART} \
                         {Timing Constraint} \
                         {Inter-slr paths with sub-optimal MCP multiplier (startpoint/endpoint floorplanned inside different SLRs)} \
                         {Warning}

::drc::create_custom_drc {EP_PART-5} {CUSTOM_DRC_PART} \
                         {Partitioning Solution} \
                         {Sub-optimal SLR-crossing for datapath cells (startpoint/endpoint floorplanned inside different SLRs)} \
                         {Warning}

::drc::create_custom_drc {EP_PART-6} {CUSTOM_DRC_PART} \
                         {Partitioning Solution} \
                         {Sub-optimal SLR-crossing for datapath cells (startpoint/endpoint floorplanned inside same SLR)} \
                         {Warning}

::drc::create_custom_drc {EP_PART-7} {CUSTOM_DRC_PART} \
                         {Partitioning Solution} \
                         {Single cell SLR-crossing sub-optimality} \
                         {Warning}

::drc::create_custom_drc {EP_PART-8} {CUSTOM_DRC_PART} \
                         {Partitioning Solution} \
                         {Multi cell(s) SLR-crossing sub-optimality} \
                         {Warning}

catch {
  # Remove DRCs from default ruledeck (2026.1 and above)
  remove_drc_checks -quiet [get_drc_checks -quiet EP_*] -ruledeck {default}
}
