# ARDaC Helm Repository

## Overview
The Gen3 team maintains the official Helm charts in their [uc-cdis/gen3-helm](https://github.com/uc-cdis/gen3-helm) GitHub repository and deploys those charts to their [https://helm.gen3.org](https://helm.gen3.org) repository.

We have forked the Gen3 repository and created our own [Su-informatics-lab/gen3-helm](https://github.com/Su-informatics-lab/gen3-helm) GitHub repository to host our custom charts.

The default branch of the forked repository is `ardac` and any changes to that branch will trigger a GitHub actions workflow which deploys the charts to the `gh-pages` branch of the same repository. The `gh-pages` branch is configured to serve the charts as a Helm repository at [https://helm.ardac.org](https://helm.ardac.org).

> [!NOTE]
> If a chart is updated in the `ardac` branch, the version number must be incremented in the `Chart.yaml` file. The version number is used to determine if a chart has changed and needs to be updated in the Helm repository. If the version number is not incremented, the GitHub actions workflow will not run and the chart will not be updated in the Helm repository.

## Usage
To use the ARDaC Helm repository, you must first add it to your local Helm configuration:
```bash
helm repo add ardac https://helm.ardac.org
```

Update your local Helm cache:
```bash
helm repo update
```

You can now search for charts in the ARDaC repository:
```bash
helm search repo ardac
```

To deploy a chart from the ARDaC repository, you must specify the repository name, e.g.:
```bash
helm upgrade --install guppy ardac/guppy -f guppy.yaml
```
