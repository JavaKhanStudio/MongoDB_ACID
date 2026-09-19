#!/usr/bin/env bash
# Le D de ACID, jusqu'au bout : une ecriture confirmee en w: 1 peut disparaitre.
# Joue depuis la machine hote (pas dans mongosh) : il faut couper le reseau
# d'un conteneur, ce qu'aucune commande MongoDB ne sait faire.
set -euo pipefail
cd "$(dirname "$0")/.."

RESEAU=mongodb-acid_default
RS="mongodb://mongo1,mongo2,mongo3/?replicaSet=rsTortues"
sh_rs()    { docker exec acid-mongo1 mongosh --quiet "$RS" "$@"; }
sh_local() { docker exec "acid-$1" mongosh --quiet "mongodb://localhost:27017/?directConnection=true" "${@:2}"; }
titre()    { printf '\n=== %s\n' "$1"; }
dire()     { printf '  %s\n' "$1"; }

sh_rs --file /projet/scripts/00-jeu-de-donnees.js > /dev/null
ANCIEN=$(sh_rs --eval 'db.hello().primary.split(":")[0]')
AUTRE=$(sh_rs --eval 'db.hello().hosts.map(h => h.split(":")[0]).find(h => h !== db.hello().primary.split(":")[0])')

titre "1. Je coupe le primaire ($ANCIEN) du reste du replica set"
docker network disconnect "$RESEAU" "acid-$ANCIEN"
dire "Il ne le sait pas encore : il se croit primaire pendant une dizaine de secondes."

titre "2. Pendant ce temps, il accepte une ecriture en w: 1"
sh_local "$ANCIEN" --eval '
  const r = db.getSiblingDB("tortues").turtles.updateOne(
    { _id: "t3" }, { $push: { notes: "ponte observee a 21h" } }, { writeConcern: { w: 1 } });
  print("  confirme : modifiedCount = " + r.modifiedCount);'
dire "Le client a recu sa confirmation. Pour lui, la note est enregistree."

titre "3. De l'autre cote, les deux secondaires elisent un nouveau primaire"
for i in $(seq 1 40); do
  NOUVEAU=$(sh_local "$AUTRE" --eval 'const p = db.hello().primary; print(p ? p.split(":")[0] : "")' 2>/dev/null || true)
  [[ -n "$NOUVEAU" && "$NOUVEAU" != "$ANCIEN" ]] && break
  sleep 1
done
dire "nouveau primaire : $NOUVEAU (apres ~${i}s)"
sh_local "$NOUVEAU" --eval '
  print("  sur " + db.hello().me + ", Lova a pour notes : " +
        JSON.stringify(db.getSiblingDB("tortues").turtles.findOne({ _id: "t3" }).notes || []));'
dire "La note n'y est pas : elle n'a jamais quitte l'ancien primaire."

titre "4. Le reseau revient"
# Isole, l'ancien primaire s'est deja retire en SECONDARY tout seul : attendre
# cet etat ne prouve rien. Le rbid, lui, augmente a chaque rollback effectue.
RBID=$(sh_local "$ANCIEN" --eval 'print(db.adminCommand({ replSetGetRBID: 1 }).rbid)')
docker exec "acid-$ANCIEN" touch /tmp/avant-reconnexion
docker network connect --alias "$ANCIEN" "$RESEAU" "acid-$ANCIEN"
for i in $(seq 1 60); do
  APRES=$(sh_local "$ANCIEN" --eval 'print(db.adminCommand({ replSetGetRBID: 1 }).rbid)' 2>/dev/null || true)
  [[ -n "$APRES" && "$APRES" != "$RBID" ]] && break
  sleep 1
done
dire "$ANCIEN a rejoint le groupe et fait un rollback (rbid $RBID -> $APRES, apres ~${i}s) :"
dire "il a defait ce que la majorite n'avait jamais recu."
sh_local "$ANCIEN" --eval '
  db.getMongo().setReadPref("secondaryPreferred");
  print("  sur " + db.hello().me + ", Lova a pour notes : " +
        JSON.stringify(db.getSiblingDB("tortues").turtles.findOne({ _id: "t3" }).notes || []));'

titre "5. Ce qui a ete defait n'est pas detruit : MongoDB le range a part"
docker exec "acid-$ANCIEN" sh -c 'for f in $(find /data/db/rollback -name "*.bson" -newer /tmp/avant-reconnexion); do
  echo "  $f"; bsondump --quiet "$f" | sed "s/^/    /"; done'
dire "C'est la version d'avant rollback du document : a un humain de decider quoi en faire."
dire "Avec w: majority, le client n'aurait jamais recu de confirmation pour cette note."
