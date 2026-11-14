{ lib, name, ... }:
{
  # Single bootstrap owner, like Cilium. Workload Applications belong in argo.
  services.k3s.manifests = lib.mkIf (name == "k8s-cp-01") {
    argocd.content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata = {
        name = "argocd";
        namespace = "kube-system";
      };
      spec = {
        chart = "argo-cd";
        repo = "https://argoproj.github.io/argo-helm";
        version = "10.18.0"; # Argo CD v3.6.1
        targetNamespace = "argocd";
        createNamespace = true;
        # GitOps starts after Cilium; this is not a network bootstrap chart.
        bootstrap = false;
        failurePolicy = "abort";
        timeout = "10m";
        valuesContent = ''
          global:
            nodeSelector:
              kubernetes.io/hostname: k8s-worker-02
          configs:
            cm:
              url: https://localhost:8080
          dex:
            enabled: false
          notifications:
            enabled: false
          applicationSet:
            replicas: 0
          controller:
            replicas: 1
            resources:
              requests:
                cpu: 100m
                memory: 256Mi
              limits:
                memory: 1Gi
          repoServer:
            replicas: 1
            resources:
              requests:
                cpu: 100m
                memory: 256Mi
              limits:
                memory: 1Gi
          server:
            replicas: 1
            service:
              type: ClusterIP
            ingress:
              enabled: false
            resources:
              requests:
                cpu: 50m
                memory: 128Mi
              limits:
                memory: 256Mi
          redis:
            enabled: true
            resources:
              requests:
                cpu: 50m
                memory: 64Mi
              limits:
                memory: 256Mi
          redisSecretInit:
            resources:
              requests:
                cpu: 50m
                memory: 64Mi
              limits:
                memory: 256Mi
          redis-ha:
            enabled: false
        '';
      };
    };
  };
}
