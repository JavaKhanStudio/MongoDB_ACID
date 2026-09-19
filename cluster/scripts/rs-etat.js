// Slide « Le replica set »
rs.status().members.forEach(m => print(m.name, m.stateStr))
