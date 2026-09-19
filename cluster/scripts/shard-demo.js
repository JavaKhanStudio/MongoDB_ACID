// Slides « Le sharded cluster - sh.shardCollection » et « - une requete ciblee »
db = db.getSiblingDB("tortues")
db.turtles.drop()
sh.shardCollection("tortues.turtles", { _id: "hashed" })
db.turtles.insertMany(Array.from({ length: 1000 },
  (_, i) => ({ name: "tortue-" + i })))

print("--- db.turtles.getShardDistribution()")
print(db.turtles.getShardDistribution())

print("--- une requete qui porte la shard key, puis une qui ne la porte pas")
const id = db.turtles.findOne({ name: "tortue-42" })._id
print(db.turtles.find({ _id: id }).explain().queryPlanner.winningPlan.stage)
print(db.turtles.find({ name: "tortue-42" }).explain().queryPlanner.winningPlan.stage)
