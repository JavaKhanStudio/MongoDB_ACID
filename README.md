# MongoDB, ACID ou pas ?

> Des démonstrations exécutables, sur un vrai replica set à 3 nœuds, de ce que
> MongoDB garantit — et de ce qu'il ne garantit pas. Accompagne la section
> « ACID / BASE » du deck MongoDB. Le domaine est celui du cours : des tortues,
> des bassins, les stations Toto et Nosy Be.

---

## Démarrage

```bash
make demarrer    # 3 noeuds mongo:8.0 + initialisation du replica set rsTortues
make 1           # puis 2, 3 ... 8
make shell       # un mongosh sur le replica set, base tortues : c'est là que se tapent les commandes des slides
```

Chaque démonstration remet la base `tortues` dans son état de départ : elles se
jouent dans n'importe quel ordre, autant de fois qu'on veut.

Sous Podman rootless (Fedora) :
`export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock` avant `make`.

---

## Les démonstrations

| make | ce qu'on voit | lettre |
|---|---|---|
| `1` | trois modifications dans **un** `updateOne` : tout ou rien, même quand l'une est impossible | A |
| `2` | **pas ACID** : un `updateMany` qui échoue en route reste à moitié appliqué ; déplacer une tortue sans transaction, avec une panne au milieu, laisse un compteur faux pour toujours | A (absent) |
| `3` | le même déplacement dans `withTransaction` : la panne annule tout, sans panne tout apparaît d'un coup | A, C |
| `4` | une transaction voit ses propres écritures, personne d'autre ; elle lit un instantané ; deux transactions sur le même document → `WriteConflict` | I |
| `5` | **en coulisses** : l'oplog. Sans transaction, trois entrées indépendantes ; avec, **une seule** entrée `applyOps` écrite au commit. Un `$inc` y devient une valeur | A, D |
| `6` | `w: 1` confirme seul ; `w: majority` attend deux nœuds sur trois, et son timeout **n'annule rien** ; `readConcern local` contre `majority` | D |
| `7` | lire sur un secondaire en retard : deux nœuds, deux réponses, puis convergence | BASE |
| `8` | **le rollback** : une écriture confirmée en `w: 1` disparaît quand l'ancien primaire rejoint le groupe, et MongoDB la range dans un fichier `rollback/` | D (absent) |

`make tout` enchaîne 1 à 7. La 8 coupe le réseau d'un conteneur et dure 20 à 40 s.

### Comment on simule une panne

- **L'application qui tombe** (2, 3) : une exception lancée entre deux écritures.
- **Des secondaires en retard** (6, 7) : `fsyncLock` sur un secondaire. Il reste en
  vie et répond aux lectures, mais n'applique plus la réplication. Toujours levé
  dans un `finally` ; si une démo est coupée au Ctrl-C : `make debloquer`.
- **Une partition réseau** (8) : `docker network disconnect` sur le primaire. Isolé,
  il se croit encore primaire une dizaine de secondes et accepte une écriture `w: 1`
  pendant que les deux autres élisent un nouveau primaire.

---

## Ce que l'exécution a appris

Chaque piège ci-dessous a été constaté en jouant les scripts, pas supposé.

| constat | où |
|---|---|
| Un `$set` vers la valeur que la transaction voit déjà est un no-op (`modifiedCount: 0`) : **aucun** `WriteConflict`. Pour montrer le conflit, il faut une vraie modification. | `04` |
| Seuls les conflits écriture / écriture sont détectés : une transaction peut commiter après qu'un autre client a modifié un document qu'elle a lu. | `04`, point 4 |
| Le timeout d'un `w: majority` renvoie `WriteConcernFailed`, mais l'écriture est faite sur le primaire et `readConcern local` la montre. | `06` |
| Un primaire isolé passe en `SECONDARY` tout seul avant même le retour du réseau : attendre cet état ne prouve pas que le rollback a eu lieu. C'est `replSetGetRBID` qui augmente à chaque rollback. | `08` |
| `currentOp()` ne dit pas si un nœud est sous `fsyncLock`, et les verrous s'empilent : `debloquer` déverrouille jusqu'au refus. | `Makefile` |
| Même hors transaction, mongosh numérote chaque écriture (`txnNumber` dans l'oplog) : ce sont les *retryable writes*, pas des transactions. Le script 05 masque ce champ pour ne pas semer le doute. | `05` |

---

## Replica set et sharded cluster

Le dossier [`cluster/`](cluster/README.md) accompagne la section « Shard et
configuration » du deck : les deux `docker-compose.yml` des slides, tels quels
(`mongo:7.0`), et un Makefile qui tape les commandes des slides à ma place.

```bash
cd cluster
make rs          # 3 noeuds, rs.initiate : un PRIMARY, deux SECONDARY
make shard       # config server, 2 shards, mongos, puis sh.addShard
make shard-demo  # 1000 tortues reparties ~50/50, SINGLE_SHARD contre SHARD_MERGE
```

---

## Arborescence

```
docker/docker-compose.yml   3 noeuds mongo:8.0 (ports 27031-27033) + rs-init
scripts/commun.js           titre(), bilan() - le compteur de chaque bassin contre la realite
scripts/00-...07-*.js       les demonstrations, jouees par mongosh --file
scripts/08-rollback.sh      joue depuis l'hote : il faut couper un reseau
scripts/debloquer.js        leve les fsyncLock oublies
Makefile                    make aide
cluster/                    replica set et sharded cluster de la section Shard (cd cluster && make aide)
```

`make arreter` conserve les données, `make purger` efface les volumes.
