# References

- https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
- Action required on relevant changelog, e.g. https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.14.md

## Rolling drain

- Rolling drain, terminate
  - Drain node: `k drain --ignore-daemonsets --delete-local-data --force ip-10-0-0-112.eu-west-1.compute.internal`
  - Terminate EC2 instance
  - Wait for EC2 instance ready
  - Wait for Kubernetes node ready

# Steps

- EKS + worker AMI 1.11 --> 1.12
  - Prime vars
- Kubeproxy --> 1.12.6
  - `k -n kube-system set image daemonset.apps/kube-proxy kube-proxy=602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/kube-proxy:v1.12.6`
- Kube-dns --> 1.2.2
  - `k -n kube-system set image deployment.apps/coredns coredns=602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/coredns:v1.2.2`
- CNI --> 1.5.3
  - `kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.5/config/v1.5/aws-k8s-cni.yaml`
- Rolling drain, terminate

- EKS + worker AMI 1.12 --> 1.13
  - Prime vars
- Kubeproxy --> 1.13.10
  - `k -n kube-system set image daemonset.apps/kube-proxy kube-proxy=602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/kube-proxy:v1.13.10`
- Kube-dns --> 1.2.6
  - `k -n kube-system set image deployment.apps/coredns coredns=602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/coredns:v1.2.6`
- Rolling drain, delete

```PowerShell
# Check versions
kubectl -n kube-system describe ds kube-proxy | Select-String "Image:"
kubectl -n kube-system describe deploy coredns | Select-String "Image:"
kubectl -n kube-system describe ds aws-node | Select-String "Image:"
```