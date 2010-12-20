<?
date_default_timezone_set(@date_default_timezone_get());

$error = '';
if (!isset($_POST['email'])) {
  $error = 'No email specified';
} else {
  $_POST['email'] = trim($_POST['email']);
  if (!preg_match('/^.+@.+\..+$/', $_POST['email'])) {
    $error = 'Bad email (did you misspell?)';
  } else {
    $entry = date('c') . ' ' . $_POST['email'] . "\n";
    file_put_contents('../signed-up-for-beta.list', $entry,
                      FILE_APPEND|LOCK_EX);
  }
}

if ($error) {
  header('Location: /?register-for-beta-error='.urlencode($error));
} else {
  header('Location: /?register-for-beta-ok');
}

?>