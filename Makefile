.PHONY: deploy teardown

deploy:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/secrets.yaml
	kubectl apply -f k8s/pvc.yaml
	kubectl apply -f k8s/deploy.yaml
	kubectl apply -f k8s/ingress.yaml

teardown:
	kubectl delete -f k8s/ingress.yaml --ignore-not-found
	kubectl delete -f k8s/deploy.yaml --ignore-not-found
	kubectl delete -f k8s/pvc.yaml --ignore-not-found
	kubectl delete -f k8s/secrets.yaml --ignore-not-found
	kubectl delete -f k8s/namespace.yaml --ignore-not-found
