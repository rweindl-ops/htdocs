php

$allowed = ['doc', 'docx', 'xls', 'xlsx', 'pdf', 'png', 'txt'];

$files = scandir(__DIR__);

echo '!DOCTYPE html';
echo 'html lang=dehead';
echo 'meta charset=utf-8';
echo 'titleDatei-Indextitle';
echo 'headbody';

echo 'h1Verfügbare Dateienh1';
echo 'ul';

foreach ($files as $file) {
    if ($file === '.'  $file === '..') {
        continue;
    }

    if (!is_file(__DIR__ . '' . $file)) {
        continue;
    }

    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));

    if (!in_array($ext, $allowed, true)) {
        continue;
    }

    $url = rawurlencode($file);

    echo 'li';
    echo 'a href=' . $url . '' . htmlspecialchars($file, ENT_QUOTES, 'UTF-8') . 'a';
    echo 'li';
}

echo 'ul';
echo 'bodyhtml';