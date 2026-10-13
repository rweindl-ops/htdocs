
<?php
header('Content-Type: application/json; charset=utf-8');

$dir = __DIR__ . '/Gehre_Mietvertrag_01_files';
$baseUrl = 'https://www.t-projekt.com/0_ARCHIV/Privat/Gehre_Mietvertrag_01_files/';

if (!is_dir($dir)) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Das Verzeichnis wurde nicht gefunden.'
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

$files = [];

foreach (scandir($dir) as $name) {
    if ($name === '.' || $name === '..') {
        continue;
    }

    $path = $dir . '/' . $name;

    if (is_file($path)) {
        $files[] = [
            'name' => $name,
            'size' => filesize($path),
            'url'  => $baseUrl . rawurlencode($name)
        ];
    }
}

echo json_encode([
    'directory' => 'Gehre_Mietvertrag_01_files',
    'count' => count($files),
    'files' => $files
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
?>