# Bootstrap a EKS cluster with CDK

## Prerequiste

- make
- NodeJS v18.15.0

## Install CDK and eks-blueprints package

Install [AWS CDK Toolkit](https://www.npmjs.com/package/aws-cdk) with below commands:

```
npm install -g aws-cdk@2.72.0
```

## Configure environment and bootstrap

Set environment variables, replace them with your account id and region:
```
export CDK_DEFAULT_ACCOUNT=1234567890
export CDK_DEFAULT_REGION=ap-southeast-1
cdk bootstrap
```

Note: if the account/region combination used is different from the initial combination used with cdk bootstrap, you will need to perform cdk bootstrap again to avoid error.


## Create a EKS cluster

```
cdk deploy
```

## Issues

### Root user not properly authorized

Root user access EKS web console will get below error message: 

`Your current user or role does not have access to Kubernetes objects on this EKS cluster
This may be due to the current user or role not having Kubernetes RBAC permissions to describe cluster resources or not having an entry in the cluster’s auth config map.`

Run kubecconfig update command will get assumerole fail message
```
➜  eks-cdk-sample git:(main) ✗ aws eks update-kubeconfig --name east-test-1 --region us-east-1 --role-arn <ROLE_ARN>
(success message)
➜  eks-cdk-sample git:(main) ✗ kubectl get ns
An error occurred (AccessDenied) when calling the AssumeRole operation: Roles may not be assumed by root accounts.
```

## Destroy stack

```
cdk destroy
```


## References

[https://aws-quickstart.github.io/cdk-eks-blueprints/getting-started/](https://aws-quickstart.github.io/cdk-eks-blueprints/getting-started/)

[https://aws.amazon.com/blogs/containers/bootstrapping-clusters-with-eks-blueprints/](https://aws.amazon.com/blogs/containers/bootstrapping-clusters-with-eks-blueprints/)