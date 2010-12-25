<?
require '../lib/h.php';
require '../config.php';

$MAXLENGTH = 4096000; # 4 MB
$base_dir = dirname(__FILE__);
$reports_dir = $base_dir.'/reports';
$entry_url_base = 'http://kodapp.com/crashreport/reports/';

$email_replyto_addr = 'kodapp+crash-report@notion.se';
$email_replyto_name = 'Kod crash reporter';
$email_recipient = 'kodapp+crash-report@notion.se';

# sanity check
if (isset($_SERVER['REQUEST_METHOD']) != 'POST') {
  header('HTTP/1.1 405 Method Not Allowed');
  exit('405 Method Not Allowed');
}

# construct entry name
#   Format:  <YYYYMMDDHHMMSS.UUUUUU>-<rand>.crash
#   Example: "20101221124503.654321-xyz.crash"
date_default_timezone_set(@date_default_timezone_get());
$u = microtime(true);
$u = ($u - intval($u))*1000000;
$entry_id = date('YmdHis.').$u.'-'.
            base_convert(rand(1000,1000000), 10, 36);
$filename = $entry_id.'.crash';

# Save input to file
$abspath = $reports_dir.'/'.$filename;
$dstf = @fopen($abspath, 'w');
if (!$dstf) {
  header('HTTP/1.1 500 Internal Server Error');
	exit('unable to write to '.$dirpath);
}
$srcf = fopen('php://input', 'r');
$size = stream_copy_to_stream($srcf, $dstf, $MAXLENGTH);
fclose($dstf);
if ($size === 0) {
	@unlink($abspath);
} elseif ($size >= $MAXLENGTH) {
	@unlink($abspath); # because it's probably broken
  header('HTTP/1.1 413 Request Entity Too Large');
	exit('Request entity larger than or equal to '.$MAXLENGTH.' B');
}

# send response
header('HTTP/1.1 201 Created');
header('Connection: close');
header('Content-type: text/plain; charset=utf8');
header('Content-length: '.strlen($entry_name));
echo $entry_name;

# send mail
ignore_user_abort(true);

$crash_report = file_get_contents($abspath);
$version = '?';
if (preg_match('/Version:[\t ]+([0-9\.]+)/', $crash_report, $m)) {
  $version = $m[1];
}
$email_body = $crash_report;
$mail = hgmail::newtext($email_recipient,
                        $email_replyto_addr,
                        $email_replyto_name,
                        'Kod '.$version.' crash report #'.$entry_id,
                        $email_body);
$mail->Send();

?>