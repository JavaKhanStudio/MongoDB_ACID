// Le I de ACID : ce que les autres voient pendant qu'une transaction travaille.
load("/projet/scripts/00-jeu-de-donnees.js");

const a = db.getMongo().startSession();
const b = db.getMongo().startSession();
const baseA = a.getDatabase("tortues");
const baseB = b.getDatabase("tortues");

titre("1. Une transaction voit ses propres ecritures, personne d'autre");
a.startTransaction();
baseA.turtles.updateOne({ _id: "t1" }, { $set: { habitatId: "bassin-b" } });
dire("dans la transaction A : " + fiche("t1", baseA));
dire("vu de l'exterieur     : " + fiche("t1"));
a.abortTransaction();
dire("apres abort           : " + fiche("t1"));

titre("2. Un instantane : la transaction ne voit pas ce qui arrive apres son debut");
a.startTransaction();
dire("A lit bassin-b          : " + baseA.habitats.findOne({ _id: "bassin-b" }).occupants + " occupant(s)");
tortues.habitats.updateOne({ _id: "bassin-b" }, { $inc: { occupants: 10 } });
dire("un autre client ajoute 10, vu de l'exterieur : "
     + tortues.habitats.findOne({ _id: "bassin-b" }).occupants);
dire("A relit bassin-b        : " + baseA.habitats.findOne({ _id: "bassin-b" }).occupants + " occupant(s)");
a.commitTransaction();
dire("A lit toujours le monde tel qu'il etait a son debut (readConcern snapshot).");
tortues.habitats.updateOne({ _id: "bassin-b" }, { $inc: { occupants: -10 } });

titre("3. Deux transactions ecrivent le meme document");
a.startTransaction();
b.startTransaction();
baseA.turtles.updateOne({ _id: "t1" }, { $set: { habitatId: "bassin-b" } });
dire("A a modifie Maki, sans commit.");
// B doit reellement changer quelque chose : un $set vers la valeur que B voit
// deja est un no-op (modifiedCount 0), sans ecriture donc sans conflit.
try {
  baseB.turtles.updateOne({ _id: "t1" }, { $inc: { observations: 1 } });
  dire("B a modifie Maki aussi ?!");
} catch (e) {
  dire("B est refusee : " + e.codeName + ", etiquette " + JSON.stringify(e.errorLabels));
}
try { b.abortTransaction(); } catch (e) { /* deja annulee par le serveur */ }
a.commitTransaction();
dire("Maki : " + fiche("t1") + ", " + tortues.turtles.findOne({ _id: "t1" }).observations + " observations");
dire("MongoDB ne fait pas attendre B : il l'annule tout de suite.");
dire("L'etiquette TransientTransactionError dit au client qu'il peut rejouer ;");
dire("withTransaction() le fait tout seul, startTransaction() non.");

titre("4. Ce que l'isolation ne couvre pas");
dire("Seuls les conflits ECRITURE / ECRITURE sont detectes. Au point 2, un autre");
dire("client a modifie un document que A venait de lire, et A a commite sans erreur.");

a.endSession();
b.endSession();
