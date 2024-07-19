# Workspaces

In environments deployed via cloud-automation, workspaces will probably not be working out of the box. The team at NIEHS documented all of their notes about issues and fixes for cloud-automation, including workspaces, in a PDF that can be found in Teams. Below is a short summary of the workspaces issues and steps to resolve.

## K8s storage class
The primary issue is related to having multiple `default` storage classes. This can cause issues with workspaces. To verify if this is the issue, run the following command:

```bash
kubectl get storageclass
```

The results will look like this:

```bash
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2 (default)        kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  123d
prometheus           kubernetes.io/aws-ebs   Retain          Immediate              false                  123d
standard (default)   kubernetes.io/aws-ebs   Retain          Immediate              false                  123d
```

To resolve this, you can delete the `default` storage class that is not being used. To do this, run the following command:

```bash
kubectl delete storageclass standard
```

## Cluster autoscaler
The second issue is that workspaces run in a separate autoscaling group with 0 nodes by default. This minimizes costs while nobody is using workspaces, but it also means that you must enable the Kubernetes cluster autoscaler (CAS) to add nodes when workspaces are in use.

>[!NOTE]
>Not having an autoscaler enabled could also cause issues with Gen3 services.

To verify if the cluster autoscaler is enabled, run the following command:

```bash
kubectl get pods -n kube-system | grep cluster-autoscaler
```

If you do not find a pod running, then the cluster autoscaler is not enabled.

Full documentation on the cluster autoscaler can be found here: https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws. But that would require a lot of work to craft the full set of YAML.

The good news is that the Gen3 team created a handy script that will do all the work for you:

```bash
gen3 kube-setup-autoscaler
```

The bad news is that this script has not been kept up to date. Specifically, there is a case statement to identify the version of Kubernetes, and at time of writing this only went up to version `1.22+`.

Which leaves two options:
1. Edit the script to include the version of Kubernetes that you are using, e.g. `1.28+`.
2. Manually apply the YAML file that the script would have applied, which you can find in `${GEN3_HOME}/kube/services/autoscaler/cluster-autoscaler-autodiscover.yaml`.

Option 2 is probably easier. It should be as simple as replacing the two variables in the deployment section of the YAML. There is one variable for the autoscaler version (`CAS_VERSION`), and one for the cluster name (`VPC_NAME`). Make a copy of the YAML template and then replace those variable names with the actual values and then apply the YAML.

```bash
kubectl apply -f ./cluster-autoscaler-autodiscover.yaml
```

>[!NOTE]
>Gen3 now has support for [Karpenter](https://karpenter.sh/), which is a much better solution for autoscaling. See this document for more details: https://github.com/uc-cdis/cloud-automation/blob/master/doc/karpenter.md.

## Timeout
By default workspaces will run until the user terminates their workspace. This can lead to unexpected expenses because even a single workspace will require the autoscaler to provision a node. There is a setting that can be added to the workspace configuration in the `manifest.json` file that is used to deploy the environment. Add the `"--NotebookApp.shutdown_no_activity_timeout=5400"` argument to the `args` section of the container configuration. For example, this config will cause the workspace to shut down after 90 minutes (5400s) of inactivity:

```json
"containers": [
      {
        "target-port": 8888,
        "cpu-limit": "0.8",
        "memory-limit": "1.5Gi",
        "name": "Brain - Python/R/Freesurfer",
        "image": "quay.io/cdis/jupyterbrain:1.1",
        "env": {

        },
        "args": [
          "--NotebookApp.base_url=/lw-workspace/proxy/",
          "--NotebookApp.shutdown_no_activity_timeout=5400"
          "--NotebookApp.password=''",
          "--NotebookApp.token=''"
        ],
        "command": [
          "start-notebook.sh"
          ...
```
