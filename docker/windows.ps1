# =====================================================================
#  Le Makefile, pour Windows : sans make, sans WSL, sans Git Bash.
#  On ne l'appelle pas directement : make.cmd, a la racine, le lance.
#
#      .\make demarrer             comme   make demarrer
#      .\make 1                    comme   make 1
#      .\make shell
#
# Chaque cible fait EXACTEMENT ce que fait celle du Makefile : les memes
# commandes docker, les memes .js joues dans le conteneur. La cible 8
# refait ici, en PowerShell, ce que scripts/08-rollback.sh fait en bash.
# Une cible qui change dans le Makefile change ici aussi.
#
# Ecrit pour Windows PowerShell 5.1 (celui de Windows 10 et 11) :
#   - ce fichier reste en ASCII pur : 5.1 lit un .ps1 sans BOM comme de
#     l'ANSI, et un accent y deviendrait du charabia ;
#   - aucun guillemet double dans un argument passe a docker : 5.1 les
#     avale en route. Le JavaScript de --eval n'utilise que des simples.
# =====================================================================

$Racine  = Split-Path -Parent $PSScriptRoot
$Compose = @('compose', '-f', (Join-Path $Racine 'docker/docker-compose.yml'))
$RS      = 'mongodb://mongo1,mongo2,mongo3/?replicaSet=rsTortues'
$Reseau  = 'mongodb-acid_default'

$Demos = [ordered]@{
    '1' = '01-un-document.js'; '2' = '02-plusieurs-documents.js'; '3' = '03-transaction.js'
    '4' = '04-isolation.js';   '5' = '05-oplog.js';              '6' = '06-durabilite.js'
    '7' = '07-base-secondaire.js'
}

# Pas nommee Docker : PowerShell ne distingue pas les majuscules, et
# & docker se rappellerait lui-meme.
function Lancer {
    & docker @args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Jouer([string]$Fichier) {
    Lancer exec acid-mongo1 mongosh --quiet $RS --file "/projet/scripts/$Fichier"
}

function Aide {
    @'

  .\make demarrer   - lance les 3 noeuds et initie le replica set
  .\make 1 ... 7    - joue une demonstration (voir README)
  .\make 8          - le rollback : coupe le reseau du primaire (~30 s)
  .\make tout       - les demonstrations 1 a 7 a la suite
  .\make etat       - qui est primaire, qui est secondaire
  .\make shell      - mongosh sur le replica set, base tortues
  .\make debloquer  - degele les secondaires si une demo a ete interrompue
  .\make arreter    - arrete, conserve les donnees
  .\make purger     - arrete et EFFACE les volumes

  Le replica set et le sharded cluster de la section Shard :
  cd cluster, puis .\make aide

'@ | Write-Host
}

function Demarrer {
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '  Docker ne repond pas. Lancer Docker Desktop, attendre que'
        Write-Host '  la baleine arrete de clignoter, et recommencer.'
        Write-Host ''
        exit 1
    }
    Lancer @Compose up -d
    & docker wait acid-rs-init > $null
    Lancer logs acid-rs-init
}

# ---------------------------------------------------------------------
# La demo 8, portee de scripts/08-rollback.sh. Memes etapes, memes
# commandes, memes phrases.
# ---------------------------------------------------------------------
function ShRs    { & docker exec acid-mongo1 mongosh --quiet $RS @args }
function ShLocal([string]$Noeud) {
    & docker exec "acid-$Noeud" mongosh --quiet 'mongodb://localhost:27017/?directConnection=true' @args
}
function Titre([string]$t) { Write-Host ''; Write-Host "=== $t" }
function Dire([string]$t)  { Write-Host "  $t" }
# Une commande rend un tableau de lignes : on garde la derniere, sans blancs.
function Valeur($x) { if ($null -eq $x) { '' } else { "$(@($x)[-1])".Trim() } }

function Rollback {
    ShRs --file /projet/scripts/00-jeu-de-donnees.js > $null
    $ancien = Valeur (ShRs --eval "db.hello().primary.split(':')[0]")
    $autre  = Valeur (ShRs --eval "db.hello().hosts.map(h => h.split(':')[0]).find(h => h !== db.hello().primary.split(':')[0])")

    Titre "1. Je coupe le primaire ($ancien) du reste du replica set"
    Lancer network disconnect $Reseau "acid-$ancien"
    Dire "Il ne le sait pas encore : il se croit primaire pendant une dizaine de secondes."

    Titre '2. Pendant ce temps, il accepte une ecriture en w: 1'
    ShLocal $ancien --eval @'
const r = db.getSiblingDB('tortues').turtles.updateOne(
  { _id: 't3' }, { $push: { notes: 'ponte observee a 21h' } }, { writeConcern: { w: 1 } });
print('  confirme : modifiedCount = ' + r.modifiedCount);
'@
    Dire 'Le client a recu sa confirmation. Pour lui, la note est enregistree.'

    Titre "3. De l'autre cote, les deux secondaires elisent un nouveau primaire"
    $nouveau = ''
    for ($i = 1; $i -le 40; $i++) {
        $nouveau = Valeur (ShLocal $autre --eval "const p = db.hello().primary; print(p ? p.split(':')[0] : '')" 2>$null)
        if ($nouveau -and $nouveau -ne $ancien) { break }
        Start-Sleep -Seconds 1
    }
    Dire "nouveau primaire : $nouveau (apres ~${i}s)"
    ShLocal $nouveau --eval @'
print('  sur ' + db.hello().me + ', Lova a pour notes : ' +
      JSON.stringify(db.getSiblingDB('tortues').turtles.findOne({ _id: 't3' }).notes || []));
'@
    Dire "La note n'y est pas : elle n'a jamais quitte l'ancien primaire."

    Titre '4. Le reseau revient'
    # Isole, l'ancien primaire s'est deja retire en SECONDARY tout seul : attendre
    # cet etat ne prouve rien. Le rbid, lui, augmente a chaque rollback effectue.
    $rbid = Valeur (ShLocal $ancien --eval 'print(db.adminCommand({ replSetGetRBID: 1 }).rbid)')
    Lancer exec "acid-$ancien" touch /tmp/avant-reconnexion
    Lancer network connect --alias $ancien $Reseau "acid-$ancien"
    $apres = ''
    for ($i = 1; $i -le 60; $i++) {
        $apres = Valeur (ShLocal $ancien --eval 'print(db.adminCommand({ replSetGetRBID: 1 }).rbid)' 2>$null)
        if ($apres -and $apres -ne $rbid) { break }
        Start-Sleep -Seconds 1
    }
    Dire "$ancien a rejoint le groupe et fait un rollback (rbid $rbid -> $apres, apres ~${i}s) :"
    Dire "il a defait ce que la majorite n'avait jamais recu."
    ShLocal $ancien --eval @'
db.getMongo().setReadPref('secondaryPreferred');
print('  sur ' + db.hello().me + ', Lova a pour notes : ' +
      JSON.stringify(db.getSiblingDB('tortues').turtles.findOne({ _id: 't3' }).notes || []));
'@

    Titre "5. Ce qui a ete defait n'est pas detruit : MongoDB le range a part"
    Lancer exec "acid-$ancien" sh -c 'for f in $(find /data/db/rollback -name ''*.bson'' -newer /tmp/avant-reconnexion); do echo ''  ''$f; bsondump --quiet $f | sed ''s/^/    /''; done'
    Dire "C'est la version d'avant rollback du document : a un humain de decider quoi en faire."
    Dire "Avec w: majority, le client n'aurait jamais recu de confirmation pour cette note."
}

function Cible([string]$c) {
    if ($Demos.Contains($c)) { Jouer $Demos[$c]; return }
    switch ($c) {
        'aide'      { Aide }
        'demarrer'  { Demarrer }
        '8'         { Rollback }
        'rollback'  { Rollback }
        'tout'      { foreach ($d in $Demos.Keys) { Cible $d } }
        'etat'      {
            Lancer exec acid-mongo1 mongosh --quiet $RS --eval `
              "rs.status().members.forEach(m => print('  ' + m.name.padEnd(14) + m.stateStr))"
        }
        # La base va dans l'URI : un nom place apres l'URI, mongosh le lit comme un fichier a jouer.
        'shell'     { Lancer exec -it acid-mongo1 mongosh --quiet 'mongodb://mongo1,mongo2,mongo3/tortues?replicaSet=rsTortues' }
        # Une demo 6 ou 7 coupee au milieu (Ctrl-C) laisse des secondaires geles par
        # fsyncLock : la replication reste arretee tant qu'on ne les libere pas.
        'debloquer' {
            foreach ($n in 'mongo1', 'mongo2', 'mongo3') {
                Lancer exec "acid-$n" mongosh --quiet --file /projet/scripts/debloquer.js
            }
        }
        'arreter'   { Lancer @Compose down }
        'purger'    { Lancer @Compose down -v }
        default     { Write-Host "  Cible inconnue : $c   (.\make aide liste tout)"; exit 2 }
    }
}

# Comme make : les cibles sont jouees dans l'ordre. Sans cible, l'aide.
$Cibles = @($args)
if ($Cibles.Count -eq 0) { $Cibles = @('aide') }
foreach ($c in $Cibles) { Cible $c }
