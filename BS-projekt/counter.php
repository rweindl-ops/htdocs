<?php
$filename = "counter.cnt";

$fh = @fopen ($filename, "r");
if ($fh) {
    $hits = trim (fread ($fh, filesize($filename))); 
    @fclose ($fh);
    $hits = intval ($hits);
}
if (empty ($hits)) {
    $hits = 1;
}

echo $hits++;

$fh = @fopen ($filename, "w");
if (!$fh) return;
@fwrite ($fh, $hits);
@fclose ($fh);
?>