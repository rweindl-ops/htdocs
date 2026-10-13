
<?php
/*
 * Read-only file reader for testing.
 * Replace the token with a long random secret.
 * Restrict access to the project files you intend to share.
 */

$token = '12345';
$root  = realpath(__DIR__);

if (!isset($_GET['key']) ||
    !hash_equals($token, (string)$_GET['key'])) {
    http_response_code(403);
    exit('Forbidden');
}

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

$path = isset($_GET['path']) ? (string)$_GET['path'] : '';

if (strpos($path, "\0") !== false ||
    preg_match('~(^|[\\\\/])\.\.([\\\\/]|$)~', $path)) {
    http_response_code(400);
    exit(json_encode(['error' => 'Invalid path']));
}

$target = realpath($root . DIRECTORY_SEPARATOR . $path);

if ($target === false ||
    ($target !== $root &&
     strpos($target, $root . DIRECTORY_SEPARATOR) !== 0)) {
    http_response_code(404);
    exit(json_encode(['error' => 'Not found']));
}

if (is_dir($target)) {
    $items = [];
    foreach (scandir($target) as $name) {
        if ($name === '.' || $name === '..') continue;
        $full = $target . DIRECTORY_SEPARATOR . $name;
        $items[] = [
            'name' => $name,
            'type' => is_dir($full) ? 'dir' : 'file'
        ];
    }
    echo json_encode(
        ['path' => $path, 'items' => $items],
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE
    );
    exit;
}

if (!is_file($target) || !is_readable($target) ||
    filesize($target) > 200000) {
    http_response_code(403);
    exit(json_encode(['error' => 'File unavailable or too large']));
}

$ext = strtolower(pathinfo($target, PATHINFO_EXTENSION));
$allowed = ['php', 'html', 'htm', 'css', 'js', 'txt', 'json', 'xml', 'md'];

if (!in_array($ext, $allowed, true)) {
    http_response_code(403);
    exit(json_encode(['error' => 'File type not allowed']));
}

echo json_encode([
    'path' => $path,
    'content' => file_get_contents($target)
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
