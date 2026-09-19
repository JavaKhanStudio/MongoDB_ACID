// Slide « Le replica set - la majorite » : ecrire sur un noeud seul
try { db.getSiblingDB("tortues").turtles.insertOne({ name: "Nosy" }); print("ecriture acceptee") }
catch (e) { print(e.name + ": " + e.message) }
