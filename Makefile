-include srcs/.env
export

COMPOSE = docker compose -f srcs/docker-compose.yml

all:
	@mkdir -p $(DATA_PATH)/db $(DATA_PATH)/wordpress
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --volumes --remove-orphans

fclean: clean
	docker rmi -f $$(docker images -qa) 2>/dev/null || true
	sudo rm -rf $(DATA_PATH)/db $(DATA_PATH)/wordpress

re: fclean all

.PHONY: all down clean fclean re
