# Create EKS cluster and VPC using Terraform

Create EKS cluster with one click install. Resources that will be created:

- a new VPC, name 'eks-tf-sample', same as current directory name
  - in your default region
  - CIDR "10.0.0.0/16"
  - 2 AZ
- a new EKS cluster, name as 'eks-tf-sample'
  - version 1.25
  - 1 managed nodegroup: 3 nodes (type m5.large) private subnet
    - disk size 100G
  - EKS addons: CoreDNS, kube-proxy, VPC CNI
  - K8s addons: AWS Load Balancer Controller
  - KMS enabled

## Prerequistes

Ensure you have following tools installed locally:

- aws cli
- kubectl
- terraform

## Deploy

Init terraform and view resources that will be created:
```
terraform init
terraform plan
```

To provision this example:
```
terraform apply -auto-approve
```



## Connect to cluster

Run `terraform output` to get command line to update config, sample output:
```
aws eks --region <REGION_ID> update-kubeconfig --name eks-tf-sample
```

Run this command to update kubeconfig of your box.

## Validate

View the nodes that were created:
```
kubectl get nodes
```

## Cleanup

1. Delete all workloads in cluster, then run following commands:

```
# To delete general add-ons, run the following command:
terraform destroy -target=module.cluster.module.eks_blueprints_kubernetes_addons --auto-approve
terraform destroy -target=module.cluster.module.eks_blueprints --auto-approve
terraform destroy --auto-approve
```

## Notes

New resource names for vpc and EKS cluster will same as the name of current directory. In this example, they will be 'eks-tf-sample'. If you want to have different names, you have two choices:

Copy *.tf files to a new directory and renamed it, for example 'test-env'

Or 

you can update name in [locals.tf], change this line
```
name            = basename(path.cwd)
```

to something like below:
```
name            = "test-env"
```


## References

Workshop: [EKS Blueprints for Terraform](https://catalog.workshops.aws/eks-blueprints-terraform/en-US)

Github: [terraform-aws-eks-blueprints
](https://github.com/aws-ia/terraform-aws-eks-blueprints)