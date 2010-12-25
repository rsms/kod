<?
date_default_timezone_set(@date_default_timezone_get());

$files = array_reverse(glob('../dist/*.zip'));
if (count($files)) {
  $absolutePath = realpath($files[0]);
  header('Content-Disposition: attachment; filename="Kod.zip"');
  header('Content-Type: application/zip');
  header("X-LIGHTTPD-send-file: ".$absolutePath);
} else {
  header('Location: http://kodapp.com/');
}
?>