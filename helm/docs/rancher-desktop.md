# Instructions for deploying gen3-helm on Rancher Desktop

## Prerequesite

* Install https://docs.rancherdesktop.io/getting-started/installation
* Once installed and started, review the Troubleshooting. Some warnings may cause problems later on
* Under Settings -> Virtual Machine Memory 16GB, 8 CPUs. During testing less memory caused the portal (webpack) build to fail

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

The elasticsearch deployment may fail with `max virtual memory areas` (as can be seen by tailing the logs per the
previous step) which will require the following steps (per
https://github.com/uc-cdis/gen3-helm/blob/master/docs/gen3_developer_environments.md#elasticsearch-error). These
steps will make this change permanent until the repo is uninstalled.
```
rdctl shell
sudo vi /etc/sysctl.conf
<go below the # comment line, press 'i' (for insert) and paste the following line with a newline at the end>
vm.max_map_count=262144
<type ':wq<enter>' to write and quit the editor>
sudo sysctl -p
exit
```

It may take 10-15 minutes for gen3 to start. Point your browser at http://localhost and bring up the Gen3 portal.
Note that you will see a browser warning about security.

## Gen3 adding locally build dependency images

❗ TBD

## Gen3 prebuild portal (webpack)

❗ TBD: DRAFT SECTION, UNTESTED / NOT COMPLETE

We can speed up building the webpack by pre-building it
(per https://github.com/uc-cdis/gen3-helm/blob/master/docs/portal/prebuild-portal.md). The downside is that
modifications of the webpack (JavaScript node frontend) require docker build & push to be run manually. Follow these
steps.

Add this to rancher-desktop-values.yaml:
```
portal:
  image:
    repository: portal
    tag: latest
```

and run:
```
git clone https://github.com/uc-cdis/gen3-helm
cd docs/portal
# portal:latest (<image_name>:<image_tag>) should match rancher-desktop-values.yaml
docker build -t portal:latest .
docker push portal:latest
```

## Gen3 uninstall

You can find the release-name in k9s.
```
helm uninstall gen3
kubectl delete pvc data-<release-name>-postgresql-0
```

## Source

This documentation was written per https://github.com/uc-cdis/gen3-helm/blob/master/docs/gen3_developer_environments.md and https://www.youtube.com/watch?v=0WCKOJtj3RM&t=385s.
