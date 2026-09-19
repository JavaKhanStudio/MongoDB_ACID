// ACID sans rien demander : une ecriture sur UN document est atomique.
load("/projet/scripts/00-jeu-de-donnees.js");

titre("1. Trois modifications, un seul document");
tortues.turtles.updateOne({ _id: "t1" }, {
  $set: { "measurements.weightKg": 134 },
  $inc: { observations: 1 },
  $push: { tags: "revue-2026" }
});
printjson(tortues.turtles.findOne({ _id: "t1" }));
dire("Un seul updateOne : aucun autre client n'a pu voir le poids change sans l'observation.");

titre("2. Tout ou rien : une des trois modifications est impossible");
// "name" est une chaine : $inc dessus est refuse par le serveur.
try {
  tortues.turtles.updateOne({ _id: "t1" }, {
    $set: { "measurements.weightKg": 999 },
    $inc: { name: 1 },
    $push: { tags: "jamais-ecrit" }
  });
} catch (e) {
  dire("refus du serveur : " + e.message);
}
printjson(tortues.turtles.findOne({ _id: "t1" }));
dire("Le poids est reste a 134 et le tag n'a pas ete ajoute : rien n'a ete applique.");
dire("C'est l'atomicite, sur un document, sans transaction.");
