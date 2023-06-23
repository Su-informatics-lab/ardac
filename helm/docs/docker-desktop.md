# Instructions for deploying gen3-helm on Docker Desktop
Docker Desktop now includes support for Kubernetes (single node). As such, it is very easy to get Gen3 deployed using Helm with some additional configuration as described here.

It is assumed that you already have a working deployment of Docker Desktop with Kubernetes enabled. For additional information see: https://docs.docker.com/desktop/kubernetes/

## Part 1: Gen3 deployment
Clone the repository and install Gen3 per the instructions: https://github.com/uc-cdis/gen3-helm

NOTE: A sample docker-desktop-values.yaml file is included in the config folder of this repo.
```
helm upgrade --install gen3 gen3/gen3 -f .\docker-desktop-values.yaml
```

## Part 2: Ingress
The gen3-helm deployment is specifically intended to be installed in a Rancher Desktop environment. The "dev" deployment includes an ingress that is designed to work in this environment, but will not work for Docker Desktop. You can avoid installing this ingress by setting `dev: false` but doing so will also skip the deployment of both PostgreSQL and Elastic.

Instead, begin by deleting the default ingress:
```
kubectl delete ingress revproxy-dev
```
Next, you will have to install an ingress controller:
```
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
```
Now you can create an ingress for Gen3:
```
kubectl create ingress gen3-local --class=nginx --rule="localhost/*=revproxy-service:80"
```
At this point you should be able to point your browser at http://localhost and bring up the Gen3 portal. Note that you will see a browser warning about security.