<?php
declare(strict_types=1);

// Diagnose für Dateiliste.txt
$file = __DIR__ . '/Dateiliste.txt';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

$result = [
    'status' => 'ok',
    'script' => 'readlist.php',
    'php_version' => PHP_VERSION,
    'directory' => basename(__DIR__),
    'file' => 'Dateiliste.txt',
    'exists' => is_file($file),
    'readable' => is_readable($file),
];

if (!is_file($file)) {
    http_response_code(404);
    $result['status'] = 'error';
    $result['message'] = 'Dateiliste.txt wurde nicht gefunden.';
    echo json_encode(
        $result,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE
    );
    exit;
}

if (!is_readable($file)) {
    http_response_code(500);
    $result['status'] = 'error';
    $result['message'] = 'Dateiliste.txt ist nicht lesbar.';
    echo json_encode(
        $result,
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE
    );
    exit;
}

$result['size_bytes'] = filesize($file);

$content = file_get_contents($file);

if ($content === false) {
    http_response_code(500);
    $result['status'] = 'error';
    $result['message'] = 'Datei konnte nicht eingelesen werden.';
} else {
    $result['bytes_read'] = strlen($content);
    $result['line_count'] = substr_count($content, "\n")
        + (($content !== '' && substr($content, -1) !== "\n") ? 1 : 0);
    $result['preview'] = substr($content, 0, 1200);
}

echo json_encode(
    $result,
    JSON_PRETTY_PRINT
    | JSON_UNESCAPED_UNICODE
    | JSON_UNESCAPED_SLASHES
);
?>
```
