# Instructions for deploying gen3-helm on Rancher Desktop

## Prerequesite

* Install https://docs.rancherdesktop.io/getting-started/installation
* Once installed and started, review the Troubleshooting. The warnings may cause problems later on
* Under Settings -> Virtual Machine Memory 16GB, 8 CPUs. During testing less memory than that caused webpack build to fail

## Gen3 deployment
Clone the repository and install Gen3. NOTE: A sample rancher-desktop-values.yaml file is included in the config folder of this repo.
```
helm repo add gen3 http://helm.gen3.org
helm repo update

(Optional, search repos) helm search repo gen3

helm upgrade --install dev gen3/gen3 -f rancher-desktop-values.yaml

(Optional, list installed helm charts) helm list -all-namespace
```

The project will start up, this can be monitored and logs reviewed via k9s:
```
k9s

(Optional) Select a service, container and, for example, 0 to tail the log. It is normal to see containers re-try startup as dependencies start up
```

The elasticsearch deployment may fail with `max virtual memory areas` which will require the following steps (per
https://github.com/uc-cdis/gen3-helm/blob/master/docs/gen3_developer_environments.md#elasticsearch-error). This is necessary
on each restart.
```
rdctl shell
sudo sysctl -w vm.max_map_count=262144
exit
```

Point your browser at http://localhost and bring up the Gen3 portal. Note that you will see a browser warning about security.

## Gen3 uninstall

```
helm uninstall
kubectl delete pvc data-<release-name>-postgresql-0
```

## Source

This documentation was written per https://github.com/uc-cdis/gen3-helm/blob/master/docs/gen3_developer_environments.md and https://www.youtube.com/watch?v=0WCKOJtj3RM&t=385s.
