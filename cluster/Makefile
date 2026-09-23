# Le replica set et le sharded cluster de la section « Shard et configuration ».
# Aucun ne publie de port : ils tournent a cote du conteneur mongodb du cours.

RS    = docker compose -f replica-set/docker-compose.yml
SH    = docker compose -f sharded-cluster/docker-compose.yml
# $(call jouer,<compose>,<service>,<script>) : mongosh dans le conteneur
jouer = $(1) exec -T $(2) mongosh --quiet --eval "$$(cat scripts/$(3))"
# $(call attendre,<compose>,<service>) : attend que le mongod reponde
attendre = until $(1) exec -T $(2) mongosh --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; do sleep 1; done

.PHONY: aide rs rs-etat rs-election rs-retour rs-majorite rs-reparer rs-arreter \
        shard shard-demo shard-arreter

aide:
	@echo "  make rs            - lance les 3 mongod, rs.initiate, affiche PRIMARY / SECONDARY"
	@echo "  make rs-etat       - qui est primaire, qui est secondaire"
	@echo "  make rs-election   - arrete mongo1 : mongo2 ou mongo3 est elu"
	@echo "  make rs-retour     - relance mongo1 : il rattrape, puis reprend la main"
	@echo "  make rs-majorite   - arrete mongo2 et mongo3 : mongo1 seul refuse d'ecrire"
	@echo "  make rs-reparer    - relance les trois noeuds, attend mongo1 primaire"
	@echo "  make rs-arreter    - arrete et efface le replica set"
	@echo "  make shard         - lance le cluster, 3 rs.initiate, 2 sh.addShard"
	@echo "  make shard-demo    - 1000 tortues reparties, requete ciblee / diffusee"
	@echo "  make shard-arreter - arrete et efface le sharded cluster"

# --- le replica set ---------------------------------------------------------
rs:
	$(RS) up -d
	@$(call attendre,$(RS),mongo1)
	@$(call attendre,$(RS),mongo2)
	@$(call attendre,$(RS),mongo3)
	@$(call jouer,$(RS),mongo1,rs-initiate.js)
	@$(call jouer,$(RS),mongo1,rs-attendre.js)
	@$(call jouer,$(RS),mongo1,rs-etat.js)

rs-etat:
	@$(call jouer,$(RS),mongo1,rs-etat.js)

# Slide « Le replica set - l'election » : mongo1 tombe, on interroge mongo2.
rs-election:
	@echo "docker stop mongo1, puis sur mongo2, quinze secondes plus tard :"
	@docker stop mongo1 >/dev/null
	@sleep 15
	@$(call jouer,$(RS),mongo2,rs-etat.js)

# Slide « Le replica set - le retour de mongo1 »
rs-retour:
	@echo "docker start mongo1 : il rattrape l'oplog, puis sa priority: 2 le rend primaire"
	@docker start mongo1 >/dev/null
	@$(call attendre,$(RS),mongo1)
	@$(call jouer,$(RS),mongo1,rs-attendre.js)
	@$(call jouer,$(RS),mongo1,rs-etat.js)

rs-majorite:
	docker stop mongo2 mongo3
	@sleep 15
	@$(call jouer,$(RS),mongo1,rs-etat.js)
	@$(call jouer,$(RS),mongo1,rs-ecrire.js)

rs-reparer:
	$(RS) start mongo1 mongo2 mongo3
	@$(call attendre,$(RS),mongo1)
	@$(call jouer,$(RS),mongo1,rs-attendre.js)
	@$(call jouer,$(RS),mongo1,rs-etat.js)

rs-arreter:
	$(RS) down -v

# --- le sharded cluster -----------------------------------------------------
shard:
	$(SH) up -d
	@$(call attendre,$(SH),config1)
	@$(call attendre,$(SH),shard1)
	@$(call attendre,$(SH),shard2)
	@$(call jouer,$(SH),config1,cfg-initiate.js)
	@$(call jouer,$(SH),shard1,sh1-initiate.js)
	@$(call jouer,$(SH),shard2,sh2-initiate.js)
	@$(call jouer,$(SH),config1,attendre-primaire.js)
	@$(call jouer,$(SH),shard1,attendre-primaire.js)
	@$(call jouer,$(SH),shard2,attendre-primaire.js)
	@$(call jouer,$(SH),mongos,add-shard.js)

shard-demo:
	@$(call jouer,$(SH),mongos,shard-demo.js)

shard-arreter:
	$(SH) down -v
