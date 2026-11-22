# Arbeitsregeln für die Zusammenarbeit – Windows-Wiederherstellung

Diese Datei ist eine verbindliche Arbeitsgrundlage für die Unterstützung bei den Reparaturarbeiten an den Laptops. Vor jeder neuen Aufgabe ist sie zu lesen und anzuwenden.

## Grundsatz

**Erst lesen, dann denken, dann handeln.**

Keine Vermutungen, keine unnötigen Tests und keine Wiederholung bereits geklärter Fragen. Ziel ist, die Arbeit beim ersten Anlauf korrekt und mit möglichst wenig Aufwand für den Nutzer zu erledigen.

## Rollen und Arbeitsablauf

- Der Nutzer führt Befehle auf seinen Windows-Geräten aus.
- Der Nutzer aktualisiert die Dateiliste und lädt neue Ergebnisse nach GitHub hoch.
- Der Assistent liest Repository-Dateien, Dateilisten und Ergebnisse über GitHub und wertet sie aus.
- Der Assistent darf niemals behaupten, lokale Befehle ausgeführt oder lokale Dateien geprüft zu haben.
- Nach einem neuen Upload zuerst die aktuelle Dateiliste lesen und danach ausschließlich die dort tatsächlich aufgeführten Dateien und Pfade verwenden.

## Dateien und Pfade

- Vor jedem neuen Befehl zuerst die aktuelle Dateiliste und die relevanten vorhandenen Skripte/Referenzdateien prüfen.
- Keine Pfade aus ähnlichen Laptop-Verzeichnissen ableiten. Insbesondere niemals ungeprüft einen L04-Pfad für L06 oder umgekehrt verwenden.
- Wenn eine benötigte Datei in der Dateiliste fehlt, den Nutzer darauf hinweisen und um Aktualisierung der Dateiliste bitten. Keine Ersatzdatei und keinen Ersatzpfad erfinden.
- Vor der Ausgabe eines Befehls prüfen, ob das Zielverzeichnis bereits existiert oder vom Befehl zuverlässig angelegt wird.
- Bei Verzeichnissen mit Leerzeichen immer korrekt quoten.

## CMD-Befehle – besonders wichtig

Der Nutzer kopiert Befehle aus dem Chat in die Windows-Eingabeaufforderung (CMD). Dabei können mehrzeilige Blöcke beim Kopieren/Einfügen zu einer einzigen Zeile zusammengezogen werden.

Daher gelten zwingend folgende Regeln:

1. **Bevorzugt einen einzigen, vollständig ausführbaren CMD-Einzeiler liefern**, wenn sich die Aufgabe damit zuverlässig erledigen lässt.
2. Wenn mehrere Befehlszeilen erforderlich sind, nicht einfach einen mehrzeiligen Chat-Block voraussetzen. Stattdessen eine robuste Lösung anbieten, z. B. eine gespeicherte BAT-Datei mit eindeutigem Speicherpfad und einem separaten Startbefehl.
3. Niemals Befehle ohne notwendige Trennzeichen/Zeilenumbrüche aneinanderreihen.
4. Vor der Ausgabe den gesamten Befehl auf CMD-Syntax, Anführungszeichen, Umleitungen, Verkettungsoperatoren und Pfade prüfen.
5. Notwendige Voraussetzungen (z. B. Zielordner, Laufwerk, Rechte) **vor** dem Befehl nennen, nicht erst nach einem Fehler.
6. Nicht behaupten, ein Befehl sei getestet worden, wenn er nicht tatsächlich in einer entsprechenden Umgebung ausgeführt werden konnte.
7. Nach einem Fehler zuerst die konkrete Fehlermeldung analysieren. Nicht blind denselben Befehl erneut ausgeben oder den Nutzer mit weiteren Versuchen beschäftigen.

## Laptop-spezifische Fakten

### L06
- Gerät: Lenovo ThinkPad T410.
- Betriebssystem: Windows 32-Bit.
- Diese Architektur ist bekannt und muss nicht erneut abgefragt oder durch unnötige Befehle ermittelt werden.
- Bei Registry-Abfragen ist die 32-Bit-Systemansicht zu berücksichtigen. Keine 64-Bit-/WOW6432Node-Abfragen als vermeintlich separate Registry-Ansicht für dieses 32-Bit-Windows ansetzen.

### L04 als Referenz für L06
- Wenn ausdrücklich L06-Ergebnisse mit L04 verglichen werden sollen, immer die tatsächlichen L04-Referenzdateien heranziehen.
- Niemals L06 mit L06 vergleichen oder versehentlich L04-Dateien als L06-Dateien behandeln.
- Dateinamen und Inhalte anhand der aktuellen GitHub-Dateiliste und der tatsächlichen Dateien verifizieren.

## Avira-Registry-Erfassung L06

Vorgesehener Ausgabeordner auf L06:

X:\000_Festplatte Reparatur\0_WIN_08_Wiederherstellung\LAPTOP06_Reparatur\ACL_Sicherungen\TXT\Avira_Registry_Check_L06

Die sechs vorgesehenen Ergebnisdateien (Namensschema passend zu L04):

1. 01_Uninstall_Avira.txt
2. 02_Uninstall_Avira_32bit.txt
3. 03_Services_Avira.txt
4. 04_Avira_Software.txt
5. 05_Avira_Software_32bit.txt
6. 06_Services_Speedup.txt

Für L06 mit 32-Bit-Windows sind die Dateien 02 und 05 als leere Platzhalter vorgesehen, damit der Dateisatz mit L04 vergleichbar bleibt. Registry-Abfragen sind lesend; keine Registry-Schlüssel verändern oder löschen.

## Kommunikation

- Kurz, konkret und handlungsorientiert antworten.
- Keine Fortschrittsmeldungen ohne nutzbaren Inhalt.
- Bereits bekannte Informationen nicht erneut erfragen.
- Keine unnötigen Architektur-, Pfad- oder Existenztests, wenn diese Informationen bereits aus Nutzerangaben oder der aktuellen Dateiliste hervorgehen.
- Bei einem eigenen Fehler klar sagen, was falsch war, und direkt eine belastbare Korrektur liefern.
- Der Nutzer soll nicht wiederholt dieselben Arbeitsregeln erklären müssen.

## Abschlusskontrolle vor jeder Befehlsausgabe

Vor dem Senden prüfen:

- [ ] Aktuelle Dateiliste und relevante Referenzdateien gelesen?
- [ ] Richtiger Laptop und richtiger Zielpfad?
- [ ] Bekannte Betriebssystemarchitektur berücksichtigt?
- [ ] Zielordner vorhanden oder wird er sicher angelegt?
- [ ] CMD-Befehl als Einzeiler oder robust ausführbare Datei gestaltet?
- [ ] Anführungszeichen, Leerzeichen, Umleitungen und Verkettungen geprüft?
- [ ] Keine unnötigen oder bereits erledigten Schritte enthalten?
- [ ] Klar gesagt, was der Nutzer ausführen und anschließend zurückmelden soll?

Wenn eine dieser Prüfungen nicht erfüllt ist, den Befehl nicht ausgeben.


## Dauerhafte Befehlsdokumentation – verbindlich

- Jeder erstellte und vom Nutzer erfolgreich ausgeführte CMD-/PowerShell-Befehl wird unmittelbar nach erfolgreichem Einsatz in der passenden Laptop-Dokumentation archiviert.
- Das Archiv enthält den **vollständigen Originalbefehl bzw. die vollständige BAT-/PS1-Datei**, den Zweck, das verwendete Gerät, das Ausführungsdatum, den Ausgabeordner und das bestätigte Ergebnis.
- Bei einer Wiederholung auf einem anderen Laptop wird zuerst dieser archivierte, funktionierende Originalbefehl herangezogen. Es werden nur die ausdrücklich laptopabhängigen Angaben geändert (z. B. Gerätename und Ausgabeordner). Registry-Abfragen, Reihenfolge, Dateinamen und Umleitungen bleiben unverändert.
- Bereits vorhandene Befehle und Skripte werden nicht aus dem Gedächtnis neu geschrieben, wenn eine archivierte Fassung existiert.
- Ein Befehl gilt erst dann als erfolgreich, wenn die erwarteten Ausgabedateien tatsächlich vorhanden sind. Eine abschließende `echo`-Meldung ist kein Erfolgsnachweis.
- Nachträgliche Korrekturen werden als neue Version dokumentiert; die zuvor verwendete Fassung bleibt nachvollziehbar erhalten.

## Avira-Registry-Erfassung – Referenz L04 / Wiederholung L06

Die L04-Erfassung umfasst genau diese sechs Dateien und Abfragen:

1. `01_Uninstall_Avira.txt` – `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Avira"`
2. `02_Uninstall_Avira_32bit.txt` – leerer Platzhalter für den vergleichbaren Dateisatz auf 32-Bit-Windows
3. `03_Services_Avira.txt` – `reg query "HKLM\SYSTEM\CurrentControlSet\Services" /s /f "Avira"`
4. `04_Avira_Software.txt` – `reg query "HKLM\SOFTWARE\Avira" /s`
5. `05_Avira_Software_32bit.txt` – leerer Platzhalter für den vergleichbaren Dateisatz auf 32-Bit-Windows
6. `06_Services_Speedup.txt` – `reg query "HKLM\SYSTEM\CurrentControlSet\Services" /s /f "Speedup"`

Die L06-Erfassung muss dieselben sechs Abfragen, Dateinamen und dieselbe Reihenfolge verwenden. Für L06 ist der aktuell bestätigte Ausgabe-Laufwerksbuchstabe **X:**. Der vollständige L06-Ausgabeordner lautet:

`X:\000_Festplatte Reparatur\0_WIN_08_Wiederherstellung\LAPTOP06_Reparatur\ACL_Sicherungen\TXT\Avira_Registry_Check_L06`

Wichtig: In diesem Pfad steht nach `Festplatte` ein Leerzeichen. Jeder einzelne Ausgabepfad muss exakt so geschrieben und vollständig in Anführungszeichen gesetzt werden.
