// Slide « Le replica set - rs.initiate »
try {
  rs.initiate({ _id: "rs0", members: [
    { _id: 0, host: "mongo1:27017" },
    { _id: 1, host: "mongo2:27017" },
    { _id: 2, host: "mongo3:27017" } ] })
} catch (e) { if (e.codeName !== "AlreadyInitialized") throw e }
