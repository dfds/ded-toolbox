# How to

## traefik-report.ps1

Generate backend request report for last 7 days - require port-forward to Prometheus server on localhost port 9090

Port forwarding:
```shell
 kubectl -n monitoring port-forward prometheus-server-{instance id} 9090
```

Running the `traefik-report.ps1` command will result in a traefik_requests.csv file listing the trafic in the given Kubernetes cluster.
