# Le replica set et le sharded cluster de la section « Shard et configuration ».
# Les deux publient le port 27017 : un seul a la fois.

RS    = docker compose -f replica-set/docker-compose.yml
SH    = docker compose -f sharded-cluster/docker-compose.yml
# $(call jouer,<compose>,<service>,<script>) : mongosh dans le conteneur
jouer = $(1) exec -T $(2) mongosh --quiet --eval "$$(cat scripts/$(3))"
# $(call attendre,<compose>,<service>) : attend que le mongod reponde
attendre = until $(1) exec -T $(2) mongosh --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; do sleep 1; done

.PHONY: aide rs rs-etat rs-election rs-majorite rs-reparer rs-arreter \
        shard shard-demo shard-arreter

aide:
	@echo "  make rs            - lance les 3 mongod, rs.initiate, affiche PRIMARY / SECONDARY"
	@echo "  make rs-etat       - qui est primaire, qui est secondaire"
	@echo "  make rs-election   - arrete mongo1 : un autre est elu"
	@echo "  make rs-majorite   - arrete mongo2 et mongo3 : mongo1 seul refuse d'ecrire"
	@echo "  make rs-reparer    - relance les trois noeuds"
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

# Arrete le primaire du moment (mongo1 sur la slide, mais l'election peut en
# avoir choisi un autre), puis interroge un noeud reste debout.
rs-election:
	@p=$$($(RS) exec -T mongo1 mongosh --quiet --eval 'db.hello().primary.split(":")[0]'); \
	 autre=$$(for n in mongo1 mongo2 mongo3; do [ $$n != $$p ] && echo $$n && break; done); \
	 echo "docker stop $$p, puis sur $$autre :"; \
	 $(RS) stop $$p 2>/dev/null; sleep 15; \
	 $(RS) exec -T $$autre mongosh --quiet --eval "$$(cat scripts/rs-etat.js)"

rs-majorite:
	$(RS) stop mongo2 mongo3
	@sleep 15
	@$(call jouer,$(RS),mongo1,rs-etat.js)
	@$(call jouer,$(RS),mongo1,rs-ecrire.js)

rs-reparer:
	$(RS) start mongo1 mongo2 mongo3

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
