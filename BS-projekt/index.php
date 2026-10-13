<!-- S E I T E - Definition -->
<?php readfile ("_doctype.php"); ?>
<?php include ("_root.php"); ?>
<?php include ("_css.php"); ?>

<!-- S E I T E N K O P F - Definition -->
<?php $aktiv="index"; include("_header.php"); ?>


<!-- S E I T E - Hauptbereich -->
<!-- S E I T E N I N H A L T - Definition LEFT -->
  <div style="display: flow-root" class="shadow" id="container_main">
    <div id="main_l">
      <h1>Navi</h1>
  <?php $aktiv="home"; include("_nav/_nav_home.php"); ?>
    </div>

<!-- S E I T E N I N H A L T - Definition MAIN -->
    <div id="main_m">
      <h1>Index (h1)</h1>

      <p><img src="_img/bild_01.jpg" alt="Bild" width="440px" border="0" ></a></p>

      <h2>Textebene (h2)</h2>
      <h3>Textebene (h3)</h3>
      <h4>Textebene (h4)</h4>
      <h5>Textebene (h5)</h5>
      <h6>Textebene (h6)</h6>
      <p>Textinhalt</p>
    </div>

<!-- S E I T E N I N H A L T - Definition RIGHT -->
    <div id="main_r">
      <h1>Info</h1>
    </div>
  </div>


<!-- S E I T E N F U S S - Definition -->
<?php include ("_footer.php"); ?>
