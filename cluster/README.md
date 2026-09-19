# Replica set et sharded cluster — section « Shard et configuration »

Les deux fichiers `docker-compose.yml` sont **exactement** ceux des slides
« Le replica set - la configuration » et « Le sharded cluster - la configuration ».
Le Makefile ne fait que taper à ma place les commandes des slides suivantes
(`rs.initiate`, `sh.addShard`, `sh.shardCollection`…) ; les scripts sont dans `scripts/`.

Il faut Docker (ou Podman avec `docker compose`) et `make`. Image `mongo:7.0`.
Les deux clusters publient le port 27017 : **un seul à la fois**.

Sous Podman rootless (Fedora) :
`export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock` avant `make`.

Tout se lance depuis ce dossier `cluster/`. Rien ne gêne le replica set de
`make demarrer` (ports 27031-27033) : les deux peuvent tourner ensemble.

## Le replica set

```
make rs            # 3 mongod, rs.initiate, puis qui est PRIMARY / SECONDARY
make rs-election   # arrête le primaire : un autre est élu
make rs-reparer    # relance les trois nœuds
make rs-majorite   # arrête deux nœuds : le dernier refuse d'écrire (not primary)
make rs-arreter    # arrête et efface tout
```

Le primaire élu au départ n'est pas forcément `mongo1` : l'élection choisit.
`make rs-election` arrête donc le primaire du moment, quel qu'il soit.

## Le sharded cluster

```
make shard          # config1, shard1, shard2, mongos ; 3 rs.initiate ; 2 sh.addShard
make shard-demo     # 1000 tortues, _id haché : ~50/50 entre sh1 et sh2,
                    # puis SINGLE_SHARD (avec la shard key) contre SHARD_MERGE (sans)
make shard-arreter  # arrête et efface tout
```

La répartition varie d'une exécution à l'autre (485/515 sur la slide, 521/479 ou
529/471 ici) : l'`_id` est un ObjectId neuf à chaque fois, donc son hash aussi.

## Taper les commandes soi-même

```
docker compose -f replica-set/docker-compose.yml exec mongo1 mongosh
docker compose -f sharded-cluster/docker-compose.yml exec mongos mongosh
```
