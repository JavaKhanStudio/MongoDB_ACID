// Attend que mongo1 soit primaire : sa priority: 2 le fait elire, ou reprendre la main a son retour.
const elu = () => rs.status().members.some(m => m.name === "mongo1:27017" && m.stateStr === "PRIMARY")
for (let i = 0; i < 60 && !elu(); i++) sleep(1000);
if (!elu()) throw new Error("mongo1 n'est pas primaire apres 60 s");
