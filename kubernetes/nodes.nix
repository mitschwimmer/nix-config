{
  # New locally administered MACs: reserve these in DHCP before cluster rollout.
  # Keep names, MACs and machine identities stable once a guest has state.
  k8s-cp-01 = { host = "meawhite"; role = "server"; mac = "02:6b:38:00:00:01"; vsockCid = 1001; vcpu = 2; mem = 4096; stateMiB = 65536; };
  k8s-cp-02 = { host = "meawhite"; role = "server"; mac = "02:6b:38:00:00:02"; vsockCid = 1002; vcpu = 2; mem = 4096; stateMiB = 65536; };
  k8s-cp-03 = { host = "meablack"; role = "server"; mac = "02:6b:38:00:00:03"; vsockCid = 1003; vcpu = 2; mem = 4096; stateMiB = 65536; };
  k8s-worker-01 = { host = "meablack"; role = "agent"; mac = "02:6b:38:00:00:04"; vsockCid = 1004; vcpu = 4; mem = 8192; stateMiB = 65536; };
  k8s-worker-02 = { host = "meawhite"; role = "agent"; mac = "02:6b:38:00:00:05"; vsockCid = 1005; vcpu = 4; mem = 8192; stateMiB = 65536; };
  k8s-test = { host = "meawhite"; role = "test"; mac = "02:6b:38:00:00:fe"; vsockCid = 1099; vcpu = 1; mem = 1024; stateMiB = 4096; };
}
