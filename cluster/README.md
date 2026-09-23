# Replica set et sharded cluster — section « Shard et configuration »

Les deux fichiers `docker-compose.yml` sont **exactement** ceux des slides
« Le replica set - le fichier compose » et « Le sharded cluster - le fichier compose ».
Le Makefile ne fait que taper à ma place les commandes des slides suivantes
(`rs.initiate`, `sh.addShard`, `sh.shardCollection`…) ; les scripts sont dans `scripts/`.

Il faut Docker (ou Podman avec `docker compose`) et `make`. Image `mongo:7.0`.
Aucun des deux ne publie de port : ils tournent à côté du conteneur `mongodb` du cours
(qui garde le 27017), et l'on parle à chaque nœud avec `docker exec`.

Sous Podman rootless (Fedora) :
`export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock` avant `make`.

Tout se lance depuis ce dossier `cluster/`. Rien ne gêne le replica set de
`make demarrer` (ports 27031-27033) : les deux peuvent tourner ensemble.

## Le replica set

```
make rs            # 3 mongod, rs.initiate, puis qui est PRIMARY / SECONDARY
make rs-election   # arrête mongo1 : mongo2 ou mongo3 est élu
make rs-retour     # relance mongo1 : il rattrape, puis reprend la main
make rs-reparer    # relance les trois nœuds
make rs-majorite   # arrête deux nœuds : le dernier refuse d'écrire (not primary)
make rs-arreter    # arrête et efface tout
```

`rs.initiate` donne à `mongo1` une `priority: 2` : il est toujours élu au départ, et
reprend la main quand il revient après `make rs-election`.

## Le sharded cluster

```
make shard          # config1, shard1, shard2, mongos ; 3 rs.initiate ; 2 sh.addShard
make shard-demo     # 1000 tortues, _id haché : ~50/50 entre sh1 et sh2,
                    # puis SINGLE_SHARD (avec la shard key) contre SHARD_MERGE (sans)
make shard-arreter  # arrête et efface tout
```

La répartition varie d'une exécution à l'autre (486/514 sur la slide, 487/513 ou
521/479 ici) : l'`_id` est un ObjectId neuf à chaque fois, donc son hash aussi.

## Taper les commandes soi-même

```
docker exec -it mongo1 mongosh
docker exec -it mongo2 mongosh "mongodb://mongo1,mongo2,mongo3/tortues?replicaSet=rs0"
docker exec -it mongos mongosh
```
