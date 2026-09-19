// Initie le replica set rsTortues puis attend qu'un primaire soit elu.
try {
  rs.status();
  print("replica set deja initie");
  quit(0);
} catch (e) {
  // NotYetInitialized : premier demarrage.
}

// Priorites egales : apres une panne, personne ne reprend la main de force,
// ce qui garde la demonstration du rollback lisible.
rs.initiate({
  _id: "rsTortues",
  members: [
    { _id: 0, host: "mongo1:27017" },
    { _id: 1, host: "mongo2:27017" },
    { _id: 2, host: "mongo3:27017" }
  ]
});

let tours = 0;
while (!db.hello().isWritablePrimary && tours < 30) { sleep(1000); tours++; }
print("replica set rsTortues pret, primaire = " + db.hello().primary);
