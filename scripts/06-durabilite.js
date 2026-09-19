// Le D de ACID : a quel moment une ecriture est-elle vraiment acquise ?
// Pour simuler des secondaires qui ne suivent plus, on les gele avec fsyncLock :
// ils restent en vie mais n'appliquent plus rien.
load("/projet/scripts/00-jeu-de-donnees.js");

const geles = secondaires();
function geler()    { geles.forEach(h => noeud(h).getDB("admin").fsyncLock()); dire("secondaires geles : " + geles.join(", ")); }
function degeler()  { geles.forEach(h => { try { noeud(h).getDB("admin").fsyncUnlock(); } catch (e) {} }); }

try {
  geler();

  titre("1. w: 1 - le primaire seul a confirme");
  const r = tortues.turtles.updateOne({ _id: "t2" }, { $inc: { observations: 1 } }, { writeConcern: { w: 1 } });
  dire("confirme : modifiedCount = " + r.modifiedCount);
  dire("Confirme tout de suite, alors qu'aucun secondaire n'a la donnee.");

  titre("2. w: majority - il faut deux machines sur trois");
  const debut = Date.now();
  try {
    tortues.turtles.updateOne({ _id: "t2" }, { $inc: { observations: 1 } },
                              { writeConcern: { w: "majority", wtimeout: 3000 } });
  } catch (e) {
    dire("apres " + (Date.now() - debut) + " ms : " + e.codeName + " - " + e.message);
  }
  dire("Piege : le timeout n'annule RIEN. L'ecriture est faite sur le primaire,");
  dire("MongoDB dit seulement qu'il n'a pas pu la garantir dans le delai.");

  titre("3. readConcern : ce qui est ecrit contre ce qui est acquis");
  dire("local    : Tsiky a " + tortues.turtles.find({ _id: "t2" }).readConcern("local").next().observations + " observations");
  dire("majority : Tsiky a " + tortues.turtles.find({ _id: "t2" }).readConcern("majority").next().observations + " observations");
  dire("local montre les deux ecritures, dont rien ne garantit qu'elles survivront.");
  dire("majority ne montre que ce qui ne peut plus etre perdu.");
} finally {
  degeler();
}

titre("4. Les secondaires repartent");
sleep(2000);
dire("majority : Tsiky a " + tortues.turtles.find({ _id: "t2" }).readConcern("majority").next().observations + " observations");
dire("La majorite a rattrape : les deux ecritures sont maintenant acquises.");
