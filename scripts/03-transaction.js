// La meme operation, dans une transaction.
load("/projet/scripts/00-jeu-de-donnees.js");

function deplacer(session, id, de, vers, panne) {
  const base = session.getDatabase("tortues");
  base.turtles.updateOne({ _id: id }, { $set: { habitatId: vers } });
  base.habitats.updateOne({ _id: de }, { $inc: { occupants: -1 } });
  if (panne) throw new Error("panne simulee : l'application tombe ici");
  base.habitats.updateOne({ _id: vers }, { $inc: { occupants: 1 } });
}

const session = db.getMongo().startSession();

titre("1. La panne au milieu, dans une transaction");
try {
  session.withTransaction(() => deplacer(session, "t1", "bassin-a", "bassin-b", true));
} catch (e) {
  dire(e.message);
}
dire("Maki : " + fiche("t1"));
bilan();
dire("Les deux premieres ecritures ont ete annulees avec la transaction.");

titre("2. Sans panne");
session.withTransaction(() => deplacer(session, "t1", "bassin-a", "bassin-b", false));
dire("Maki : " + fiche("t1"));
bilan();
dire("Les trois ecritures sont devenues visibles ensemble, au commit.");

session.endSession();
