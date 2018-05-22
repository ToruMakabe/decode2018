# de:code 2018 Sample

## Prerequisite
Place your ssh keypair ~/.ssh as id_rsa & id_rsa.pub

## Availability Zones

### Prepare Terraform variable
```
AZ/infra/region1 $ cp variables.tf.sample variables.tf
```

Edit variables as you like

### Create resources
```
AZ/infra/region1 $ terraform init
AZ/infra/region1 $ terraform plan
AZ/infra/region1 $ terraform apply
```

### Get some info
```
# get jumpbox VM public ip
$ az vm list-ip-addresses -g your-demo-az-centralus-rg -n your-jb-label-centralus

# get load balancer public ip for cross-zone scale sets
$ az network public-ip show -g your-demo-az-centralus-rg -n pip-vmss --query "{fqdn: dnsSettings.fqdn, address: ipAddress}"
```

### ssh to jumpbox and demo 1 & 2
```
$ ssh yourname@jumpbox-public-ip

# demo 1 (cross-zone scale sets)
$ while true; do curl yourvmss01.centralus.cloudapp.azure.com; sleep 3; done

# demo 2 (check latency)
$ ping vmss-node-private-ip
```

### Delete resources
```
AZ/infra/region1 $ terraform destroy
```

### (if you will do demo on the other region, change the region directory and repeat the proc again)

## Accelerated Networking

### Prepare Terraform variable
```
Accel_Net/infra $ cp variables.tf.sample variables.tf
```

Edit variables as you like

### Create resources
```
Accel_Net/infra $ terraform init
Accel_Net/infra $ terraform plan
Accel_Net/infra $ terraform apply
```

### Get VMs ip
```
$ az vm list-ip-addresses -g your-demo-accelnet-rg --query "[].{Name: virtualMachine.name,  PublicIP:virtualMachine.network.publicIpAddresses[0].ipAddress, PrivateIP:virtualMachine.network.privateIpAddresses[0]}"
```

### Setup iperf server on same region (another ssh session)
```
$ ssh yourname@vm01-1-public-ip
$ iperf -s
```

### Setup iperf server on the other region (another ssh session)
```
$ ssh yourname@vm02-public-ip
$ iperf -s
```

### ssh to iperf client and demo 1 & 2 (another ssh session)
```
$ ssh yourname@vm01-0-public-ip

# iperf to same region VM
$ iperf -c vm01-1-private-ip -P 8 -t 3

# iperf to the other region VM
$ iperf -c vm02-private-ip -P 8 -t 3
```

### Delete resources
```
Accel_Net/infra $ terraform destroy
```

## (Extra) Azure Resource Manager Template Deployment with Terraform RP

* ARM Template & parameters file under Terraform_RP
  * Deploy AKS Cluster
  * Deploy Azure Log Analytics ContainerInsights solution
  * Register Microsoft.TerraformOSS kubernetes provider
  * Deploy NGINX container to AKS as kubernetes pod

```
Terraform_RP $ sample.azuredeploy.parameters.json azuredeploy.parameters.json
```

Edit parameters as you like

### Deploy
```
Terraform_RP $ az group create -n your-demo-tf-aks -l eastus
Terraform_RP $ az group deployment create -g your-demo-tf-aks --template-file azuredeploy.json --parameters azuredeploy.parameters.json