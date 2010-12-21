<?
$stackwalk_program = dirname(__FILE__).'/minidump_stackwalk';

function breakpad_stackwalk($dump_path, $symbol_dir) {
  global $stackwalk_program;
  $cmd = "'$stackwalk_program' '$dump_path' '$symbol_dir'";
  #echo '$cmd = "'.$cmd."\"\n\n";
  $out = array();
  $exitstatus = 0;
  exec($cmd, $out, $exitstatus);
  $out = implode("\n", $out);
  if ($exitstatus == 0) {
    return $out;
  } else {
    return false;
  }
}

?>