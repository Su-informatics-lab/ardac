# Deploying Gen3 on Jetstream

## Creating a server to host Gen3
Gen3 can be deployed onto a single Jetstream VM using Helm. Instructions for creating a VM from scratch can be found in this respository: [https://github.com/alan-walsh/gen3-dev](https://github.com/alan-walsh/gen3-dev).

Once the VM is created and Minikube is started, the instructions in that repo point you to deploying Gen3 using the instructions in the [Gen3 Helm](https://github.com/uc-cdis/gen3-helm) repository. You will need a minimal configuration file to deploy Gen3, which can be found in the this repository in the `/helm/config` directory. Use the rancher-desktop-values.yaml file as a starting point for a generic Gen3 deployment or ardac-portal-values.yaml for a deployment that includes the ARDaC portal UI.

That configuration will bring up the core services in Gen3.

## Launching Guppy
To launch Guppy, you will need to add the ARDaC Helm repository to your local Helm configuration. The ARDaC Helm repository is hosted at [https://helm.ardac.org](https://helm.ardac.org).

```bash
helm repo add ardac https://helm.ardac.org
```
Before you can launch Guppy, you will need to load some metadata into Gen3. Guppy relies on Elastic indexes, which are created by the ETL process from uploaded metadata.

Step-by-step instructions for this process can be found in the documentation for Rancher desktop here: [https://github.com/Su-informatics-lab/ardac/blob/master/helm/docs/rancher-desktop.md#creating-a-program-and-project](https://github.com/Su-informatics-lab/ardac/blob/master/helm/docs/rancher-desktop.md#creating-a-program-and-project).
