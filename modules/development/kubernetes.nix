{ config, lib, pkgs, ... }:

let
  myLib = import ../../lib/default.nix { inherit lib pkgs; };
  
  awsConfigs = {
    "prod-sso" = {
      sso_start_url = "https://d-9267728a52.awsapps.com/start";
      sso_region = "us-west-2";
      sso_account_id = "873097255122";
      sso_role_name = myLib.config.awsProdSsoRole;
      region = "us-west-2";
      output = "json";
    };

    "staging-sso" = {
      sso_start_url = "https://d-9267728a52.awsapps.com/start";
      sso_region = "us-west-2";
      sso_account_id = "893894238537";
      sso_role_name = "AdministratorAccess";
      region = "us-west-2";
      output = "json";
    };

    "dev-sso" = {
      sso_start_url = "https://d-9267728a52.awsapps.com/start";
      sso_region = "us-west-2";
      sso_account_id = "361919038798";
      sso_role_name = "AdministratorAccess";
      region = "us-west-2";
      output = "json";
    };
  };

  kubeConfigs = {
    clusters = {
      "dev-us-east-1-main" = {
        profile = "dev-sso";
        region = "us-east-1";
        name = "dev-us-east-1-main";
      };
      "eks-staging" = {
        profile = "staging-sso";
        region = "us-west-2";
        name = "eks-staging";
      };
      "eks-prod" = {
        profile = "prod-sso";
        region = "us-west-2";
        name = "eks-prod";
      };
      "eks-prod-eu" = {
        profile = "prod-sso";
        region = "eu-west-1";
        name = "eks-prod-eu";
      };
    };
  };

in
{
  # System packages for Kubernetes development
  environment.systemPackages = with pkgs; [
    awscli2
    (kubectl.overrideAttrs (oldAttrs: {
      version = myLib.versions.kubectl;
      src = pkgs.fetchFromGitHub {
        owner = "kubernetes";
        repo = "kubernetes";
        rev = "v${myLib.versions.kubectl}";
        hash = "sha256-Gcj9YhK/IQEAL/O80bgzLGRMhabs7cTPKLYeUtECNZk=";
      };
    }))
    kubectx
    kubelogin
    kubernetes-helm
    kustomize
    stern
  ];

  # Export AWS configs for use in user configuration
  nixpkgs.config.kubernetes = {
    inherit awsConfigs kubeConfigs;
  };
}