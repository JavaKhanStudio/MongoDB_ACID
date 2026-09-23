// Slide « Le replica set - la majorite » : ecrire sur mongo1 reste seul
try { db.getSiblingDB("tortues").turtles.insertOne({ name: "Crush" }); print("ecriture acceptee") }
catch (e) { print(e.name + "[" + e.codeName + "]: " + e.message) }
