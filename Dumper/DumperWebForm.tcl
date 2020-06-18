tcl;

eval {

#***********************************************************************
# User Defined Settings (globals from SpinnerDumper.tcl take precedence!)
#***********************************************************************

   set sFilter               "*";   #  default "*" - name filter
   set sOrigNameFilter       "";    #  default "" - original name property filter
   set bSpinnerAgentFilter   FALSE; #  default FALSE - filters schema modified by SpinnerAgent if TRUE
   set sGreaterThanEqualDate "";    #  default "" - date range min value formatted mm/dd/yyyy
   set sLessThanEqualDate    "";    #  default "" - date range max value formatted mm/dd/yyyy
#   set sGreaterThanEqualDate [clock format [clock seconds] -format "%m/%d/%Y"]; dynamic setting for current day
#   set sLessThanEqualDate    [clock format [clock seconds] -format "%m/%d/%Y"]; dynamic setting for current day
   
# End User Defined Settings
#*********************************************************************** 

#  Set up array for symbolic name mapping
#
   set lsPropertyName ""
   catch {set lsPropertyName [split [mql print program eServiceSchemaVariableMapping.tcl select property.name dump |] |]} sMsg
   set sTypeReplace "form "

   foreach sPropertyName $lsPropertyName {
      set sSchemaTest [lindex [split $sPropertyName "_"] 0]
      if {$sSchemaTest == "form"} {
         set sPropertyTo [mql print program eServiceSchemaVariableMapping.tcl select property\[$sPropertyName\].to dump]
         regsub $sTypeReplace $sPropertyTo "" sPropertyTo
         regsub "_" $sPropertyName "|" sSymbolicName
         set sSymbolicName [lindex [split $sSymbolicName |] 1]
         array set aSymbolic [list $sPropertyTo $sSymbolicName]
      }
   }

   if {[mql get env GLOBALFILTER] != ""} {
      set sFilter [mql get env GLOBALFILTER]
   } elseif {$sFilter == ""} {
      set sFilter "*"
   }
   
   if {[mql get env SPINNERFILTER] != ""} {
      set bSpinnerAgentFilter [mql get env SPINNERFILTER]
   }
   
   if {[mql get env ORIGNAMEFILTER] != ""} {
      set sOrigNameFilter [mql get env ORIGNAMEFILTER]
   }
   
   set sModDateMin [mql get env MODDATEMIN]
   set sModDateMax [mql get env MODDATEMAX]
   if {$sModDateMin == "" && $sModDateMax == ""} {
      if {$sGreaterThanEqualDate != ""} {
         set sModDateMin [clock scan $sGreaterThanEqualDate]
      }
      if {$sLessThanEqualDate != ""} {
         set sModDateMax [clock scan $sLessThanEqualDate]
      }
   }
   
   set sSpinnerPath [mql get env SPINNERPATH]
   if {$sSpinnerPath == ""} {
      set sOS [string tolower $tcl_platform(os)];
      set sSuffix [clock format [clock seconds] -format "%Y%m%d"]
      
      if { [string tolower [string range $sOS 0 5]] == "window" } {
         set sSpinnerPath "c:/temp/SpinnerAgent$sSuffix/Business";
      } else {
         set sSpinnerPath "/tmp/SpinnerAgent$sSuffix/Business";
      }
      file mkdir $sSpinnerPath
   }

   set sPath "$sSpinnerPath/SpinnerWebFormData.xls"
   set lsWebForm [split [mql list form] \n]
   set sFile "Name\tRegistry Name\tDescription\tField Names (in order-use \"|\" delim)\tHidden (boolean)\tTypes (use \"|\" delim)\n"
   foreach sWebForm $lsWebForm {
      if {[mql print form $sWebForm select web dump] == "TRUE"} {
         set bPass TRUE
         set sModDate [mql print form $sWebForm select modified dump]
         set sModDate [clock scan [clock format [clock scan $sModDate] -format "%m/%d/%Y"]]
         if {$sModDateMin != "" && $sModDate < $sModDateMin} {
            set bPass FALSE
         } elseif {$sModDateMax != "" && $sModDate > $sModDateMax} {
            set bPass FALSE
         }
         
         if {$sOrigNameFilter != ""} {
            set sOrigName [mql print form $sWebForm select property\[original name\].value dump]
            if {[string match $sOrigNameFilter $sOrigName] == 1} {
               set bPass TRUE
            } else {
               set bPass FALSE
            }
         }
   
         if {($bPass == "TRUE") && ($bSpinnerAgentFilter != "TRUE" || [mql print form $sWebForm select property\[SpinnerAgent\] dump] != "")} {
            set sName [mql print form $sWebForm select name dump]
            for {set i 0} {$i < [string length $sName]} {incr i} {
               if {[string range $sName $i $i] == " "} {
                  regsub " " $sName "<SPACE>" sName
               } else {
                  break
               }
            }
            set sOrigName ""
            catch {set sOrigName $aSymbolic($sWebForm)} sMsg
            regsub -all " " $sWebForm "" sOrigNameTest
            if {$sOrigNameTest == $sOrigName} {
               set sOrigName $sWebForm
            }
            set sDescription [mql print form $sWebForm select description dump]
            set slsType [mql print form $sWebForm select type dump " | "]
            set sHidden [mql print form $sWebForm select hidden dump]
            set slsField [mql print form $sWebForm select field dump " | "]
            for {set i 0} {$i < [string length $slsField]} {incr i} {
               if {[string range $slsField $i $i] == " "} {
                  regsub " " $slsField "<SPACE>" slsField
               } else {
                  break
               }
            }
            regsub -all " \\\|  " $slsField " \| <SPACE>" slsField
            append sFile "$sName\t$sOrigName\t$sDescription\t$slsField\t$sHidden\t$slsType\n"
         }
      }
   }
   set iFile [open $sPath w]
   puts $iFile $sFile
   close $iFile
   puts "WebForm data loaded in file $sPath"
}
