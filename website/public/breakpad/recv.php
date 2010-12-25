<?
require '../lib/h.php';
require '../config.php';

$base_dir = '/var/www/kodapp.com/www/breakpad';
#$base_dir = '.'; # XXX DEV
$dump_dir = $base_dir.'/dumps';
$symbol_dir = $base_dir.'/symbols';
$email_replyto_addr = 'rasmus+kod-crash-report@notion.se';
$email_replyto_name = 'Kod crash reporter';
$email_recipient = 'rasmus@notion.se';
$entry_url_base = 'http://kodapp.com/breakpad/admin/entry.php?name=';

# sanity check
if (!isset($_FILES['upload_file_minidump']) ||
    !isset($_POST['prod']) ||
    !isset($_POST['ver']) ||
    preg_match('/[\/]|\.\./', $_POST['prod']) ||
    preg_match('/[\/]|\.\./', $_POST['ver'])) {
  header('HTTP/1.1 400 Bad Request');
  exit('400 Bad Request');
}

# check optional
$email = '';
if (isset($_POST['email']) &&
    preg_match('/^.+@.+\..+$/', $_POST['email']) &&
    !preg_match('/[\/]|\.\./', $_POST['email'])) {
  $email = $_POST['email'];
} else {
  $_POST['email'] = '';
}

# construct entry name
#   Format:  <prod>-<ver>-<YYYYMMDDHHMMSS.UUUUUU>-<rand>-[<email>]
#   Example: "Kod-0.0.1-20101221124503.654321-xyz-foo@bar.com"
#   Example: "Kod-0.0.1-20101221124503.654321-xyz-"
date_default_timezone_set(@date_default_timezone_get());
$entry_id = date('YmdHis.u').'-'.
            base_convert(rand(1000,1000000), 10, 36);
$entry_name = $_POST['prod'].'-'.$_POST['ver'].'-'.$entry_id.'-'.$email;

# handle dump file
$dump_filename = $entry_name.'.dmp';
$dump_path = $dump_dir.'/'.$dump_filename;
if (!move_uploaded_file($_FILES['upload_file_minidump']['tmp_name'],
                        $dump_path)) {
  header('HTTP/1.1 400 Bad Request');
  exit('400 Bad Request -- illegal or bad dump file');
}

# store metadata as json
$meta_filename = $entry_name.'.json';
$meta_path = $dump_dir.'/'.$meta_filename;
file_put_contents($meta_path, json_encode($_POST));

# send response
header('HTTP/1.1 201 Created');
header('Connection: close');
header('Content-type: text/plain; charset=utf8');
header('Content-length: '.strlen($entry_name));
echo $entry_name;

# send mail if there are comments
if (isset($_POST['comments']) &&
    ($_POST['comments'] = trim($_POST['comments']))) {
  ignore_user_abort(true);
  
  require 'stackwalk.php';
  $stacktrace = breakpad_stackwalk($dump_path, $symbol_dir);

  $email_body = '';
  foreach ($_POST as $k => $v) {
    if ($k != 'comments')
      $email_body .= $k.': '.$v."\n";
  }
  $email_body .= "entry: $entry_name <$entry_url_base".urlencode($entry_name).">\n".
                 "comments:\n".$_POST['comments'].
                 "\n----\n".$stacktrace."\n";

  $mail = hgmail::newtext($email_recipient,
                          $email_replyto_addr,
                          $email_replyto_name,
                          $_POST['prod'].' '.$_POST['ver'].' crash report '.$entry_id,
                          $email_body);

  $mail->Send();
}

?>