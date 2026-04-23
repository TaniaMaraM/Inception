-include srcs/.env
export

NAME    = inception
COMPOSE = docker compose -f srcs/docker-compose.yml -p $(NAME)

all:
	@mkdir -p $(DATA_PATH)/db $(DATA_PATH)/wordpress
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

restart: down all

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down --volumes --remove-orphans

fclean: clean
	docker rmi -f $$(docker images -qa) 2>/dev/null || true
	docker volume rm $$(docker volume ls -q) 2>/dev/null || true
	docker network rm $$(docker network ls -q) 2>/dev/null || true
	sudo rm -rf $(DATA_PATH)/db $(DATA_PATH)/wordpress

re: fclean all

db:
	docker exec -it inception-mariadb-1 mariadb -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE)

eval:
	docker stop $$(docker ps -qa) 2>/dev/null || true
	docker rm $$(docker ps -qa) 2>/dev/null || true
	docker rmi -f $$(docker images -qa) 2>/dev/null || true
	docker volume rm $$(docker volume ls -q) 2>/dev/null || true
	docker network rm $$(docker network ls -q) 2>/dev/null || true

.PHONY: all down restart logs ps clean fclean re eval db
