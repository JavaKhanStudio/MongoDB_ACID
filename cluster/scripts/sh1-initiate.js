// Slide « Le sharded cluster - rs.initiate » : sur shard1
try { rs.initiate({ _id: "sh1", members: [{ _id: 0, host: "shard1:27017" }] }) }
catch (e) { if (e.codeName !== "AlreadyInitialized") throw e }
