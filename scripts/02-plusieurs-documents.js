// Ce qui N'EST PAS atomique : des qu'un second document est en jeu.
load("/projet/scripts/00-jeu-de-donnees.js");

titre("1. updateMany qui echoue en route");
// Lova a un poids illisible : l'increment echouera sur elle, et seulement elle.
tortues.turtles.updateOne({ _id: "t3" }, { $set: { "measurements.weightKg": "inconnu" } });
try {
  tortues.turtles.updateMany({}, { $inc: { "measurements.weightKg": 1 } });
} catch (e) {
  dire("refus du serveur : " + e.message);
}
tortues.turtles.find({}, { name: 1, "measurements.weightKg": 1 }).sort({ _id: 1 })
  .forEach(t => dire(t.name.padEnd(6) + " " + t.measurements.weightKg));
dire("Maki et Tsiky ont pris 1 kg, Lova non : l'operation s'est arretee a moitie,");
dire("et rien n'a ete defait. Chaque document est atomique, l'ensemble ne l'est pas.");

load("/projet/scripts/00-jeu-de-donnees.js");

titre("2. Deplacer une tortue sans transaction, avec une panne au milieu");
dire("Maki quitte bassin-a pour bassin-b : trois ecritures sur trois documents.");
try {
  tortues.turtles.updateOne({ _id: "t1" }, { $set: { habitatId: "bassin-b" } });
  tortues.habitats.updateOne({ _id: "bassin-a" }, { $inc: { occupants: -1 } });
  throw new Error("panne simulee : l'application tombe ici");
  tortues.habitats.updateOne({ _id: "bassin-b" }, { $inc: { occupants: 1 } });
} catch (e) {
  dire(e.message);
}
bilan();
dire("Les deux premieres ecritures sont acquises, la troisieme n'a jamais eu lieu.");
dire("Personne ne defait ce qui a ete fait : la base est incoherente et le restera.");
