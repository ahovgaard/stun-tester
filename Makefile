.PHONY: build-stun-client
build-stun-client:
	cd stun_client && docker build -t stun-client:latest -f Dockerfile .

.PHONY: build-stun-server
build-stun-server:
	cd stun_server && docker build -t stun-server:latest -f Dockerfile .

.PHONY: push-stun-client
push-stun-client:
	$(eval VERSION := $(shell grep "version" ./stun_client/mix.exs | cut -d '"' -f 2))
	docker tag stun-client:latest ahovgaard/stun-client:$(VERSION)
	docker push ahovgaard/stun-client:$(VERSION)

.PHONY: push-stun-server
push-stun-server:
	$(eval VERSION := $(shell grep "version" ./stun_server/mix.exs | cut -d '"' -f 2))
	docker tag stun-server:latest ahovgaard/stun-server:$(VERSION)
	docker push ahovgaard/stun-server:$(VERSION)
