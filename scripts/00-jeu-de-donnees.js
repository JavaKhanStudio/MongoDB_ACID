// Remet la base "tortues" dans son etat de depart. Chaque demonstration
// commence par la. Rejouable a volonte.
load("/projet/scripts/commun.js");

tortues.dropDatabase();

tortues.habitats.insertMany([
  { _id: "bassin-a", station: "Toto",    occupants: 2 },
  { _id: "bassin-b", station: "Nosy Be", occupants: 1 }
], { writeConcern: { w: "majority" } });

tortues.turtles.insertMany([
  { _id: "t1", name: "Maki",  habitatId: "bassin-a", measurements: { weightKg: 130 }, observations: 4 },
  { _id: "t2", name: "Tsiky", habitatId: "bassin-a", measurements: { weightKg: 98 },  observations: 2 },
  { _id: "t3", name: "Lova",  habitatId: "bassin-b", measurements: { weightKg: 112 }, observations: 7 }
], { writeConcern: { w: "majority" } });

titre("Etat de depart");
bilan();
