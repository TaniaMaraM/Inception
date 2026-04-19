-include srcs/.env
export

COMPOSE = docker compose -f srcs/docker-compose.yml

all:
	@mkdir -p /home/$(LOGIN)/data/db /home/$(LOGIN)/data/wordpress
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --volumes --remove-orphans

fclean: clean
	docker rmi -f $$(docker images -qa) 2>/dev/null || true
	sudo rm -rf /home/$(LOGIN)/data/db /home/$(LOGIN)/data/wordpress

re: fclean all

.PHONY: all down clean fclean re
