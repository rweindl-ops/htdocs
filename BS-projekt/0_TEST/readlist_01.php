<?php
$file = __DIR__ . '/Dateiliste.txt';

if (!is_file($file) || !is_readable($file)) {
    http_response_code(404);
    exit('Dateiliste.txt nicht gefunden oder nicht lesbar.');
}

header('Content-Type: text/plain; charset=utf-8');
readfile($file);
?>
```
