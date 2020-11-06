version = 0.1.7

.PHONY: deploy
deploy: build-docker push-docker

.PHONY: build-docker
build-docker:
	docker build -t ahovgaard/stun-client:$(version) -f Dockerfile .

.PHONY: push-docker
push-docker:
	docker push ahovgaard/stun-client:$(version)
