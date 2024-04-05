# Elastic deployment

Gen3 requires an Elastic cluster and in "dev" mode, it is deployed as a single-node cluster by the umbrella gen3 chart. You can also deploy it independently using the official Elastic Helm chart. A sample yaml file is provided in the config folder.

To deploy the chart:
    
    ```bash
    helm repo add elastic https://helm.elastic.co
    helm repo update
    helm upgrade --install gen3-elastic elastic/elasticsearch --version 7.17.3 -f elastic.yaml
    ```

To check the status of the deployment:

    ```bash
    kubectl get pods
    ```

You should find a single pod called `gen3-elasticsearch-master-0` running. This is your single-node Elastic cluster.

