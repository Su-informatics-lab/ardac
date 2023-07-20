# Instructions for deploying gen3-helm on Rancher Desktop

## Prerequesite

* Install https://docs.rancherdesktop.io/getting-started/installation
* Once installed and started, review the Troubleshooting. Some warnings may cause problems later on
* Under Settings -> Virtual Machine Memory 16GB, 8 CPUs. During testing less memory caused the portal (webpack) build to fail

## Gen3 deployment
Clone the repository and install Gen3. A sample rancher-desktop-values.yaml file is included in the config folder of
this repo. It includes a locally build data-portal (windmill). A similar pattern is applicable for other services.
```
helm repo add gen3 http://helm.gen3.org
helm repo update

(Optional, search repos) helm search repo gen3

git clone https://github.com/jing-su/ardac.git
git clone https://github.com/jing-su/data-portal.git
docker build -t windmill data-portal/.
helm upgrade --install dev gen3/gen3 -f ardac/helm/config/rancher-desktop-values.yaml
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

## Gen3 restarting
Shut down and start up rancher will stop and start the dev deployment per the above instructions. Unfortunately 
elasticsearch will fail with the above error even though we persisted it. Follow these steps to bring it back:
```
rdctl shell
sudo sysctl -p
exit
```

## Gen3 uninstall

The persistent database needs to be uninstalled via a seperate command.
```
helm uninstall dev
kubectl delete pvc data-dev-postgresql-0
```

## Sources

* Basic setup: https://github.com/uc-cdis/gen3-helm/blob/master/docs/gen3_developer_environments.md, https://www.youtube.com/watch?v=0WCKOJtj3RM&t=385s.
* Postgres persistence: https://github.com/uc-cdis/gen3-helm/blob/b800bffcc6deeed6cef002d4e7f2c1ee0bcfe62b/docs/PREREQUISITES.md?plain=1#L40
* Custom image: https://github.com/uc-cdis/data-portal/blob/master/docs/quickstart_helm.md
* Prebuild portal (webpack) for faster startup: https://github.com/uc-cdis/gen3-helm/blob/b800bffcc6deeed6cef002d4e7f2c1ee0bcfe62b/docs/portal/prebuild-portal.md
  * Skipped, it didn't work per the following error
  * ❗docker build fails with getaddrinfo ENOTFOUND revproxy-service even though it is running per above
