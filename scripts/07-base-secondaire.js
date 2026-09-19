// BASE dans MongoDB : lire sur un secondaire, c'est accepter une donnee en retard.
load("/projet/scripts/00-jeu-de-donnees.js");

const lent = secondaires()[1];
const surLent = noeud(lent).getDB("tortues");

try {
  noeud(lent).getDB("admin").fsyncLock();
  dire(lent + " ne suit plus la replication (gele).");

  titre("1. Une ecriture confirmee par la majorite");
  tortues.turtles.updateOne({ _id: "t3" }, { $inc: { observations: 1 } }, { writeConcern: { w: "majority" } });
  dire("w: majority confirme : le primaire et un secondaire l'ont, deux sur trois suffisent.");

  titre("2. Qui voit quoi");
  dire("primaire         : Lova a " + tortues.turtles.findOne({ _id: "t3" }).observations + " observations");
  dire(lent.padEnd(16) + " : Lova a " + surLent.turtles.findOne({ _id: "t3" }).observations + " observations");
  dire("Soft State : deux noeuds, deux reponses. Le secondaire en retard repond quand meme,");
  dire("il reste disponible (Basically Available), mais avec une valeur perimee.");
} finally {
  noeud(lent).getDB("admin").fsyncUnlock();
}

titre("3. Eventual consistency");
sleep(2000);
dire(lent.padEnd(16) + " : Lova a " + surLent.turtles.findOne({ _id: "t3" }).observations + " observations");
dire("Une fois la replication reprise, tout le monde converge vers la meme valeur.");
