# This file includes multiple custom DRCs

proc CUSTOM_DRC_BUCKET { drccheck } {
  set start [clock seconds]
  # List of violations
  set vios [list]
  # DRC code
  switch $drccheck {
    EP_BUCKET-1 {
      # This DRC bucketize the setup timing paths (setup violations only)
      set paths [filter -quiet [::drc::get spaths] {SLACK<0}] ; llength $paths
    }
    EP_BUCKET-2 {
      # This DRC bucketize the setup timing paths (setup violations only)
      set paths [filter -quiet [::drc::get spaths] {SLACK<0}] ; llength $paths
      if {[llength $paths] > 1} {
        # Worst path only
        set paths [lindex $paths 0]
      }
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
      incr pathnum
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
        EP_BUCKET-1 -
        EP_BUCKET-2 {
          # Clocks driven by BUFG_GT
          set bufg_gts [get_cells -quiet -hier -filter {REF_NAME=~BUFG_GT}] ; llength $bufg_gts
          set clocks [get_clocks -quiet -of [get_pins -quiet -of $bufg_gts -filter {DIRECTION==OUT}]]
          if {([lsearch -exact $clocks $spclk]!=-1) || ([lsearch -exact $clocks $epclk]!=-1)} {
            ##
            ## Setup violations on GT clocks (PCIE, ...)
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: GT_CLOCK: setup violation on a GT clock: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr != $epslr) && ($exception == {})} {
            ##
            ## Floorplanned startpoint/endpoint in different SLRs with missing MCP
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: CONSTR: constraint issue: missing MCP with startpoint/endpoint floorplanned in different SLRs: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr != $epslr) && ($exception != {})} {
            ##
            ## Floorplanned startpoint/endpoint in different SLRs with timing exception
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: CONSTR_OR_FP: constraint or floorplanning issue: path covered by timing exception with startpoint/endpoint floorplanned in different SLRs: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr == $epslr) && ($crossing == 0) && ($skew >= -1.0)} {
            ##
            ## Intra-SLR path with floorplanned startpoint/endpoint inside the same SLR (no SLR crossing + fair skew)
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: GP: GP issue: intra-SLR path with floorplanning constraints and fair skew: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {(($sppb != {}) || $spisfixed) && (($eppb != {}) || $episfixed) && ($spslr == $epslr) && ($crossing == 0) && ($skew < -1.0)} {
            ##
            ## Intra-SLR path with floorplanned startpoint/endpoint inside the same SLR (no SLR crossing + large skew)
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: GP_OR_CRP: GP + CRP issue: intra-SLR path with floorplanning constraints and large skew: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {( (($sppb == {}) && !$spisfixed) && (($eppb == {}) && !$episfixed) ) && ($spslr != $epslr)} {
            ##
            ## Startpoint/endpoint are partially floorplanned or not floorplanned
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: PART: partitioner issue: inter-SLR path without floorplanning constraints: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {( (($sppb == {}) && !$spisfixed) || (($eppb == {}) && !$episfixed) ) && ($spslr != $epslr)} {
            ##
            ## Startpoint/endpoint are partially floorplanned or not floorplanned
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: PART: partitioner issue: inter-SLR path with partial floorplanning constraints: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {($crossing > 0) && ($skew <= -1.0)} {
            ##
            ## Setup violation on an inter-SLR path with high skew
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: PART_OR_CRP: partitioner + CRP issue: inter-SLR path with large skew: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
          if {($crossing == 0) && ($skew <= -1.0)} {
            ##
            ## Setup violation on an intra-SLR path with high skew
            ##
            lappend vioPaths $path
            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: GP_OR_CRP: GP + CRP issue: intra-SLR path with large skew: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
            set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
            lappend vios $vio
            # Next path
            continue
          }
         if {($crossing > 0)} {
           ##
           ## Setup violation on an inter-SLR path
           ##
           lappend vioPaths $path
           set msg "$drccheck: path #[::drc::fpathnum $pathnum]: INTER_SLR: setup violation on inter-SLR path: more analysis needed: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
#            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: potential partitioner issue on inter-SLR path: more analysis needed: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
           set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
           lappend vios $vio
           # Next path
           continue
         }
         if {($crossing == 0)} {
           ##
           ## Setup violation on an intra-SLR path
           ##
           lappend vioPaths $path
           set msg "$drccheck: path #[::drc::fpathnum $pathnum]: INTRA_SLR: setup violation on intra-SLR path: more analysis needed: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
#            set msg "$drccheck: path #[::drc::fpathnum $pathnum]: potential GP issue on intra-SLR path: more analysis needed: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
           set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
           lappend vios $vio
           # Next path
           continue
        }
          # No bucket is found => still add the current path to the Tcl list so that all the paths are kept in order
          lappend vioPaths $path
          set msg "$drccheck: path #[::drc::fpathnum $pathnum]: UNKNOWN: NO BUCKET FOUND - NEEDS REVIEW: %ELG -> %ELG (slack=${slack}ns / skew=${skew}ns / levels=$lvl / path requirement=${req}ns / exception='$exception' / sp${sptag}='$spslr' / ep${eptag}='$epslr' / datapath${dptag}='$dp_slrs' / total crossings=$crossing )"
          set vio [ create_drc_violation -name [lindex [info level 0] end] -msg $msg $sppin $eppin]
          lappend vios $vio
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
      if {[catch { report_timing -quiet -of $vioPaths -name $drccheck } errorstring]} {
        puts " -E- $errorstring"
      }
    }
    if {$::drc::params(rpt) == 1} {
      if {[catch { report_timing -quiet -of $vioPaths -file ${::drc::params(outputDir)}/${drccheck}.rpt } errorstring]} {
        puts " -E- $errorstring"
      }
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


::drc::create_custom_drc {EP_BUCKET-1} {CUSTOM_DRC_BUCKET} \
                         {Bucketization} \
                         {Top-N paths with setup violations} \
                         {Warning}

::drc::create_custom_drc {EP_BUCKET-2} {CUSTOM_DRC_BUCKET} \
                         {Bucketization} \
                         {WNS path with setup violation} \
                         {Warning}

catch {
  # Remove DRCs from default ruledeck (2026.1 and above)
  remove_drc_checks -quiet [get_drc_checks -quiet EP_*] -ruledeck {default}
}
