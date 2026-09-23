# =====================================================================
#  Le Makefile de cluster/, pour Windows : sans make, sans WSL.
#  On ne l'appelle pas directement : make.cmd, dans ce dossier, le lance.
#
#      .\make rs                   comme   make rs
#      .\make shard shard-demo     comme   make shard shard-demo
#
# Chaque cible fait ce que fait celle du Makefile, dans le meme ordre.
# Une seule difference : le Makefile passe chaque script a mongosh par
# --eval "$(cat scripts/x.js)". Windows PowerShell 5.1 avale les
# guillemets doubles d'un argument, et les scripts en sont pleins : ici,
# le script est copie dans le conteneur (docker cp), puis joue par --file.
#
# Ecrit pour Windows PowerShell 5.1 : ce fichier reste en ASCII pur.
# =====================================================================

$Racine = $PSScriptRoot
$RS = @('compose', '-f', (Join-Path $Racine 'replica-set/docker-compose.yml'))
$SH = @('compose', '-f', (Join-Path $Racine 'sharded-cluster/docker-compose.yml'))

# Pas nommee Docker : PowerShell ne distingue pas les majuscules, et
# & docker se rappellerait lui-meme.
function Lancer {
    & docker @args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Les conteneurs portent le nom de leur service (container_name).
function Jouer([string]$Conteneur, [string]$Script) {
    Lancer cp (Join-Path $Racine "scripts/$Script") "${Conteneur}:/tmp/$Script"
    Lancer exec $Conteneur mongosh --quiet --file "/tmp/$Script"
}

function Attendre([string]$Conteneur) {
    do {
        & docker exec $Conteneur mongosh --quiet --eval 'db.adminCommand({ping:1})' *> $null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 1
    } while ($true)
}

function Aide {
    @'

  .\make rs            - lance les 3 mongod, rs.initiate, affiche PRIMARY / SECONDARY
  .\make rs-etat       - qui est primaire, qui est secondaire
  .\make rs-election   - arrete mongo1 : mongo2 ou mongo3 est elu
  .\make rs-retour     - relance mongo1 : il rattrape, puis reprend la main
  .\make rs-majorite   - arrete mongo2 et mongo3 : mongo1 seul refuse d'ecrire
  .\make rs-reparer    - relance les trois noeuds, attend mongo1 primaire
  .\make rs-arreter    - arrete et efface le replica set
  .\make shard         - lance le cluster, 3 rs.initiate, 2 sh.addShard
  .\make shard-demo    - 1000 tortues reparties, requete ciblee / diffusee
  .\make shard-arreter - arrete et efface le sharded cluster

'@ | Write-Host
}

function Cible([string]$c) {
    switch ($c) {
        'aide'          { Aide }
        'rs'            {
            Lancer @RS up -d
            Attendre mongo1; Attendre mongo2; Attendre mongo3
            Jouer mongo1 rs-initiate.js
            Jouer mongo1 rs-attendre.js
            Jouer mongo1 rs-etat.js
        }
        'rs-etat'       { Jouer mongo1 rs-etat.js }
        # Slide << Le replica set - l'election >> : mongo1 tombe, on interroge mongo2.
        'rs-election'   {
            Write-Host 'docker stop mongo1, puis sur mongo2, quinze secondes plus tard :'
            Lancer stop mongo1 > $null
            Start-Sleep -Seconds 15
            Jouer mongo2 rs-etat.js
        }
        'rs-retour'     {
            Write-Host "docker start mongo1 : il rattrape l'oplog, puis sa priority: 2 le rend primaire"
            Lancer start mongo1 > $null
            Attendre mongo1
            Jouer mongo1 rs-attendre.js
            Jouer mongo1 rs-etat.js
        }
        'rs-majorite'   {
            Lancer stop mongo2 mongo3
            Start-Sleep -Seconds 15
            Jouer mongo1 rs-etat.js
            Jouer mongo1 rs-ecrire.js
        }
        'rs-reparer'    {
            Lancer @RS start mongo1 mongo2 mongo3
            Attendre mongo1
            Jouer mongo1 rs-attendre.js
            Jouer mongo1 rs-etat.js
        }
        'rs-arreter'    { Lancer @RS down -v }
        'shard'         {
            Lancer @SH up -d
            Attendre config1; Attendre shard1; Attendre shard2
            Jouer config1 cfg-initiate.js
            Jouer shard1 sh1-initiate.js
            Jouer shard2 sh2-initiate.js
            Jouer config1 attendre-primaire.js
            Jouer shard1 attendre-primaire.js
            Jouer shard2 attendre-primaire.js
            Jouer mongos add-shard.js
        }
        'shard-demo'    { Jouer mongos shard-demo.js }
        'shard-arreter' { Lancer @SH down -v }
        default         { Write-Host "  Cible inconnue : $c   (.\make aide liste tout)"; exit 2 }
    }
}

# Comme make : les cibles sont jouees dans l'ordre. Sans cible, l'aide.
$Cibles = @($args)
if ($Cibles.Count -eq 0) { $Cibles = @('aide') }
foreach ($c in $Cibles) { Cible $c }
