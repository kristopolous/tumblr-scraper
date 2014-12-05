<?php
/*
 * A simple global blacklist maintainer for the greasemonkey plugin.
 */
if(isset($_GET['urlList'])) {
  $newList = $_GET['urlList'];
} else {
  $newList = array();
}

if(isset($_GET['last'])) {
  $last = intval($_GET['last']);
} else {
  $last = 0;
}

if(file_exists('blacklist.txt')) {
  $list = file("blacklist.txt",FILE_IGNORE_NEW_LINES);
} else {
  $list = array();
}

$toSend = array_slice($list, $last);

$dirty = false;
foreach($newList as $url) {
  if(array_search($url, $list) === false) {
    $list[] = $url;
    $dirty = true;
  }
}

if($dirty) {
  file_put_contents("blacklist.txt", implode("\n", $list));
}

echo json_encode(array(
  'url' => $toSend,
  'last' => count($list)
));
