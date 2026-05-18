.PHONY: deploy teardown

deploy:
	kubectl apply -k k8s/

teardown:
	kubectl delete -k k8s/ --ignore-not-found
