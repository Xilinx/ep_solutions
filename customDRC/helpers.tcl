
namespace eval ::parse {
}

proc ::parse::extract_columns { str match } {
  set col 0
  set columns [list]
  set previous -1
  while {[set col [string first $match $str [expr $previous +1]]] != -1} {
    if {[expr $col - $previous] > 1} {
      lappend columns $col
    }
    set previous $col
  }
  return $columns
}

proc ::parse::extract_row {str columns} {
  lappend columns [string length $str]
  set row [list]
  set pos 0
  foreach col $columns {
    set value [string trim [string range $str $pos $col]]
    lappend row $value
    set pos [incr col 2]
  }
  return $row
}

proc ::parse::parseClockInteractionReport {report} {
  set columns [list]
  set table [list]
  set report [split $report \n]
  set SM {header}
  for {set index 0} {$index < [llength $report]} {incr index} {
    set line [lindex $report $index]
    switch $SM {
      header {
        if {[regexp {^\-+\s+\-+\s+\-+} $line]} {
          set columns [extract_columns [string trimright $line] { }]
          set header1 [extract_row [lindex $report [expr $index -2]] $columns]
          set header2 [extract_row [lindex $report [expr $index -1]] $columns]
          set row [list]
          foreach h1 $header1 h2 $header2 {
            lappend row [string trim [format {%s %s} [string trim [format {%s} $h1]] [string trim [format {%s} $h2]]] ]
          }
          lappend table $row
          set SM {table}
        }
      }
      table {
        # Check for empty line or for line that match '<empty>'
        if {(![regexp {^\s*$} $line]) && (![regexp -nocase {^\s*No clocks found.\s*$} $line])} {
          set row [extract_row $line $columns]
          lappend table $row
        }
      }
      end {
      }
    }
  }
  return $table
}
