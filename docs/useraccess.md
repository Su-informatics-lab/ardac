# User Access Management in Gen3

Access to Gen3 is controlled by Fence and Arborist. These files read user data out of the Postgres database. That database is updated via a batch job that reads a YAML file out of an S3 bucket and applies the configuration to the database.

Log on the the admin VM for the specific deployment.
Change to the /Gen3Secrets/apis_configs directory.

```bash
cd /Gen3Secrets/apis_configs
```

Copy the user.yaml file using today’s date as a suffix, e.g.: user.yaml.20250428. This is a backup in case something goes wrong.

```bash
cp user.yaml user.yaml.20250428
```    

Edit the user.yaml file to adjust user access. See https://github.com/uc-cdis/fence/blob/master/docs/additional_documentation/user.yaml_guide.md for details.

Validate the file

```bash
gen3users validate user.yaml
```

Upload the file to the correct S3 location:

PORTAL
```bash
aws s3 cp user.yaml s3://cdis-state-ac742378880825-gen3/config/user.yaml
```

DEMO
```bash
aws s3 cp user.yaml s3://cdis-state-ac613495871066-gen3/config/user.yaml
```
Run the job:
```bash
gen3 runjob usersync
```
Reference: https://github.com/uc-cdis/cloud-automation/blob/master/kube/services/jobs/README.md#usersync-job

Check the logs to make sure that it ran successfully.
