##########################################
#
# Custom DRCs for E&P
#
#
#Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
#This file contains confidential and proprietary information of Xilinx, Inc. and is protected under U.S. and international copyright and other intellectual property laws.
#DISCLAIMER
#This disclaimer is not a license and does not grant any rights to the materials distributed herewith. Except as otherwise provided in a valid license issued to you by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including negligence, or under any other theory of liability) for any loss or damage of any kind or nature related to, arising under or in connection with these materials, including for any direct, or any indirect, special, incidental, or consequential loss or damage (including loss of data, profits, goodwill, or any type of loss or damage suffered as a result of any action brought by a third party) even if such damage or loss was reasonably foreseeable or Xilinx had been advised of the possibility of the same.
#CRITICAL APPLICATIONS
#Xilinx products are not designed or intended to be fail-safe, or for use in any application requiring fail-safe performance, such as life-support or safety devices or systems, Class III medical devices, nuclear facilities, applications related to the deployment of airbags, or any other applications that could lead to death, personal injury, or severe property or environmental damage (individually and collectively, "Critical Applications"). Customer assumes the sole risk and liability of any use of Xilinx products in Critical Applications, subject only to applicable laws and regulations governing limitations on product liability.
#THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
##########################################

# Example:
# ========
# # Source the top script: only once
# source all.tcl
#
# # Post-place DRCs
# file mkdir ./vivado/postplace_drcs
# ::drc::config -max 100 -rpt -odir ./vivado/postplace_drcs
# report_drc -ruledecks EmuProto_checks -file ./vivado/postplace_drcs.rpt
#
# # Post-route DRCs
# file mkdir ./vivado/postroute_drcs
# ::drc::config -max 100 -rpt -odir ./vivado/postroute_drcs
# report_drc -ruledecks EmuProto_checks -file ./vivado/postroute_drcs.rpt

namespace eval ::drc {
  catch {unset params}
  array set params [list gui 0 rpt 1 npaths 100 outputDir {.} debug 0]
  catch {unset db}
#   catch {unset var}
#   set db(paths) [list]
  # List of files that have been read
  set files [list]
}

proc ::drc::lshift { inputlist } {
  upvar $inputlist argv
  set arg  [lindex $argv 0]
  set argv [lrange $argv 1 end]
  return $arg
}

# Remove duplicate elements without sorting
# Usage:
#  % set testlist [list 2 2 3 3 5 5 5 2 2 1 1]
#  % lsort -command nosort -unique $testlist
#  => 1 2 5 3 2 #unique list in reverse order
proc ::drc::nosort {val1 val2} {
  if {$val1 == $val2} {
    return 0
  } else {
    return 1
  }
}

# remove_consecutive_duplicates {SLR0 SLR0 SLR3 SLR3 SLR3 SLR0 SLR1 SLR1 SLR1 SLR3 SLR3 SLR3 SLR3 SLR0 SLR1}
# => SLR0 SLR3 SLR0 SLR1 SLR3 SLR0 SLR1
proc ::drc::remove_consecutive_duplicates {list_items} {
  return [lmap item $list_items {
    if {![info exists prev] || $item ne $prev} {
      set prev $item
    } else {
      continue
    }
  }]
}

proc ::drc::dputs {args} {
  variable params
  if {$params(debug)} {
    eval [concat puts $args]
  }
  return -code ok
}


proc ::drc::dump {args} {
  variable db
# puts "<args:{*}$args>"
#   parray db {*}$args
#   parray db [format {*:{tdmnet_6_0_3_muxin_bit_2_tdmx_0_12_iff_120_s_0/C --> xtdm_707/versal_txrx/inst/cdns_ptm_advio_22tx30rx_xcvp1902_1200_phy_i/inst/BANK_WRAPPER_INST0/NIBBLE[1].UNISIM.I_XPHY/D3[3]}}]
  return -code ok
}


# Return the SLR of a pblock
proc ::drc::pblock2slr {pblock} {
  set pbs [get_pblocks -quiet $pblock]
  if {$pbs == {}} {
    return {}
  }
  set slrs [list]
  foreach pb $pbs {
    # SLICE_X410Y970:SLICE_X425Y995
    # CLOCKREGION_X7Y7:CLOCKREGION_X7Y7 CLOCKREGION_X6Y6:CLOCKREGION_X7Y6 CLOCKREGION_X7Y5:CLOCKREGION_X7Y5
    set range [get_property -quiet GRID_RANGES $pb]
    if {$range == {}} {
      continue
    }
    if {[regexp {SLR([0-9]):SLR([0-9])} $range - n m]} {
      if {$n==$m} { return SLR$n }
    }
    regsub -all {CLOCKREGION_} $range {} range
    # TODO: expand the range to cover pblocks crossing multiple SLRs
    regsub -all { } $range {:} range
    foreach elm [split $range :] {
      set elm [string trim $elm]
      set slr {}
      switch -regexp -nocase -- $elm {
        {^(S[0-9]+)?X[0-9]+Y[0-9]+$} {
          set slr [get_slrs -quiet -of [get_clock_region -quiet $elm]]
        }
        {^SLICE_.+$} {
          set slr [get_slrs -quiet -of [get_sites -quiet $elm]]
        }
        {^.+_(S[0-9]+)?X[0-9]+Y[0-9]+$} {
          set slr [get_slrs -quiet -of [get_sites -quiet $elm]]
        }
        default {
          puts " -E- pblock $pb: $elm"
        }
      }
      if {$slr != {}} {
        lappend slrs $slr
      }
    }
  }
  return [lsort -unique $slrs]
}


# Format path number (pathnum) by adding leading 0 depending on the max number of paths
# The formating with leading 0 is needed to keep the DRC inside the report file ordered as they have been generated
proc ::drc::fpathnum {num} {
  variable params
  set npath $params(npaths)
  if {$npath < 10} { return [format {%01d} $num] }
  if {$npath < 100} { return [format {%02d} $num] }
  if {$npath < 1000} { return [format {%03d} $num] }
  if {$npath < 10000} { return [format {%04d} $num] }
  return [format {%05d} $num]
}


proc ::drc::create_custom_drc { check proc category description severity } {
  # Create the proc in the global namespace
  uplevel #0 [format {
    proc %s {} {
      return [%s [info level 0] ]
    }
  } $check $proc]
  # Create rule deck
  catch {
    create_drc_ruledeck {EmuProto_checks}
  }
  # Delete existing check
  catch {
    delete_drc_check $check
  }
  # Create check
  create_drc_check -name $check -hiername $category \
                   -desc $description \
                   -rule_body $check -severity $severity
  # Add check to rule deck
  add_drc_checks -ruledeck {EmuProto_checks} $check
}


proc ::drc::get_value {key {default {}}} {
  variable var
  # Get the value for the key
  if {[info exists var($key)]} {
    set val $var($key)
  } else {
#     puts " -E- :drc::get_value : key '$key' does not exist"
    set val $default
  }
# puts "<key:$key><val:$val>"
  return $val
}


proc ::drc::set_value {key value} {
  variable var
  # Set the value for the key
  set var($key) $value
  # Reload all the DRC Tcl scripts
  reload
  #
  return $value
}


proc ::drc::reload {args} {
  variable files
  foreach file $files {
#     puts " -I- sourcing DRC '$file'"
    catch {source -notrace $file}
  }
}


proc ::drc::get {key} {
  variable db
  # Build the internal data structure (if needed)
  build
  # Get the value for the key
  if {[info exists db($key)]} {
    set val $db($key)
  } else {
    puts " -E- :drc::get : key '$key' does not exist"
    set val {!ERROR_KEY!}
  }
# puts "<key:$key><val:$val>"
  return $val
}


proc ::drc::update { tag paths } {
  variable params
  variable db

  if {[llength $paths]} {
    set slacks [get_property -quiet SLACK $paths]
    set levels [get_property -quiet LOGIC_LEVELS $paths]
    set requirements [get_property -quiet REQUIREMENT $paths]
    set exceptions [get_property -quiet EXCEPTION $paths]
    set skews [get_property -quiet SKEW $paths]
    set sps [get_property -quiet STARTPOINT_PIN $paths]
    set eps [get_property -quiet ENDPOINT_PIN $paths]
    set cells [get_cells -quiet -of $paths]
    catch {unset db(pblock)}
    foreach cell [concat $cells [get_cells -quiet -of $sps] [get_cells -quiet -of $eps] ] {
      set db(pblock:$cell) [get_pblocks -quiet -of $cell]
    }
    catch {unset db(slr)}
    foreach cell [concat $cells [get_cells -quiet -of $sps] [get_cells -quiet -of $eps] ] {
      set db(slr:$cell) [get_slrs -quiet -of $cell]
    }
    catch {unset db(slack)}
    for {set idx 0} {$idx < [llength $paths]} {incr idx} {
      # Note: keep the get_* commands below to avoid side issues when $paths has only 1 timing path.
      #       In that case, the previous 'lindex ... 0' converted objects into strings
      set path [lindex $paths $idx]
      set slack [lindex $slacks $idx]
      set lvl [lindex $levels $idx]
      set req [lindex $requirements $idx]
      set exception [lindex $exceptions $idx]
      set skew [lindex $skews $idx]
      set sp [get_pins -quiet [lindex $sps $idx]]
      set spCell [get_cells -quiet -of $sp]
      set ep [get_pins -quiet [lindex $eps $idx]]
      set epCell [get_cells -quiet -of $ep]
      #
      set db(${tag}:slack:$path)     $slack
      set db(${tag}:lvl:$path)       $lvl
      set db(${tag}:req:$path)       $req
      set db(${tag}:exception:$path) $exception
      set db(${tag}:skew:$path)      $skew
      set db(${tag}:sp:$path)        [get_cells -quiet $spCell]
      set db(${tag}:sppin:$path)     [get_pins -quiet $sp]
      set db(${tag}:sppb:$path)      [get_pblocks -quiet -of $spCell]
      set db(${tag}:spclk:$path)     [get_clocks -quiet [get_property -quiet STARTPOINT_CLOCK $path]]
      set db(${tag}:spslr:$path)     [get_slrs -quiet -of $spCell]
      set db(${tag}:sploc:$path)     [get_property -quiet LOC $spCell]
#       set db(${tag}:spisfixed:$path) [expr [get_property -quiet IS_FIXED $spCell]==1? 1 : 0]
      if {[get_property -quiet IS_FIXED $spCell] == 1} {
        set db(${tag}:spisfixed:$path) 1
      } else {
        set db(${tag}:spisfixed:$path) 0
      }
      set db(${tag}:ep:$path)        [get_cells -quiet $epCell]
      set db(${tag}:eppin:$path)     [get_pins -quiet $ep]
      set db(${tag}:eppb:$path)      [get_pblocks -quiet -of $epCell]
      set db(${tag}:epclk:$path)     [get_clocks -quiet [get_property -quiet ENDPOINT_CLOCK $path]]
      set db(${tag}:epslr:$path)     [get_slrs -quiet -of $epCell]
      set db(${tag}:eploc:$path)     [get_property -quiet LOC $epCell]
#       set db(${tag}:episfixed:$path) [expr [get_property -quiet IS_FIXED $epCell]==1? 1 : 0]
      if {[get_property -quiet IS_FIXED $epCell] == 1} {
        set db(${tag}:episfixed:$path) 1
      } else {
        set db(${tag}:episfixed:$path) 0
      }
     # Calculate the number of SLRs crossing between the startpoint and the endpoint
      set crossing 0
      # E.g: SLR0:SLR2
      switch [join [lsort -dictionary -unique [list $db(${tag}:spslr:$path) $db(${tag}:epslr:$path)]] {:}] {
        "SLR0:SLR1" { incr crossing 1 }
        "SLR0:SLR2" { incr crossing 2 }
        "SLR0:SLR3" { incr crossing 1 }
        "SLR1:SLR2" { incr crossing 1 }
        "SLR1:SLR3" { incr crossing 2 }
        "SLR2:SLR3" { incr crossing 1 }
      }
# puts "<crossing><[join [lsort -dictionary -unique [list $db(${tag}:spslr:$path) $db(${tag}:epslr:$path)]] {:}]:$crossing>"
      set db(${tag}:crossing_spep:$path) $crossing
      # Datapath cells and nets
      set cells [get_cells -quiet -of $path]
      set db(${tag}:cells:$path) $cells
      set nets [get_nets -quiet -parent_net -of $path]
      set db(${tag}:nets:$path) $nets
      # Pblocks and SLRs
      set pblocks [list]
      set slrs [list]
      foreach cell $cells {
        if {[info exists db(pblock:$cell)] && ($db(pblock:$cell) != {})} {
          lappend pblocks $db(pblock:$cell)
        } else {
          set db(pblock:$cell) [get_pblocks -quiet -of $cell]
          lappend pblocks $db(pblock:$cell)
        }
        if {[info exists db(slr:$cell)] && ($db(slr:$cell) != {})} {
          lappend slrs $db(slr:$cell)
        } else {
          set db(slr:$cell) [get_slrs -quiet -of $cell]
          lappend slrs $db(slr:$cell)
        }
      }
      # Ordered list of pblocks
      set db(${tag}:pblocks:$path) $pblocks
      # Ordered list of slrs
      set db(${tag}:slrs:$path) $slrs
      # Calculate the total number of SLRs crossing in the path
      # Iterate through all the pairs of datapath cells and compare their respective SLR
      set crossing 0
      for {set idx2 0} {$idx2 < [expr [llength $cells] -1]} {incr idx2} {
        set from [lindex $cells $idx2]
        set fromSlr [::drc::get slr:$from]
        set to [lindex $cells [expr $idx2 +1]]
        set toSlr [::drc::get slr:$to]
        if {[catch {
          switch [join [lsort -dictionary -unique [list $fromSlr $toSlr]] {:}] {
            "SLR0:SLR1" { incr crossing 1 }
            "SLR0:SLR2" { incr crossing 2 }
            "SLR0:SLR3" { incr crossing 1 }
            "SLR1:SLR2" { incr crossing 1 }
            "SLR1:SLR3" { incr crossing 2 }
            "SLR2:SLR3" { incr crossing 1 }
          }
        } errorstring]} {
          puts " -E- $errorstring"
          puts " -E- fromSlr:$fromSlr / toSlr:$toSlr"
        }
      }
      set db(${tag}:crossing:$path) $crossing
    }
  }

  if {$params(debug)} {
    parray db
  }
#   parray db
#   parray db {*:{tdmnet_6_0_2_muxin_bit_7_tdmx_0_12_iff_117_s_0/C --> xtdm_707/versal_txrx/inst/cdns_ptm_advio_22tx30rx_xcvp1902_1200_phy_i/inst/BANK_WRAPPER_INST0/NIBBLE[1].UNISIM.I_XPHY/D3[0]}}
  return -code ok
}


proc ::drc::build { args } {
  variable params
  variable db
  if {![info exist db(spaths)]} {
    set start [clock seconds]
#     set db(paths) [get_timing_paths -quiet -setup -nworst 1 -max $params(npaths)]
    set db(spaths) [get_timing_paths -quiet -setup -nworst 1 -max $params(npaths)]
    set db(hpaths) [get_timing_paths -quiet -hold -nworst 1 -max $params(npaths)]
    #
    ::drc::update setup $db(spaths)
    ::drc::update hold $db(hpaths)
    #
    set stop [clock seconds]
    puts " -I- get_timing_paths in [expr $stop - $start] seconds"
  }

  if {0 && ![info exist db(rci)]} {
    set start [clock seconds]
    set report [report_clock_interaction -quiet -no_header -delay_type min_max -return_string]
    set clock_interaction_table [::parse::parseClockInteractionReport $report]
    set db(rci) $report
    #
    set colFromClock -1
    set colToClock -1
    set colCommonPrimaryClock -1
    set colInterClockConstraints -1
    set colTNSFailingEndpoints -1
    set colTNSTotalEndpoints -1
    set colWNSClockEdges -1
    set colWNS -1
    set colTNS -1
    set colWNSPathRequirement -1
    set colTHSFailingEndpoints -1
    set colTHSTotalEndpoints -1
    set colWHS -1
    set colTHS -1
    set colWHSPathRequirement -1
    set colClockPairClassification -1
    if {$clock_interaction_table != {}} {
      set header [lindex $clock_interaction_table 0]
      for {set i 0} {$i < [llength $header]} {incr i} {
        # Header from report_clock_interaction:
        #   {From Clock} {To Clock} {WNS Clock Edges} WNS(ns) TNS(ns) {TNS Failing Endpoints} {TNS Total Endpoints} {WNS Path Requirement(ns)} {Common Primary Clock} {Inter-Clock Constraints}
        switch -regexp -- [lindex $header $i] {
          "From Clock" {
            set colFromClock $i
          }
          "To Clock" {
            set colToClock $i
          }
          "Common Primary Clock" {
            set colCommonPrimaryClock $i
          }
          "Inter-Clock Constraints" {
            set colInterClockConstraints $i
          }
          "TNS Failing Endpoints" {
            set colTNSFailingEndpoints $i
          }
          "TNS Total Endpoints" {
            set colTNSTotalEndpoints $i
          }
          "WNS Clock Edges" {
            set colWNSClockEdges $i
          }
          "WNS\\\(ns\\\)" {
            set colWNS $i
          }
          "TNS\\\(ns\\\)" {
            set colTNS $i
          }
          "WNS Path Requirement" {
            set colWNSPathRequirement $i
          }
          "THS Failing Endpoints" {
            set colTHSFailingEndpoints $i
          }
          "THS Total Endpoints" {
            set colTHSTotalEndpoints $i
          }
          "WHS Clock Edges" {
            set colWHSClockEdges $i
          }
          "WHS\\\(ns\\\)" {
            set colWHS $i
          }
          "THS\\\(ns\\\)" {
            set colTHS $i
          }
          "WHS Path Requirement" {
            set colWHSPathRequirement $i
          }
          "Clock-Pair Classification" {
            set colClockPairClassification $i
          }
          default {
          }
        }
      }
    }
    #
    set n 0
    set clockPairs [list]
    set setupViosClockPairs [list]
    set holdViosClockPairs [list]
    foreach row [lrange $clock_interaction_table 1 end] {
      incr n
      set fromClock [lindex $row $colFromClock]
      set toClock [lindex $row $colToClock]
      set failingEndpoints [lindex $row $colTNSFailingEndpoints]
      set totalEndpoints [lindex $row $colTNSTotalEndpoints]
      set commonPrimaryClock [lindex $row $colCommonPrimaryClock]
      set interClockConstraints [lindex $row $colInterClockConstraints]
      set clockPairClassification [lindex $row $colClockPairClassification]
      set wnsClockEdges [lindex $row $colWNSClockEdges]
      set wns [lindex $row $colWNS]
      set tns [lindex $row $colTNS]
      set whs [lindex $row $colWHS]
      set ths [lindex $row $colTHS]
      set wnsPathRequirement [lindex $row $colWNSPathRequirement]
      if {$clockPairClassification == {Ignored}} {
        continue
      }
#       if {$interClockConstraints == {Timed}} {
#         lappend clockPairs [list $fromClock $toClock]
#       }
      lappend clockPairs [list $fromClock $toClock]
      if {([scan $wns {%f}] != {}) && ($wns < 0)} {
        lappend setupViosClockPairs [list $fromClock $toClock]
puts "$fromClock -> $toClock : \t\twns=$wns"
      }
      if {([scan $whs {%f}] != {}) && ($whs < 0)} {
        lappend holdViosClockPairs [list $fromClock $toClock]
puts "$fromClock -> $toClock : \t\twhs=$whs"
      }
    }

    set db(hold) $holdViosClockPairs
    set db(setup) $setupViosClockPairs
    set db(clockpairs) $clockPairs
    set stop [clock seconds]
    puts " -I- report_clock_interaction in [expr $stop - $start] seconds"
  } else {
  }

  return -code ok
}

proc ::drc::config {args} {
  variable params
  variable db
  set error 0
  set help 0
  if {[llength $args] == 0} {
    set help 1
  }
  while {[llength $args]} {
    set name [lshift args]
    switch -regexp -- $name {
      {^-gui$} -
      {^-gui?$}  {
        set params(gui) 1
      }
      {^-no_gui$} -
      {^-no_g(ui?)?$}  {
        set params(gui) 0
      }
      {^-rpt$} -
      {^-rpt?$}  {
        set params(rpt) 1
      }
      {^-no_rpt$} -
      {^-no_r(pt?)?$}  {
        set params(rpt) 0
      }
      {^-max$} -
      {^-max?$} {
        set params(npaths) [lshift args]
        catch {unset db}
      }
      {^-reset$} -
      {^-reset?$} {
        catch {unset db}
      }
      {^-dump$} -
      {^-dump?$} {
        parray params
      }
      {^-db$} {
        parray db
      }
      {^-odir$} -
      {^-odir?$} {
        set params(outputDir) [lshift args]
      }
      {^-debug$} {
        set params(debug) 1
      }
      {^-h(e(lp?)?)?$} {
        set help 1
      }
      default {
        if {[string match "-*" $name]} {
          puts " -E- option '$name' is not a valid option."
          incr error
        } else {
          puts " -E- option '$name' is not a valid option."
          incr error
        }
      }
    }
  }

  if {$help} {
    puts [format {
  Usage: ::drc::config
              [-gui|-no_gui]
              [-rpt|-no_rpt]
              [-max <num>]
              [-odir <dir>]
              [-reset]
              [-help|-h]

  Description: Configure the custom DRCs

    -odir: set the output directory for the reports
      Default: current working directory
    -max: maximum number of timing paths to consider
    -reset: discard the existing timing parths
    -gui: open the timing paths violations in the GUI
    -rpt: save the timing paths violations on disk

    Default behavior is -summary and -cmdline

  Example:
     profiler configure -collection_display_limit 500 -details
} ]
    # HELP -->
    return -code ok
  }
  return -code ok
}

# This proc check if a sub-sequent list of 3 SLRs reflect an optimal or non-optimal partitioning
proc ::drc::isOptimalSLRPart { slr_before slr slr_after } {
  switch [join [list $slr_before $slr $slr_after] {:}] {
    "SLR0:SLR1:SLR0" -
    "SLR0:SLR1:SLR3" -
    "SLR0:SLR2:SLR0" -
    "SLR0:SLR2:SLR1" -
    "SLR0:SLR2:SLR3" -
    "SLR0:SLR3:SLR0" -
    "SLR0:SLR3:SLR1" -
    "--------------" -
    "SLR1:SLR2:SLR1" -
    "SLR1:SLR2:SLR0" -
    "SLR1:SLR3:SLR1" -
    "SLR1:SLR3:SLR2" -
    "SLR1:SLR3:SLR1" -
    "SLR1:SLR0:SLR1" -
    "SLR1:SLR0:SLR2" -
    "--------------" -
    "SLR2:SLR3:SLR2" -
    "SLR2:SLR3:SLR1" -
    "SLR2:SLR0:SLR2" -
    "SLR2:SLR0:SLR3" -
    "SLR2:SLR0:SLR1" -
    "SLR2:SLR1:SLR2" -
    "SLR2:SLR1:SLR3" -
    "--------------" -
    "SLR3:SLR0:SLR2" -
    "SLR3:SLR0:SLR3" -
    "SLR3:SLR1:SLR0" -
    "SLR3:SLR1:SLR2" -
    "SLR3:SLR1:SLR3" -
    "SLR3:SLR2:SLR0" -
    "SLR3:SLR2:SLR3" {
      # Not optimal list of SLRs
      return 0
    }
  }
  # Other patterns: optimal list of SLRs
  return 1
}

##########################################
# Source all dependencies
##########################################

if {[catch { set dir [file dirname [file readlink [info script]]] } errorstring]} {
  set dir [file dirname [info script]]
}
set dir [file normalize $dir]
foreach file [lsort -dictionary [glob -nocomplain $dir/*.tcl]] {
  # Is that this file?
  if {[file normalize $file] == [file normalize [info script]]} {
    # Skipping this current file
    continue
  }
  puts " -I- sourcing DRC '$file'"
  if {[catch {source -notrace $file} errorstring]} {
    puts " -E- $errorstring"
  } else {
    lappend ::drc::files $file
  }
}

##########################################
# Execute the custom DRCs
##########################################

# report_drc -ruledecks EmuProto_checks
