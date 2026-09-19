// Leve tous les fsyncLock du noeud courant. currentOp() ne dit pas si un noeud
// est verrouille, et les verrous s'empilent : on deverrouille jusqu'au refus.
let leves = 0;
try { while (true) { db.fsyncUnlock(); leves++; } } catch (e) { /* plus verrouille */ }
print("  " + db.hello().me + " libre (" + leves + " verrou(s) leve(s))");
