# Create EKS cluster and VPC using Terraform

You will be able to create a VPC and a EKS cluster following this example.
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

Blow is a list of resources created in this example in default region:

- a new VPC, name 'eks-tf-sample'
- a new EKS cluster, name as 'eks-tf-sample'
  - nodegroup: 3 nodes (type t3.medium) 

## Connect to cluster

Run `terraform output` to get command line to update config, sample output:
```
aws eks --region ap-southeast-1 update-kubeconfig --name eks-tf-sample
```

Run this command to update kubeconfig of your box.

## Validate

View the nodes that were created:
```
kubectl get nodes
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