# Demonstrations ACID / BASE sur un replica set MongoDB a 3 noeuds.

COMPOSE = docker compose -f docker/docker-compose.yml
RS      = mongodb://mongo1,mongo2,mongo3/?replicaSet=rsTortues
MONGOSH = docker exec -it acid-mongo1 mongosh --quiet "$(RS)"
JOUER   = docker exec acid-mongo1 mongosh --quiet "$(RS)" --file

.PHONY: aide demarrer arreter purger shell etat debloquer tout rollback \
        1 2 3 4 5 6 7 8

aide:
	@echo "  make demarrer   - lance les 3 noeuds et initie le replica set"
	@echo "  make 1 ... 7    - joue une demonstration (voir README)"
	@echo "  make 8          - le rollback : coupe le reseau du primaire (~30 s)"
	@echo "  make tout       - les demonstrations 1 a 7 a la suite"
	@echo "  make etat       - qui est primaire, qui est secondaire"
	@echo "  make shell      - mongosh sur le replica set"
	@echo "  make debloquer  - degele les secondaires si une demo a ete interrompue"
	@echo "  make arreter    - arrete, conserve les donnees"
	@echo "  make purger     - arrete et EFFACE les volumes"

demarrer:
	$(COMPOSE) up -d
	@docker wait acid-rs-init > /dev/null
	@docker logs acid-rs-init

1: ; @$(JOUER) /projet/scripts/01-un-document.js
2: ; @$(JOUER) /projet/scripts/02-plusieurs-documents.js
3: ; @$(JOUER) /projet/scripts/03-transaction.js
4: ; @$(JOUER) /projet/scripts/04-isolation.js
5: ; @$(JOUER) /projet/scripts/05-oplog.js
6: ; @$(JOUER) /projet/scripts/06-durabilite.js
7: ; @$(JOUER) /projet/scripts/07-base-secondaire.js
8: ; @scripts/08-rollback.sh
rollback: 8

tout: 1 2 3 4 5 6 7

etat:
	@docker exec acid-mongo1 mongosh --quiet "$(RS)" --eval \
	  'rs.status().members.forEach(m => print("  " + m.name.padEnd(14) + m.stateStr))'

shell:
	$(MONGOSH) tortues

# Une demo 6 ou 7 coupee au milieu (Ctrl-C) laisse des secondaires geles par
# fsyncLock : la replication reste arretee tant qu'on ne les libere pas.
debloquer:
	@for n in mongo1 mongo2 mongo3; do \
	  docker exec acid-$$n mongosh --quiet --file /projet/scripts/debloquer.js; \
	done

arreter:
	$(COMPOSE) down

purger:
	$(COMPOSE) down -v
