// Outils partages par les demonstrations. Charge par load() en tete de script.

const tortues = db.getSiblingDB("tortues");

function titre(t) { print("\n=== " + t + " " + "=".repeat(Math.max(0, 66 - t.length))); }
function dire(t)  { print("  " + t); }

// Chaque bassin tient un compteur d'occupants. Il est juste si et seulement si
// il egale le nombre de tortues qui pointent vers ce bassin.
function bilan(base) {
  base = base || tortues;
  let juste = true;
  base.habitats.find().sort({ _id: 1 }).forEach(function (h) {
    const reel = base.turtles.countDocuments({ habitatId: h._id });
    const ok = reel === h.occupants;
    if (!ok) juste = false;
    dire((ok ? "  ok  " : "  FAUX") + "  " + h._id.padEnd(9) + " (" + h.station + ")  compteur = "
         + h.occupants + ", tortues presentes = " + reel);
  });
  return juste;
}

function fiche(id, base) {
  const t = (base || tortues).turtles.findOne({ _id: id });
  return t ? t.name + " -> " + t.habitatId : "(absente)";
}

// Connexion directe a un noeud precis, lecture autorisee meme sur un secondaire.
function noeud(hote) {
  const m = new Mongo(hote + ":27017/?directConnection=true");
  m.setReadPref("secondaryPreferred");
  return m;
}

function secondaires() {
  const primaire = db.hello().primary;
  return db.hello().hosts.filter(h => h !== primaire).map(h => h.split(":")[0]);
}
