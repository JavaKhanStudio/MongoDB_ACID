// Un replica set a un seul membre : attend que ce mongod soit devenu primaire (l'election prend quelques secondes).
for (let i = 0; i < 60 && !db.hello().isWritablePrimary; i++) sleep(1000);
if (!db.hello().isWritablePrimary) throw new Error("pas de primaire apres 60 s");
