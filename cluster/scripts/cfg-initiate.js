// Slide « Le sharded cluster - rs.initiate » : sur config1
try {
  rs.initiate({ _id: "cfg", configsvr: true,
    members: [{ _id: 0, host: "config1:27017" }] })
} catch (e) { if (e.codeName !== "AlreadyInitialized") throw e }
