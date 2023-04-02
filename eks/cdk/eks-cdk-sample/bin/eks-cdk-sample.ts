#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import * as blueprints from '@aws-quickstart/eks-blueprints';

const app = new cdk.App();
const account = process.env.CDK_DEFAULT_ACCOUNT;
const region = process.env.CDK_DEFAULT_REGION;

const addOns: Array<blueprints.ClusterAddOn> = [
  // new blueprints.addons.ArgoCDAddOn(),
  // new blueprints.addons.CalicoOperatorAddOn(),
  // new blueprints.addons.MetricsServerAddOn(),
  // new blueprints.addons.ClusterAutoScalerAddOn(),
  new blueprints.addons.AwsLoadBalancerControllerAddOn(),
  new blueprints.addons.VpcCniAddOn(),
  new blueprints.addons.CoreDnsAddOn(),
  new blueprints.addons.KubeProxyAddOn()
];

const stack = blueprints.EksBlueprint.builder()
  .account(account)
  .region(region)
  .addOns(...addOns)
  .useDefaultSecretEncryption(true) // set to false to turn secret encryption off (non-production/demo cases)
  .build(app, 'eks-blueprint');