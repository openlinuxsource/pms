#!/usr/bin/tclsh

################
# version: 0.0.2
################

package require Tk

wm title . "Performance Monitoring Station"
wm resizable . 0 0

##############
# common procs
##############

proc StatusInsert {name now} {
	global old
	if {$old($name) == {}} {
		set old($name) $now
	}

	if {$now > $old($name)} {
		puts "[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] $name $now UP"
		$name configure -foreground red
	} elseif {$now == $old($name)} {
		puts "[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] $name $now EQUAL"
		$name configure -foreground blue
	} else {
		puts "[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] $name $now DOWN"
		$name configure -foreground darkgreen
	}

	set old($name) $now
}

##################
# common procs end
##################

##############
# loadavg proc
##############

proc loadavg {} {
	set lavgFile {/proc/loadavg}
	set lavgFD [open $lavgFile r]
	while {[gets $lavgFD line] >= 0} {
		set result $line
	}
	close $lavgFD

	foreach widget {.loadavg.onemin .loadavg.fivemin .loadavg.fifteenmin} value [lrange [split $result { }] 0 2] {
		StatusInsert $widget $value
	}

	foreach widget {.loadavg.prun .loadavg.pall} value [split [lindex [split $result { }] 3] {/}] {
		StatusInsert $widget $value
	}
}

labelframe .loadavg -text "Load Avg" -labelanchor n
entry .loadavg.onemin -width 8 -state readonly -justify center -textvariable old(.loadavg.onemin)
entry .loadavg.fivemin -width 8 -state readonly -justify center -textvariable old(.loadavg.fivemin)
entry .loadavg.fifteenmin -width 8 -state readonly -justify center -textvariable old(.loadavg.fifteenmin)
entry .loadavg.prun -width 8 -state readonly -justify center -textvariable old(.loadavg.prun)
entry .loadavg.pall -width 8 -state readonly -justify center -textvariable old(.loadavg.pall)
label .loadavg.one -text "1 min" -justify center
label .loadavg.five -text "5 min" -justify center
label .loadavg.fifteen -text "15 min" -justify center
label .loadavg.run -text "Run Proc" -justify center
label .loadavg.all -text "All Proc" -justify center

grid .loadavg.one .loadavg.five .loadavg.fifteen .loadavg.run .loadavg.all -sticky nsew
grid .loadavg.onemin .loadavg.fivemin .loadavg.fifteenmin .loadavg.prun .loadavg.pall -sticky nsew

##################
# loadavg proc end
##################

##############
# cpuload proc
##############

proc cpustat {} {
	global CpuEntryOld
	global Cpu
	set CpuEntryAdd {}
	set CpuEntryRemove {}
	set cpustat [open /proc/stat r]
	while {[gets $cpustat line] >= 0} {
		if {[regexp -all -lineanchor cpu $line]} {
			set cpuname [lindex $line 0]
			set Cpu($cpuname.new) [dict create user [lindex $line 1] nice [lindex $line 2] system [lindex $line 3] idle [lindex $line 4] iowait [lindex $line 5] irq [lindex $line 6] softirq [lindex $line 7]]

			if {![info exists Cpu($cpuname.old)]} {
				set Cpu($cpuname.old) [dict create user 0 nice 0 system 0 idle 0 iowait 0 irq 0 softirq 0]
			}

			set $cpuname [dict create \
				us [expr {[dict get [set Cpu($cpuname.new)] user] - [dict get [set Cpu($cpuname.old)] user] + [dict get [set Cpu($cpuname.new)] nice] - [dict get [set Cpu($cpuname.old)] nice]}] \
				sy [expr {[dict get [set Cpu($cpuname.new)] system] - [dict get [set Cpu($cpuname.old)] system] + [dict get [set Cpu($cpuname.new)] irq] - [dict get [set Cpu($cpuname.old)] irq] + [dict get [set Cpu($cpuname.new)] softirq] - [dict get [set Cpu($cpuname.old)] softirq]}] \
				id [expr {[dict get [set Cpu($cpuname.new)] idle] - [dict get [set Cpu($cpuname.old)] idle]}] \
				wa [expr {[dict get [set Cpu($cpuname.new)] iowait] - [dict get [set Cpu($cpuname.old)] iowait]}] \
			]
			dict append $cpuname all [expr {[dict get [set $cpuname] us] + [dict get [set $cpuname] sy] + [dict get [set $cpuname] id] + [dict get [set $cpuname] wa]}]

		lappend CpuEntryNew $cpuname
		}
	}
	close $cpustat

	if {[info exists CpuEntryOld] == 0} {
		set CpuEntryOld $CpuEntryNew
		foreach dev $CpuEntryOld {
			entry .cpustat.us$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.us$dev)
			entry .cpustat.sy$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.sy$dev)
			entry .cpustat.id$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.id$dev)
			entry .cpustat.wa$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.wa$dev)
			label .cpustat.l$dev -text "$dev" -justify center

			StatusInsert .cpustat.us$dev [format %.2f [expr {[dict get [set $dev] us] * 100.0 / [dict get [set $dev] all]}]]
			StatusInsert .cpustat.sy$dev [format %.2f [expr {[dict get [set $dev] sy] * 100.0 / [dict get [set $dev] all]}]]
			StatusInsert .cpustat.id$dev [format %.2f [expr {[dict get [set $dev] id] * 100.0 / [dict get [set $dev] all]}]]
			StatusInsert .cpustat.wa$dev [format %.2f [expr {[dict get [set $dev] wa] * 100.0 / [dict get [set $dev] all]}]]

			grid .cpustat.l$dev .cpustat.us$dev .cpustat.sy$dev .cpustat.id$dev .cpustat.wa$dev
		}
	} else {
		foreach dev $CpuEntryOld {
			if {[info exists $dev]} {
				StatusInsert .cpustat.us$dev [format %.2f [expr {[dict get [set $dev] us] * 100.0 / [dict get [set $dev] all]}]]
				StatusInsert .cpustat.sy$dev [format %.2f [expr {[dict get [set $dev] sy] * 100.0 / [dict get [set $dev] all]}]]
				StatusInsert .cpustat.id$dev [format %.2f [expr {[dict get [set $dev] id] * 100.0 / [dict get [set $dev] all]}]]
				StatusInsert .cpustat.wa$dev [format %.2f [expr {[dict get [set $dev] wa] * 100.0 / [dict get [set $dev] all]}]]
			}
		}
	}

	foreach dev $CpuEntryOld { 
		if {[lsearch $CpuEntryNew $dev] == -1} {
			lappend CpuEntryRemove $dev
	}
	}

	foreach dev $CpuEntryNew {
		if {[lsearch $CpuEntryOld $dev] == -1} {
			lappend CpuEntryAdd $dev
		}
	}

	if {[llength $CpuEntryAdd] > 0} {
		foreach dev $CpuEntryAdd {
			entry .cpustat.us$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.us$dev)
			entry .cpustat.sy$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.sy$dev)
			entry .cpustat.id$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.id$dev)
			entry .cpustat.wa$dev -width 8 -state readonly -justify center -textvariable old(.cpustat.wa$dev)
			label .cpustat.l$dev -text "$dev" -justify center

			StatusInsert .cpustat.us$dev [format %.2f [expr {[dict get [set $dev] us] * 100.0 / [dict get [set $dev] all]}]]
			StatusInsert .cpustat.sy$dev [format %.2f [expr {[dict get [set $dev] sy] * 100.0 / [dict get [set $dev] all]}]]
			StatusInsert .cpustat.id$dev [format %.2f [expr {[dict get [set $dev] id] * 100.0 / [dict get [set $dev] all]}]]
			StatusInsert .cpustat.wa$dev [format %.2f [expr {[dict get [set $dev] wa] * 100.0 / [dict get [set $dev] all]}]]

			grid .cpustat.l$dev .cpustat.us$dev .cpustat.sy$dev .cpustat.id$dev .cpustat.wa$dev
			
		}
	}

	if {[llength $CpuEntryRemove] > 0} {
		foreach dev $CpuEntryRemove {
			destroy .cpustat.us$dev
			destroy .cpustat.sy$dev
			destroy .cpustat.id$dev
			destroy .cpustat.wa$dev
			destroy .cpustat.l$dev
		}
	}

	foreach dev $CpuEntryOld {
		if {[info exists $dev]} {
			dict set Cpu($dev.old) user [dict get [set Cpu($dev.new)] user]
			dict set Cpu($dev.old) nice [dict get [set Cpu($dev.new)] nice]
			dict set Cpu($dev.old) system [dict get [set Cpu($dev.new)] system]
			dict set Cpu($dev.old) idle [dict get [set Cpu($dev.new)] idle]
			dict set Cpu($dev.old) iowait [dict get [set Cpu($dev.new)] iowait]
			dict set Cpu($dev.old) irq [dict get [set Cpu($dev.new)] irq]
			dict set Cpu($dev.old) softirq [dict get [set Cpu($dev.new)] softirq]
		}
	}

	set CpuEntryOld $CpuEntryNew
}

labelframe .cpustat -text "CPU Utilization" -labelanchor n
label .cpustat.lus -text "user%" -justify center
label .cpustat.lsy -text "sys%" -justify center
label .cpustat.lid -text "idle%" -justify center
label .cpustat.lwa -text "wait%" -justify center
grid x .cpustat.lus .cpustat.lsy .cpustat.lid .cpustat.lwa

##################
# cpuload proc end
##################

##############
# meminfo proc
##############

proc meminfo {} {
	set meminfo [open /proc/meminfo r]
	while {[gets $meminfo line] >= 0} {
		scan $line {MemTotal:%dkB} memtotal
		scan $line {MemFree:%dkB} memfree
		scan $line {Buffers:%dkB} buffers
		scan $line {Cached:%dkB} cached
		scan $line {Dirty:%dkB} dirty
		scan $line {SwapCached:%dkB} swapcached
		scan $line {SwapTotal:%dkB} swaptotal
		scan $line {SwapFree:%dkB} swapfree
	}
	close $meminfo

	StatusInsert .meminfo.memtotal $memtotal
	StatusInsert .meminfo.memfree $memfree
	StatusInsert .meminfo.buffers $buffers
	StatusInsert .meminfo.cached $cached
	StatusInsert .meminfo.dirty $dirty
	StatusInsert .meminfo.swapcached $swapcached
	StatusInsert .meminfo.swaptotal $swaptotal
	StatusInsert .meminfo.swapfree $swapfree
}

labelframe .meminfo -text "Memory Information" -labelanchor n
entry .meminfo.memtotal -width 16 -state readonly -justify center -textvariable old(.meminfo.memtotal)
entry .meminfo.memfree -width 16 -state readonly -justify center -textvariable old(.meminfo.memfree)
entry .meminfo.buffers -width 16 -state readonly -justify center -textvariable old(.meminfo.buffers)
entry .meminfo.cached -width 16 -state readonly -justify center -textvariable old(.meminfo.cached)
entry .meminfo.dirty -width 16 -state readonly -justify center -textvariable old(.meminfo.dirty)
entry .meminfo.swapcached -width 16 -state readonly -justify center -textvariable old(.meminfo.swapcached)
entry .meminfo.swaptotal -width 16 -state readonly -justify center -textvariable old(.meminfo.swaptotal)
entry .meminfo.swapfree -width 16 -state readonly -justify center -textvariable old(.meminfo.swapfree)
label .meminfo.lmemtotal -text "Total Memory(kB)" -justify center
label .meminfo.lmemfree -text "Free Memory(kB)" -justify center
label .meminfo.lbuffers -text "Buffers(kB)" -justify center
label .meminfo.lcached -text "Cached(kB)" -justify center
label .meminfo.ldirty -text "Dirty(kB)" -justify center
label .meminfo.lswapcached -text "Swap Cached(kB)" -justify center
label .meminfo.lswaptotal -text "Total Swap(kB)" -justify center
label .meminfo.lswapfree -text "Free Swap(kB)" -justify center

grid .meminfo.lmemtotal .meminfo.memtotal -sticky nsew 
grid .meminfo.lmemfree .meminfo.memfree -sticky nsew
grid .meminfo.lbuffers .meminfo.buffers -sticky nsew
grid .meminfo.lcached .meminfo.cached -sticky nsew
grid .meminfo.ldirty .meminfo.dirty -sticky nsew
grid .meminfo.lswapcached .meminfo.swapcached -sticky nsew
grid .meminfo.lswaptotal .meminfo.swaptotal -sticky nsew
grid .meminfo.lswapfree .meminfo.swapfree -sticky nsew

##################
# meminfo proc end
##################

###############
# diskstat proc
###############

proc diskstat {} {
	global BlockEntryOld
	global Block
	set BlockEntryAdd {}
	set BlockEntryRemove {}
	set diskstats [open /proc/diskstats r]
	while {[gets $diskstats line] >= 0} {
		if {![regexp -all -lineanchor loop|ram $line]} {
			set blockname [lindex $line 2]
			set Block($blockname.new) [dict create rio [lindex $line 3] rmerge [lindex $line 4] rsect [lindex $line 5] ruse [lindex $line 6] wio [lindex $line 7] wmerge [lindex $line 8] wsect [lindex $line 9] wuse [lindex $line 10] running [lindex $line 11] aveq [lindex $line 12] use [lindex $line 13]]

			if {![info exists Block($blockname.old)]} {
				set Block($blockname.old) [dict create rio 0 rmerge 0 rsect 0 ruse 0 wio 0 wmerge 0 wsect 0 wuse 0 running 0 aveq 0 use 0]
			}
			set $blockname [dict create \
				rrqm [expr {[dict get [set Block($blockname.new)] rmerge] - [dict get [set Block($blockname.old)] rmerge]}] \
				wrqm [expr {[dict get [set Block($blockname.new)] wmerge] - [dict get [set Block($blockname.old)] wmerge]}] \
				r [expr {[dict get [set Block($blockname.new)] rio] - [dict get [set Block($blockname.old)] rio]}] \
				w [expr {[dict get [set Block($blockname.new)] wio] - [dict get [set Block($blockname.old)] wio]}] \
				rsec [expr {[dict get [set Block($blockname.new)] rsect] - [dict get [set Block($blockname.old)] rsect]}] \
				wsec [expr {[dict get [set Block($blockname.new)] wsect] - [dict get [set Block($blockname.old)] wsect]}] \
				rkB [expr {([dict get [set Block($blockname.new)] rsect] - [dict get [set Block($blockname.old)] rsect]) / 2}] \
				wkB [expr {([dict get [set Block($blockname.new)] wsect] - [dict get [set Block($blockname.old)] wsect]) / 2}] \
			]
			lappend BlockEntryNew $blockname
		}
	}
	close $diskstats

	if {[info exists BlockEntryOld] == 0} {
		set BlockEntryOld $BlockEntryNew
		foreach dev $BlockEntryOld {
			entry .diskstat.rrqm$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.rrqm$dev)
			entry .diskstat.wrqm$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.wrqm$dev)
			entry .diskstat.r$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.r$dev)
			entry .diskstat.w$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.w$dev)
			entry .diskstat.rsec$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.rsec$dev)
			entry .diskstat.wsec$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.wsec$dev)
			entry .diskstat.rkB$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.rkB$dev)
			entry .diskstat.wkB$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.wkB$dev)
			label .diskstat.l$dev -text "$dev" -justify center

			StatusInsert .diskstat.rrqm$dev [dict get [set $dev] rrqm]
			StatusInsert .diskstat.wrqm$dev [dict get [set $dev] wrqm]
			StatusInsert .diskstat.r$dev [dict get [set $dev] r]
			StatusInsert .diskstat.w$dev [dict get [set $dev] w]
			StatusInsert .diskstat.rsec$dev [dict get [set $dev] rsec]
			StatusInsert .diskstat.wsec$dev [dict get [set $dev] wsec]
			StatusInsert .diskstat.rkB$dev [dict get [set $dev] rkB]
			StatusInsert .diskstat.wkB$dev [dict get [set $dev] wkB]
			grid .diskstat.l$dev .diskstat.rrqm$dev .diskstat.wrqm$dev .diskstat.r$dev .diskstat.w$dev .diskstat.rsec$dev .diskstat.wsec$dev .diskstat.rkB$dev .diskstat.wkB$dev
		}
	} else {
		foreach dev $BlockEntryOld {
			if {[info exists $dev]} {
				StatusInsert .diskstat.rrqm$dev [dict get [set $dev] rrqm]
				StatusInsert .diskstat.wrqm$dev [dict get [set $dev] wrqm]
				StatusInsert .diskstat.r$dev [dict get [set $dev] r]
				StatusInsert .diskstat.w$dev [dict get [set $dev] w]
				StatusInsert .diskstat.rsec$dev [dict get [set $dev] rsec]
				StatusInsert .diskstat.wsec$dev [dict get [set $dev] wsec]
				StatusInsert .diskstat.rkB$dev [dict get [set $dev] rkB]
				StatusInsert .diskstat.wkB$dev [dict get [set $dev] wkB]
			}
		}
	}

	foreach dev $BlockEntryOld {
		if {[lsearch $BlockEntryNew $dev] == -1} {
			lappend BlockEntryRemove $dev
		}
	}

	foreach dev $BlockEntryNew {
		if {[lsearch $BlockEntryOld $dev] == -1} {
			lappend BlockEntryAdd $dev
		}
	}

	if {[llength $BlockEntryAdd] > 0} {
		foreach dev $BlockEntryAdd {
			entry .diskstat.rrqm$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.rrqm$dev)
			entry .diskstat.wrqm$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.wrqm$dev)
			entry .diskstat.r$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.r$dev)
			entry .diskstat.w$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.w$dev)
			entry .diskstat.rsec$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.rsec$dev)
			entry .diskstat.wsec$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.wsec$dev)
			entry .diskstat.rkB$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.rkB$dev)
			entry .diskstat.wkB$dev -width 8  -state readonly -justify center -textvariable old(.diskstat.wkB$dev)
			entry .diskstat.l$dev -text "$dev" -justify center

			StatusInsert .diskstat.rrqm$dev [dict get [set $dev] rrqm]
			StatusInsert .diskstat.wrqm$dev [dict get [set $dev] wrqm]
			StatusInsert .diskstat.r$dev [dict get [set $dev] r]
			StatusInsert .diskstat.w$dev [dict get [set $dev] w]
			StatusInsert .diskstat.rsec$dev [dict get [set $dev] rsec]
			StatusInsert .diskstat.wsec$dev [dict get [set $dev] wsec]
			StatusInsert .diskstat.rkB$dev [dict get [set $dev] rkB]
			StatusInsert .diskstat.wkB$dev [dict get [set $dev] wkB]
			grid .diskstat.l$dev .diskstat.rrqm$dev .diskstat.wrqm$dev .diskstat.r$dev .diskstat.w$dev .diskstat.rsec$dev .diskstat.wsec$dev .diskstat.rkB$dev .diskstat.wkB$dev
		}
	}

	if {[llength $BlockEntryRemove] > 0} {
		foreach dev $BlockEntryRemove {
			destroy .diskstat.rrqm$dev
			destroy .diskstat.wrqm$dev
			destroy .diskstat.r$dev
			destroy .diskstat.w$dev
			destroy .diskstat.rsec$dev
			destroy .diskstat.wsec$dev
			destroy .diskstat.rkB$dev
			destroy .diskstat.wkB$dev
			destroy .diskstat.l$dev
		}
	}

	foreach dev $BlockEntryOld {
		if {[info exists $dev]} {
			dict set Block($dev.old) rio [dict get [set Block($dev.new)] rio]
			dict set Block($dev.old) rmerge [dict get [set Block($dev.new)] rmerge]
			dict set Block($dev.old) rsect [dict get [set Block($dev.new)] rsect]
			dict set Block($dev.old) ruse [dict get [set Block($dev.new)] ruse]
			dict set Block($dev.old) wio [dict get [set Block($dev.new)] wio]
			dict set Block($dev.old) wmerge [dict get [set Block($dev.new)] wmerge]
			dict set Block($dev.old) wsect [dict get [set Block($dev.new)] wsect]
			dict set Block($dev.old) wuse [dict get [set Block($dev.new)] wuse]
			dict set Block($dev.old) running [dict get [set Block($dev.new)] running]
			dict set Block($dev.old) aveq [dict get [set Block($dev.new)] aveq]
			dict set Block($dev.old) use [dict get [set Block($dev.new)] use]
		}
	}

        set BlockEntryOld $BlockEntryNew
}

labelframe .diskstat -text "Disk Status" -labelanchor n
label .diskstat.lrrqm -text "rrqm/s" -justify center
label .diskstat.lwrqm -text "wrqm/s" -justify center
label .diskstat.lr -text "r/s" -justify center
label .diskstat.lw -text "w/s" -justify center
label .diskstat.lrsec -text "rsec/s" -justify center
label .diskstat.lwsec -text "wsec/s" -justify center
label .diskstat.lrkB -text "rkB/s" -justify center
label .diskstat.lwkB -text "wkB/s" -justify center
grid x .diskstat.lrrqm .diskstat.lwrqm .diskstat.lr .diskstat.lw .diskstat.lrsec .diskstat.lwsec .diskstat.lrkB .diskstat.lwkB


###################
# diskstat proc end
###################

##############
# netstat proc
##############

proc netstat {} {
	global NetEntryOld
	global Net
	set NetEntryAdd {}
	set NetEntryRemove {}
	set netstat [open /proc/net/dev r]
	gets $netstat
	gets $netstat

	while {[gets $netstat line] >= 0} {
		lassign [split $line :] netname mertric
		set Net($netname.new) [dict create rxok [lindex $mertric 1] rxerr [lindex $mertric 2] rxdrp [lindex $mertric 3] rxovr [lindex $mertric 4] txok [lindex $mertric 9] txerr [lindex $mertric 10] txdrp [lindex $mertric 11] txovr [lindex $mertric 12]]
		if {![info exists Net($netname.old)]} {
			set Net($netname.old) [dict create rxok 0 rxerr 0 rxdrp 0 rxovr 0 txok 0 txerr 0 txdrp 0 txovr 0]
		}

		set $netname [dict create \
			rxok [expr {[dict get [set Net($netname.new)] rxok] - [dict get [set Net($netname.old)] rxok]}] \
			rxerr [expr {[dict get [set Net($netname.new)] rxerr] - [dict get [set Net($netname.old)] rxerr]}] \
			rxdrp [expr {[dict get [set Net($netname.new)] rxdrp] - [dict get [set Net($netname.old)] rxdrp]}] \
			rxovr [expr {[dict get [set Net($netname.new)] rxovr] - [dict get [set Net($netname.old)] rxovr]}] \
			txok [expr {[dict get [set Net($netname.new)] txok] - [dict get [set Net($netname.old)] txok]}] \
			txerr [expr {[dict get [set Net($netname.new)] txerr] - [dict get [set Net($netname.old)] txerr]}] \
			txdrp [expr {[dict get [set Net($netname.new)] txdrp] - [dict get [set Net($netname.old)] txdrp]}] \
			txovr [expr {[dict get [set Net($netname.new)] txovr] - [dict get [set Net($netname.old)] txovr]}] \
		]
		lappend NetEntryNew $netname
	}
	close $netstat

	if {[info exists NetEntryOld] == 0} {
		set NetEntryOld $NetEntryNew
		foreach dev $NetEntryOld {
			entry .netstat.rxok$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxok$dev)
			entry .netstat.rxerr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxerr$dev)
			entry .netstat.rxdrp$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxdrp$dev)
			entry .netstat.rxovr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxovr$dev)
			entry .netstat.txok$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txok$dev)
			entry .netstat.txerr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txerr$dev)
			entry .netstat.txdrp$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txovr$dev)
			entry .netstat.txovr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txdrp$dev)
			label .netstat.l$dev -text "$dev" -justify center

			StatusInsert .netstat.rxok$dev [dict get [set $dev] rxok]
			StatusInsert .netstat.rxerr$dev [dict get [set $dev] rxerr]
			StatusInsert .netstat.rxdrp$dev [dict get [set $dev] rxdrp]
			StatusInsert .netstat.rxovr$dev [dict get [set $dev] rxovr]
			StatusInsert .netstat.txok$dev [dict get [set $dev] txok]
			StatusInsert .netstat.txerr$dev [dict get [set $dev] txerr]
			StatusInsert .netstat.txdrp$dev [dict get [set $dev] txdrp]
			StatusInsert .netstat.txovr$dev [dict get [set $dev] txovr]

			grid .netstat.l$dev .netstat.rxok$dev .netstat.rxerr$dev .netstat.rxdrp$dev .netstat.rxovr$dev .netstat.txok$dev .netstat.txerr$dev .netstat.txdrp$dev .netstat.txovr$dev
		}
	} else {
		foreach dev $NetEntryOld {
			if {[info exists $dev]} {
				StatusInsert .netstat.rxok$dev [dict get [set $dev] rxok]
				StatusInsert .netstat.rxerr$dev [dict get [set $dev] rxerr]
				StatusInsert .netstat.rxdrp$dev [dict get [set $dev] rxdrp]
				StatusInsert .netstat.rxovr$dev [dict get [set $dev] rxovr]
				StatusInsert .netstat.txok$dev [dict get [set $dev] txok]
				StatusInsert .netstat.txerr$dev [dict get [set $dev] txerr]
				StatusInsert .netstat.txdrp$dev [dict get [set $dev] txdrp]
				StatusInsert .netstat.txovr$dev [dict get [set $dev] txovr]
			}
		}
	}

	foreach dev $NetEntryOld {
		if {[lsearch $NetEntryNew $dev] == -1} {
			lappend NetEntryRemove $dev
		}
	}

	foreach dev $NetEntryNew {
		if {[lsearch $NetEntryOld $dev] == -1} {
			lappend NetEntryAdd $dev
		}
	}

	if {[llength $NetEntryAdd] > 0} {
		foreach dev $NetEntryAdd {
			entry .netstat.rxok$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxok$dev)
			entry .netstat.rxerr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxerr$dev)
			entry .netstat.rxdrp$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxdrp$dev)
			entry .netstat.rxovr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.rxovr$dev)
			entry .netstat.txok$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txok$dev)
			entry .netstat.txerr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txerr$dev)
			entry .netstat.txdrp$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txovr$dev)
			entry .netstat.txovr$dev -width 8 -state readonly -justify center -textvariable old(.netstat.txdrp$dev)
			label .netstat.l$dev -text "$dev" -justify center

			StatusInsert .netstat.rxok$dev [dict get [set $dev] rxok]
			StatusInsert .netstat.rxerr$dev [dict get [set $dev] rxerr]
			StatusInsert .netstat.rxdrp$dev [dict get [set $dev] rxdrp]
			StatusInsert .netstat.rxovr$dev [dict get [set $dev] rxovr]
			StatusInsert .netstat.txok$dev [dict get [set $dev] txok]
			StatusInsert .netstat.txerr$dev [dict get [set $dev] txerr]
			StatusInsert .netstat.txdrp$dev [dict get [set $dev] txdrp]
			StatusInsert .netstat.txovr$dev [dict get [set $dev] txovr]

			grid .netstat.l$dev .netstat.rxok$dev .netstat.rxerr$dev .netstat.rxdrp$dev .netstat.rxovr$dev .netstat.txok$dev .netstat.txerr$dev .netstat.txdrp$dev .netstat.txovr$dev
		}
	}

	if {[llength $NetEntryRemove] > 0} {
		foreach dev $NetEntryRemove {
			destroy .netstat.rxok$dev
			destroy .netstat.rxerr$dev
			destroy .netstat.rxdrp$dev
			destroy .netstat.rxovr$dev
			destroy .netstat.txok$dev
			destroy .netstat.txerr$dev
			destroy .netstat.txdrp$dev
			destroy .netstat.txovr$dev
			destroy .netstat.l$dev
		}
	}

	foreach dev $NetEntryOld {
		if {[info exists $dev]} {
			dict set Net($dev.old) rxok [dict get [set Net($dev.new)] rxok]
			dict set Net($dev.old) rxerr [dict get [set Net($dev.new)] rxerr]
			dict set Net($dev.old) rxdrp [dict get [set Net($dev.new)] rxdrp]
			dict set Net($dev.old) rxovr [dict get [set Net($dev.new)] rxovr]
			dict set Net($dev.old) txok [dict get [set Net($dev.new)] txok]
			dict set Net($dev.old) txerr [dict get [set Net($dev.new)] txerr]
			dict set Net($dev.old) txdrp [dict get [set Net($dev.new)] txdrp]
			dict set Net($dev.old) txovr [dict get [set Net($dev.new)] txovr]
		}
	}

	set NetEntryOld $NetEntryNew
}

labelframe .netstat -text "Network Interfaces Status" -labelanchor n
label .netstat.lrxok -text "RX-OK/s" -justify center
label .netstat.lrxerr -text "RX-ERR/s" -justify center
label .netstat.lrxdrp -text "RX-DRP/s" -justify center
label .netstat.lrxovr -text "RX-OVR/s" -justify center
label .netstat.ltxok -text "TX-OK/s" -justify center
label .netstat.ltxerr -text "TX-ERR/s" -justify center
label .netstat.ltxdrp -text "TX-DRP/s" -justify center
label .netstat.ltxovr -text "TX-OVR/s" -justify center
grid x .netstat.lrxok .netstat.lrxerr .netstat.lrxdrp .netstat.lrxovr .netstat.ltxok .netstat.ltxerr .netstat.ltxdrp .netstat.ltxovr

##################
# netstat proc end
##################

########
# layout 
########

grid .loadavg .netstat -sticky nsew
grid .cpustat .diskstat -sticky nsew
grid .meminfo -sticky nsew

grid anchor .loadavg center
grid anchor .cpustat center
grid anchor .meminfo center
grid anchor .diskstat center
grid anchor .netstat center

############
# layout end
############

proc pms {} {
	loadavg
	cpustat
	meminfo
	diskstat
	netstat
	after 1000 pms
}

pms

