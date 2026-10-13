<?php
declare(strict_types=1);

/*
 * readlist.php
 * Automatische, seitenweise Ausgabe der lokalen Dateiliste.
 * Gesicherte Versionen bleiben unangetastet.
 */

$file = __DIR__ . '/Dateiliste.txt';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate');

if (!is_file($file) || !is_readable($file)) {
    http_response_code(404);
    echo json_encode([
        'status' => 'error',
        'message' => 'Dateiliste.txt fehlt oder ist nicht lesbar.'
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

$start = filter_input(INPUT_GET, 'start', FILTER_VALIDATE_INT);
$count = filter_input(INPUT_GET, 'count', FILTER_VALIDATE_INT);

$start = ($start !== false && $start !== null && $start >= 1)
    ? $start : 1;

$count = ($count !== false && $count !== null && $count >= 1)
    ? min($count, 50) : 50;

$handle = fopen($file, 'rb');

if ($handle === false) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Dateiliste.txt konnte nicht geöffnet werden.'
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

$total = 0;
$lines = [];

while (($line = fgets($handle)) !== false) {
    $total++;

    if ($total >= $start && count($lines) < $count) {
        $lines[] = rtrim($line, "\r\n");
    }
}

fclose($handle);

echo json_encode([
    'status' => 'ok',
    'total_lines' => $total,
    'start' => $start,
    'returned_lines' => count($lines),
    'next_start' => ($start + count($lines) <= $total)
        ? $start + count($lines)
        : null,
    'lines' => $lines
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
?>
