#!/bin/bash
terraform destroy -target=module.cluster.module.eks_blueprints_kubernetes_addons --auto-approve
terraform destroy -target=module.cluster.module.eks_blueprints --auto-approve
terraform destroy --auto-approve