{ lib, pkgs, ... }:

{
  # Version management utilities
  versions = {
    kubectl = "1.29.13";
    python = "3.10.13";
    terraform = "1.1.3";
  };

  # Configuration values
  config = {
    awsProdSsoRole = "EKS_Access";
  };

  # Utility functions
  mkVersionedPackage = name: version: attrs:
    pkgs.${name}.overrideAttrs (oldAttrs: {
      version = version;
    } // attrs);

  # Generate AWS config sections
  mkAwsConfig = configs: lib.concatStrings (
    lib.mapAttrsToList (name: cfg: ''
      [profile ${name}]
      sso_start_url = ${cfg.sso_start_url}
      sso_region = ${cfg.sso_region}
      sso_account_id = ${cfg.sso_account_id}
      sso_role_name = ${cfg.sso_role_name}
      region = ${cfg.region}
      output = ${cfg.output}

    '') configs
  );

  # Generate kubectl context setup commands
  mkKubeContexts = clusters: lib.concatStrings (
    lib.mapAttrsToList (name: cluster: ''
      aws eks --profile "${cluster.profile}" --region "${cluster.region}" \
        update-kubeconfig --name "${cluster.name}" || true
    '') clusters
  );
}