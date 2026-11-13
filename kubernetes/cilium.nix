{ lib, name, ... }:
{
  # One server owns the HelmChart resource. The Cilium DaemonSet will
  # automatically extend to the remaining nodes when they join K3s.
  services.k3s.manifests = lib.mkIf (name == "k8s-cp-01") {
    cilium.content = {
      apiVersion = "helm.cattle.io/v1";
      kind = "HelmChart";
      metadata = {
        name = "cilium";
        namespace = "kube-system";
      };
      spec = {
        chart = "cilium";
        repo = "https://helm.cilium.io";
        version = "1.20.4";
        targetNamespace = "kube-system";
        bootstrap = true;
        failurePolicy = "abort";
        timeout = "10m";
        valuesContent = ''
          kubeProxyReplacement: true
          k8sServiceHost: 192.168.1.103
          k8sServicePort: 6443
          routingMode: native
          autoDirectNodeRoutes: true
          ipv4NativeRoutingCIDR: 10.42.0.0/16
          ipam:
            mode: kubernetes
          k8s:
            requireIPv4PodCIDR: true
          cni:
            binPath: /var/lib/rancher/k3s/data/cni
            confPath: /var/lib/rancher/k3s/agent/etc/cni/net.d
          operator:
            replicas: 1
        '';
      };
    };
  };
}
