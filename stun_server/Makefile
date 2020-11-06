version = 0.1.2

.PHONY: deploy
deploy: build-docker push-docker

.PHONY: build-docker
build-docker:
	docker build -t ahovgaard/stun-server:$(version) -f Dockerfile .

.PHONY: push-docker
push-docker:
	docker push ahovgaard/stun-server:$(version)
