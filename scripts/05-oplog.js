// En coulisses : ce que le primaire ecrit dans l'oplog, que les secondaires rejouent.
load("/projet/scripts/00-jeu-de-donnees.js");

const oplog = db.getSiblingDB("local").oplog.rs;
function dernierTs() { return oplog.find().sort({ $natural: -1 }).limit(1).next().ts; }
function entreesDepuis(ts) {
  return oplog.find({ ts: { $gt: ts }, $or: [{ ns: /^tortues\./ }, { "o.applyOps.ns": /^tortues\./ }] },
                    { _id: 0, ts: 1, op: 1, ns: 1, o: 1, o2: 1 }).sort({ $natural: 1 }).toArray();
}

titre("1. Deplacer Maki SANS transaction");
let depuis = dernierTs();
tortues.turtles.updateOne({ _id: "t1" }, { $set: { habitatId: "bassin-b" } });
tortues.habitats.updateOne({ _id: "bassin-a" }, { $inc: { occupants: -1 } });
tortues.habitats.updateOne({ _id: "bassin-b" }, { $inc: { occupants: 1 } });
let e = entreesDepuis(depuis);
dire(e.length + " entrees dans l'oplog :");
e.forEach(x => printjson(x));
dire("Trois entrees independantes : un secondaire peut en avoir rejoue une sans les autres.");

titre("2. Le retour de Maki DANS une transaction");
const session = db.getMongo().startSession();
depuis = dernierTs();
session.withTransaction(() => {
  const base = session.getDatabase("tortues");
  base.turtles.updateOne({ _id: "t1" }, { $set: { habitatId: "bassin-a" } });
  base.habitats.updateOne({ _id: "bassin-b" }, { $inc: { occupants: -1 } });
  base.habitats.updateOne({ _id: "bassin-a" }, { $inc: { occupants: 1 } });
});
session.endSession();
e = entreesDepuis(depuis);
dire(e.length + " entree dans l'oplog :");
e.forEach(x => printjson(x));
dire("Une seule entree applyOps, ecrite au commit : un secondaire la rejoue en entier");
dire("ou pas du tout. Avant le commit, rien n'est ecrit dans l'oplog, donc rien a annuler.");

titre("3. Un $inc devient une valeur");
dire("Regarder les entrees sur les habitats : l'oplog ne dit pas 'ajoute 1', il dit");
dire("'occupants vaut maintenant 2'. Rejouer deux fois la meme entree donne le meme");
dire("resultat : c'est ce qui permet a un secondaire de reprendre sans double comptage.");
