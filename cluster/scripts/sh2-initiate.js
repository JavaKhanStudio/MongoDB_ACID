// Slide « Le sharded cluster - rs.initiate » : sur shard2
try { rs.initiate({ _id: "sh2", members: [{ _id: 0, host: "shard2:27017" }] }) }
catch (e) { if (e.codeName !== "AlreadyInitialized") throw e }
