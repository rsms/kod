<?
# hunch utils
error_reporting(E_ALL);
date_default_timezone_set(@date_default_timezone_get());

# ------------------------------------------------------------------------------
class h {
  static $basedir = null;
  static $magicQuotes = false;
}

# derive basedir, given we live in <basedir>/something/h.php
h::$basedir = dirname(dirname(__FILE__));
h::$magicQuotes = !!(function_exists('get_magic_quotes_gpc') &&
                     get_magic_quotes_gpc());

# autoload classes from the same directory as we live in
@ini_set('include_path', ini_get('include_path') . ':' . h::$basedir.'/lib');
function __autoload($classname) { require $classname . '.php'; }

# ------------------------------------------------------------------------------
class hlog {
  static $file = null;
  
  # append |prefix| + |msg| to end of |hlog::$file| using an exclusive flock
  static function append($prefix, $msg=false) {
    if (!self::$file) throw new Exception('hlog::$file is not set');
    if ($msg === false) { $msg = $prefix; $prefix = false; }
    $msg = '['.date('Y-m-d H:i:s').($prefix ? ' '.$prefix:'').'] '.
           trim($msg)."\n";
    return file_put_contents(self::$file, $msg, FILE_APPEND|LOCK_EX);
  }
}

# ------------------------------------------------------------------------------
class hhttp {
  static $last_error = false;
  
  # POST something
  static function POST($url, $payload) {
    $body = is_string($payload) ? $payload : http_build_query($payload);
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
    $result = curl_exec($ch);
    self::$last_error = ($result === false) ? curl_error($ch) : false;
    curl_close($ch);
    return $result;
  }
}

# ------------------------------------------------------------------------------
class hgmail {
  static $accountAddress = null;
  static $accountPassword = null;
  # Create a bare-bones mail which can be sent using $mail->Send()
  static function newmail() {
    $mail = new PHPMailer();
    $mail->IsSMTP();
    $mail->SMTPAuth = true;
    $mail->SMTPSecure = 'ssl';
    $mail->Host = 'smtp.gmail.com';
    $mail->Port = 465;
    $mail->Username = self::$accountAddress;
    $mail->Password = self::$accountPassword;
    $mail->CharSet = 'utf-8';
    return $mail;
  }
  # Create a mail which can be sent using $mail->Send()
  static function newtext($to, $from, $from_name, $subject, $body) {
    $mail = self::newmail();
    $mail->SetFrom($from, $from_name);
    $mail->Subject = $subject;
    $mail->Body = $body;
    $mail->AddAddress($to);
    return $mail;
    #if (!$mail->Send())
    #  var_dump($mail->ErrorInfo);
  }
}

# ------------------------------------------------------------------------------
if (function_exists('mb_strtolower')) {
  function utf8strtolower($str) { return mb_strtolower($str, 'UTF-8'); }
} else {
  function utf8strtolower($str) { return strtolower($str); }
}

?>