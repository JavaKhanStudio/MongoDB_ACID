// Slide « Le replica set - la verification »
printjson(rs.status().members.map(m => m.name + " " + m.stateStr))
