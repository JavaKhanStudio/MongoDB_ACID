// Attend qu'un des trois noeuds soit elu primaire : pas forcement mongo1.
const elu = () => rs.status().members.some(m => m.stateStr === "PRIMARY")
for (let i = 0; i < 60 && !elu(); i++) sleep(1000);
if (!elu()) throw new Error("pas de primaire apres 60 s");
