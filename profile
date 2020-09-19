ndb/cs
ndb/dns

load std
load file2chan
dir := /tmp/cmdchan
output_file := $dir^/tmp/output_file
cmd_file := $dir^/tmp/cmd

test -d $dir/export || mkdir -p $dir/export
test -d $dir/tmp || mkdir -p $dir/tmp

file2chan $dir^/export/cmd {
    if {~ ${rget offset} 0} {
      cat $output_file | putrdata
    } {
      rread ''
    }
  } {
    sh -c ${rget data} > $output_file
  }

listen -A tcp!*!1917 {
  export $dir^/export/ &
}
