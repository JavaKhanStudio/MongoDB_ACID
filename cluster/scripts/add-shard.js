// Slide « Le sharded cluster - sh.addShard » : sur mongos
// mongos attend que le config server ait un primaire avant de repondre.
for (let i = 0; i < 60; i++) {
  try { db.adminCommand({ ping: 1 }); break } catch (e) { sleep(1000) }
}
printjson(sh.addShard("sh1/shard1:27017").shardAdded)
printjson(sh.addShard("sh2/shard2:27017").shardAdded)
db.adminCommand({ listShards: 1 }).shards.forEach(s => print(s._id, s.host))
