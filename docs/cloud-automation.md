# Commons build up steps 

The following guide is intended to guide you through the process of bringing up a gen3 commons. This particular guide is intended for those who would build commons independently from a centralized account. Said account will be called CSOC and is used to control multiple commons and also collect logs from them for later processing. 



# Table of contents


- [1. Requirements](#requirements)
- [2. Setting up the adminVM](#first-part-setting-up-the-adminvm)
- [3. Start gen3](#second-part-start-gen3)
- [4. Deploy Elasticsearch](#third-part-deploy-elasticsearch)
- [5. Deploy kubernetes](#fourth-part-deploy-the-kubernetes-cluster)
- [6. Bring up services in kubernetes](#fifth-part-bring-up-services-in-kubernetes)
- [7. Cleanup process](#cleanup-process)




## Requirements

To get started, you must have an AWS account ready in which you will deploy all the resources required to build up a commons. Unfortunately, the deployment may not be small enough, at least as for now, to enter into the free tier zone, therefore, costs may be involved if you decide to test this.

On the bright side, because we use terraform to deploy almost all resources, it is realtively easy to tear them all down.

In order to move on, you must have an EC2 instance up with an admin-like role attached to it. It shouldn't matter in which VPC it is or if it's behind a bastion node or not. In case you don't want to give Full admin access to an EC2 instance, then you will minimally need the following:
```
RDS
EC2
VPC
IAM
KMS
Route53
S3
CloudWatch
Lambda
CloudTrail
SNS
SQS
EKS
```

Additionally, we recommend requesting a SSL certificate for the domain you are going to use to access your commons through AWS certificate manager before moving on because you'll need it later.





## First part, setting up the adminVM

1. Clone the repo (if you have not done so already)
```bash
git clone https://github.com/Su-informatics-lab/cloud-automation.git --branch ardac
```

2. If no proxy is needed then 
```bash
export GEN3_NOPROXY='no'
```
   If a proxy is required, then gen3 would assume cloud-proxy.internal.io:3128 is your proxy for http and https. 

3. Install dependencies; you must run this part as a sudo access user.
```bash 
bash cloud-automation/gen3/bin/kube-setup-workvm.sh
```

>[!Warning]
>The above step is absolutely critical because (among other things) it creates the Gen3Secrets folder, which will be used in subsequent parts of the deployment. If you skip this step, you will need to manually create the Gen3Secrets folder.

4. kube-setup-workvm.sh adds a few required configurations to the user's local bashrc file. To be able to use them, we may want to source it, otherwise we'll have to logout and in again.
```bash
source ${HOME}/.bashrc
```

5. Confirm that the AWS CLI config file was created during the admin VM deployment. Usually said file is located in the user's home (${HOME})folder. And it should look something like:
```bash
  ubuntu@ip-172-31-40-144:~$ cat ${HOME}/.aws/config 
  [default]
  output = json
  region = us-east-1
  credential_source = Ec2InstanceMetadata
  [profile cdistest]
  output = json
  region = us-east-1
```

  It's worth noting that additional information may be required in this file but that will depend on your setup for the VM in question.





## Second part start gen3

1. Initialize the base module
```bash
gen3 workon <aws profile> <commons-name> 
```

E.g.:
```
gen3 workon ardac ardac-test
```

>[!Note]
>The third argument of the above command (ardac) refers to the profile in the AWS config file that was created during the admin VM setup. The fourth argument (ardac-test) would be the name of the commons you want to use; only lowercase letters and hyphens are permitted. Making the commmons-name unique is recommended.

2. Go to the terraform workspace folder
```bash
gen3 cd
```

3. Edit the `config.tfvars` file with your preferred text editor.

  Variables to pay attention to:

`vpc_name` Make sure the vpc_name is unique as some bucket names are derived from the vpc_name.

`vpc_cidr_block` CIDR where the commons resources would reside. E.g.: 10.138.0.0/20. As for now, only /20 subnets are supported. Your VPC must have only RFC1918 or CG NAT CIDRs.

`dictionary_url` url where the dictionary schema is; it must be in json format. E.g.: `https://dictionary.ardac.org/1.0.0/schema.json`

`portal_app` This should probably be set to `gitops`

`aws_cert_name` AWS ARN for the certificate to use on the Load Balancer that will be in front. Access to commons is strictly through HTTPS; therefore you need one. You may want request it previously this step.

`hostname` domain which the commons will respond to

>[!WARNING]
>HA squid is strongly recommended in all deployments. You can specify a single node in the cluster (example below) which is the same net effect as a single instance. The Gen3 team has mostly dropped support for the single instance squid proxy. If you do decide to use a single instance note that you will probably need to provide your own AMI.

`single_squid_instance_type` instance type for the single squid proxy. `t3a.small` is a good choice for non-production commons.

If you are deploying HA squid, you will need to set the following variables:

`deploy_ha_squid` and `deploy_single_proxy` are mutually exclusive. When one is set to true, the other should be set to false.

`ha-squid_instance_type` as with the single proxy, `t3a.small` is a good choice for non-production commons.

`ha-squid_cluster_desired_capasity` and `ha-squid_cluster_max_size` are the desired and maximum number of instances in the cluster. For non-production commons, set desired to `1` and max to `2` as a good starting point. 

`indexd_prefix` This is the prefix that will be used by Indexd for all uploads. Use `dg.ardac/` unless there is a good reason not to. Note the trailing slash.

`config_folder` folder for permissions. By default, commons would try to load a user.yaml file from s3://cdis-gen3-users/CONFIG_FOLDER/user.yaml. This bucket is not publicly accessible however you can set a different one later. Keep in mind that the folder with the name you are setting this var will need to exist within the bucket and a user.yaml file within the folder in question. You can still set permissions based on a local file. 


`google_client_secret` and `google_client_id`  Google set of API key so you can set google authentication. You can generate a new one through Google Cloud Console.

`kube_ssh_key` Replace this with the contents of the public key that was created during the admin VM setup. Should be located in the user's home folder under the name `.ssh/id_rsa.pub`.

>[!NOTE] 
>If the following variables are not in the file, just add them along with their values.

`csoc_managed` if you are going to set up your commons hooked up to a central control management account. By default it is set to true. If you leave the default value, you must run the logging module first, otherwise terraform will fail. But since this instruction is specifically for non-attached deployments, you should set the value to false.

`peering_cidr` this is the CIDR where your adminVM belongs to. Since the commons would create it's own VPC, you need to pair them up to allow communication between them later. Basically, said pairing would let you run kubectl commands against the kubernetes cluster hosting the commons.

`peering_vpc_id` VPC id from where you are running gen3 commands, must be in the same region as where you are running gen3.

`users_bucket_name` This also has something to do with the user.yaml file. In case you need your commons to access a user.yaml file in a different bucket than `cdis-gen3-users`, then add this variable with the corresponding value. Terraform with ultimately create a policy allowing the Kubernetes worker nodes to access the bucket in question (Ex. `s3://<user_bucket_name>/<config_folder>/user.yaml`).

`fence_engine_version`, `sheepdog_engine_version`, `indexd_engine_version` This must be set to a valid Postgres version supported by RDS. Default will often fail as it changes more quickly than the Gen3 code. Check the [AWS documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts.General.DBVersions) for a list of supported versions.

`fence_db_instance`, `sheepdog_db_instance`, `indexd_db_instance` EC2 instance type(s) for the databases. `db.t4g.micro` is suitable for non-production deployments. See [AWS documentation](https://aws.amazon.com/ec2/instance-types/) for a list of available instance types.

>[!NOTE] 
>If you are hooking up your commons with a centralized control management account, you may need to add additional variables to this file with more information about said account.


4. Create a terraform plan
```bash
gen3 tfplan
```
  You may want to review what will be created by terraform by going through the outputed plan.

5. Apply the previously created plan
```bash
gen3 tfapply
```

NOTE: There is sometimes an error on the first "apply" about bucket policy conflicts. Simply run `gen3 tfplan` and `gen3 tfapply` again and the process should complete successfully.

6. Copy the newly commons-test_output folder created to the user's home folder. Keep in mind that you'll see the folder if you haven't `cd` onto a different folder after running `gen3 cd`
```bash
cp -r commons-test_output/ $HOME
```

>[!WARNING]
>The squid proxy will need to be updated with two domains in the web wildcard file:
> - .ardac.org
> - .cilogon.org
>If the first entry is missing, the dictionary will not load. If the second entry is missing, the fence login will not work.

## Third part: deploy Elasticsearch

>[!NOTE] 
>In the current version, only one instance of Elasticsearch is supported per AWS account. This is due to naming, which will not be unique to a deployment. In other words, there can only be one active Gen3 deployment per account.

1. Initialize the base module
```bash
gen3 workon <aws profile> <commons-name>_es 
```

Ex:
```
gen3 workon cdistest commons-test_es
```

>[!Note]
>The third argument of the above command (cdistest) refers to the profile in the config file from step five of the admin VM setup. The fourth argument would be the name of the commons you want to use; only lowercase letters and hyphens are permitted. You must add `_es` to the name in order to invoke the ES module.

2. Go to the terraform workspace folder
```bash
gen3 cd
```

3. Edit the `config.tfvars` file with your preferred text editor.

Variables to pay attention to:

`instance_type` This is the instance type for the Elasticsearch instance. `t3.small.elasticsearch` is a good choice for non-production deployments. See [AWS documentation](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/supported-instance-types.html) for a list of available instance types.

>[!NOTE]
>Terraform requires the "*elasticsearch" name, which is not the same as the actual AWS instance types.

`instance_count` Number of instances to deploy. `1` is suitable for non-production deployments.

4. Create a terraform plan
```bash
gen3 tfplan
```
  You may want to review what will be created by terraform by going through the outputed plan.

5. Apply the previously created plan
```bash
gen3 tfapply
```
Be patient! This step will take quite a while (15-20 mins).

## Fourth part, deploy the kubernetes cluster

>[!NOTE] 
>This part of the deployment requires that you have an updated version of the aws-iam-authenticator binary. The version that is usually installed via the VM setup script(s) is tool old (0.5.0) for recent version of Kubernetes. The binary is supposed to be included in the AWS CLI, so one option is to try upgrading the client using the instructions in the AWS docs. If that does not work, the most reliable method is to simply download the binary directly from [GitHub](https://github.com/kubernetes-sigs/aws-iam-authenticator) and drop it into the `/usr/local/bin` directory. Ideally, use a symbolic link to allow you to shift versions, e.g.: `aws-iam-authenticator -> /usr/local/bin/aws-iam-authenticator_0.6.14_linux_amd64`.

1. Initialize the EKS module
```bash
gen3 workon cdistest commons-test_eks
```

  Note: The third argument of the above command (cdistest) refers to the profile in the config file from step five of the admin VM setup.
        The fourth argument would be the name of the commons you want to use; only lowercase letters and hyphens are permitted. You must add `_eks` to the name in order to invoke the EKS module.

2. Go to the terraform workspace folder
```bash
gen3 cd
```

3. Edit the `config.tfvars` file with a preferred text editor. 

  Variables to pay attention to:

`cidrs_to_route_to_gw` Comment out this line to avoid an error message when you run `gen3 tfplan`. This line is only needed if you are hooking up your commons with a centralized control management account.

`vpc_name` name of the commons it *MUST* be the same one used in part two.

`users_policy` this is the name of the policy that allows access to the user.yaml file mentioned in part two. This variable value should always be the same as the above one, but it might differ in very specific cases.

`instance_type` default set to t3.xlarge. Change if necessary.

>[!NOTE]
>Gen3 containers support the ARM64 architecture. If you want to use ARM64 instances, you must change the instance type to one that supports ARM64. See [AWS documentation](https://aws.amazon.com/ec2/instance-types/) for a list of available instance types. `t4g.2xlarge` is a good choice for non-production deployments. If you build your own custom container images then make sure that they have support for ARM64. Otherwise, `t3a.*` is a good choice for instance types.

`ec2_keyname` an existing Key Pair in EC2 for the workers for deployment. More keys can be added automatically if you specify them in $HOME/cloud-automation/files/authorized_keys/ops_team.

>[!NOTE]
>If the following variables are not in the file, just add them along with their values.

`ha_squid` Set to true if you have a high availability squid proxy (see above). Default is false.

`peering_vpc_id` VPC id from where you are running gen3 commands, must be in the same region as where you are running gen3.

`csoc_managed` same as in part 2, if you want it attached to a csoc account. Default is true.

`peering_cidr` basically the CIDR of the VPC where you are running gen3. Pretty much the same as `csoc_vpc_id` for part two.

`eks_version` You should change this to 1.23 or higher. This should (ideally) match the kubectl version installed on the admin VM. Be aware that if you set it too high you could encounter fatal errors on the EKS deployment. Be aware that this is very tricky to get right because EKS versions change rapidly, and Gen3 often struggles to keep up. See [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) for a list of available versions.

*Optional*

`sns_topic_arn` The kubernetes cluster that runs gen3 commons run a fluentd daemonset that sends logs onto CloudWatchLogGroups. If using fluentd version `v1.10.2-debian-cloudwatch-1.0` (set in the manifest), the configuration used would create new CloudWatchLogs Streams with the date as prefix, for this to work and rotate daily , a cron job must be running on the cluster that does this for us. 
                Said job would publish an SNS topic of your choice. Should you want this enable, set this variable with a valid SNS so the kubernetes workers can access the service.



4. Create a terraform plan
```bash
gen3 tfplan
```
  You may want to review what will be created by terraform by going through the outputed plan.

5. Apply the previously created plan
```bash
gen3 tfapply
```
  Again, be patient. This deployment will take about 10-15 minutes.
  
6. The EKS module creates a kubernetes configuration file (kubeconfig), copy it to the user's home folder.
```bash
cp commons-test_output_EKS/kubeconfig $HOME
```





## Fifth part, bring up services in kubernetes


1. Copy the esential files onto `Gen3Secrets` folder
```bash
cd ${HOME}/commons-test_output/
for fileName in 00configmap.yaml creds.json; do
  if [[ -f "${fileName}" && ! -f ~/Gen3Secrets ]]; then
    cp ${fileName} ~/Gen3Secrets/
    mv "${fileName}" "${fileName}.bak"
  else
    echo "Using existing ~/Gen3Secrets/${fileName}"
  fi
done
```

2. Move the kubeconfig file copied previously into Gen3Secrets
```bash
mv ${HOME}/kubeconfig ${HOME}/Gen3Secrets/
```

3. Create a manifest folder
```bash
mkdir -p ${HOME}/cdis-manifest/commons-test.planx-pla.net
```

>[!Note]
>The cdis-manifest folder is required, if you want to use your own manifest folder name you must make changes to the code, the file containing the line is `cloud-automation/gen3/lib/g3k_manifest.sh`. Moreover, a subfolder named the same as your hostname is required.

4. Create a manifest file

  With the text editor of your preference, create a new file and open it, Ex: `${HOME}/cdis-manifest/commons-test.planx-pla.net/manifest.json`.

>[!NOTE]
>  - Use the release manifest as a starting point: https://github.com/uc-cdis/cdis-manifest/tree/master/releases, but be sure to edit the scaling values as the defaults tend to be quite high (e.g. 15 replicas for presigned URLs, 5 for fence, etc.)
>  - You might need to add a configuration entry to create the ELB service:

```json
"deploy_elb": "true",
```

5. Check your `.bashrc` file to make sure it'll make gen3 work properly and source it.

The file should look something like the following at the bottom of it:
```bash
export vpc_name='commons-test'
export s3_bucket='kube-commons-test-gen3'
export KUBECONFIG=~/Gen3Secrets/kubeconfig
export GEN3_HOME=~/cloud-automation
if [ -f "${GEN3_HOME}/gen3/gen3setup.sh" ]; then
  source "${GEN3_HOME}/gen3/gen3setup.sh"
fi
alias kubectl=g3kubectl
export GEN3_NOPROXY='no'
if [[ -z "$GEN3_NOPROXY" ]]; then
  export http_proxy='http://cloud-proxy.internal.io:3128'
  export https_proxy='http://cloud-proxy.internal.io:3128'
  export no_proxy='localhost,127.0.0.1,169.254.169.254,.internal.io,logs.us-east-1.amazonaws.com,kibana.planx-pla.net'
fi
```

>[!WARNING]
>It is very important to check the first two lines, which reference the specific deployment. Be sure to check that this matches your current deployment. Edit as necessary, then source it:

```bash
source ~/.bashrc
```

6. Apply the global manifest
```bash
kubectl apply -f ~/Gen3Secrets/00configmap.yaml
```

7. Verify that kubernetes is up. After sourcing our local bashrc file we should be able to talk to kubernetes:
```bash
kubectl get nodes
```

8. Roll services
```bash
gen3 roll all
```
>[!Note]
> This process might take a few minutes to complete; let it run and monitor the output for error messages.


9. Get the newly created ELB endpoint so you can point your domain to it.
```bash
kubectl get service revproxy-service-elb -o json | jq -r .status.loadBalancer.ingress[].hostname
```

10. Go to your registrar and point the desired domain to the outcome of above command. In AWS, this is done using Route 53.

11. Enable Google logins

Use vi to edit $HOME/Gen3Secrets/apis_configs/fence-config.yaml

* Replace the empty strings for `client_id` and `client_secret`, replacing them with the correct Google Client ID and Secret.
* Remove empty list `[]` from LOGIN_OPTIONS. Uncomment the first four lines, which contain the `'Login from Google'` configuration.
* Set DEFAULT_LOGIN_IDP to `'google'` (defaults to null)

After saving your edits, run `gen3 kube-setup-fence` to redeploy Fence with the changes.

# Cleanup process

Clean up is relatively easy. Because we use terraform to build up the infrastructure, we'll also use it to destroy them all.

>[!NOTE]
>Databases have a destroy prevention flag to avoid accidental deletion, therefore if you are deliverately deleting your commons, you may need to skip the flag. Use the command below to remove the protection.

```bash
sed -i 's/prevent_destroy/#prevent_destroy/g' $HOME/cloud-automation/tf_files/aws/commons/kube.tf
```


## Destroying the kubernetes cluster

First you need to delete any resource that was not created by terraform. It will most likely be an Elastic Load balancer that was created when you ran `gen3 roll all`. 


You can view if you have a reverse proxy attached to an ELB through the following command:

```bash
kubectl get service revproxy-service-elb
```

To delete it, run the following:

```bash
kubectl delete service revproxy-service-elb
```

Now, let's delete kubernetes cluster:


```bash
gen3 workon cdistest commons-test_eks
gen3 cd
gen3 tfplan --destroy
gen3 tfapply
```

Once that destroy is done, let's delete the Elasticsearch deployment.

## Destroy the Elasticsearch deployment


```bash
gen3 workon cdistest commons-test_es
gen3 cd
gen3 tfplan --destroy
gen3 tfapply
```

Once that destroy is done, let's delete the base components.

## Destroy the base components


```bash
gen3 workon cdistest commons-test
gen3 cd
gen3 tfplan --destroy
gen3 tfapply
```

>[!NOTE]
>* Sometimes buckets created through `gen3` get populated with logs and other data. You may need to empty them before running the above commands. Otherwise, when applying the plan it might fail to delete the bucket.
>* RDS instances will sometimes complain about snapshots. In this case, probably easiest to delete them manually using the AWS web console.
>* If any destroys get stuck, try using terraform directly, as in the command below.
```
terraform destroy
```