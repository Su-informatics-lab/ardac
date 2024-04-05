# PostgreSQL deployment in Helm

Gen3 requires a PostgreSQL database and in "dev" mode, it is deployed by the umbrella gen3 chart. You can also deploy it independently using the same Bitnami Helm chart. A sample yaml file is provided in the config folder.

> [!NOTE]
> Pay careful attention to the chart version for PostgreSQL. Gen3 scripts, specifically the DB setup scripts used by most microservices, may not function correctly with PostgrSQL version `15.0` or later. The version used in the Gen3 Helm chart is `11.9.13`, which corresponds to PostgreSQL version `14.5.0`. 

To deploy the chart:

    ```bash
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    helm upgrade --install gen3-postgres bitnami/postgresql --version 11.9.13 -f postgres.yaml
    ```

To check the status of the deployment:

    ```bash
    kubectl get pods
    ```

You should find a single pod called `gen3-postgres-0` running. This is your PostgreSQL database.

