from kubernetes.client.api.apps_v1_api import AppsV1Api
from kubernetes.client.api.batch_v1_api import BatchV1Api
from kubernetes.client.models.v1_pod import V1Pod
from kubernetes.client.models.v1_resource_requirements import V1ResourceRequirements
from kubernetes.client.models.v1_replica_set import V1ReplicaSet
from kubernetes.client.models.v1_job import V1Job
from src.kubernetes.limit_range_violations import Violations


class PodResource:
    """Fetch all relevant data for analysing pod resources in terms of limitranges."""

    def __init__(
        self, apps_client: AppsV1Api, batch_client: BatchV1Api, pod_item: V1Pod
    ) -> None:
        self.apps_client: AppsV1Api = apps_client
        self.batch_client: BatchV1Api = batch_client
        self.__pod_item: V1Pod = pod_item
        self.name: str = pod_item.metadata.name
        self.namespace: str = pod_item.metadata.namespace
        self.__pod_owner_name: str = pod_item.metadata.owner_references[0].name
        self.__pod_owner_kind: str = pod_item.metadata.owner_references[0].kind
        self.resources: list[V1ResourceRequirements] = self.__get_resource()
        self.number_of_containers: int = len(self.__pod_item.spec.containers)
        self.__get_resources_by_type()
        self.violations: list[str] = []

    def __get_resource(self) -> list[V1ResourceRequirements]:
        """Get resources object per container from Pod object."""
        container_resources: list[V1ResourceRequirements] = []
        for container in self.__pod_item.spec.containers:
            container_resources.append(container.resources)
        return container_resources

    def __get_resources_by_type(self) -> None:
        """
        Get resources both requests and limits
        and assign them as attributes list[float] to the object.
        """
        requests_cpu: list[float] = []
        requests_memory: list[float] = []
        limits_cpu: list[float] = []
        limits_memory: list[float] = []
        for resources in self.resources:
            if resources.requests is None:
                requests_cpu.append(0)
                requests_memory.append(0)
            else:
                requests_cpu.append(
                    self.__convert_cpu(resources.requests.get("cpu", "0"))
                )
                requests_memory.append(
                    self.__convert_memory(resources.requests.get("memory", "0"))
                )
            if resources.limits is None:
                limits_cpu.append(0)
                limits_memory.append(0)
            else:
                limits_cpu.append(self.__convert_cpu(resources.limits.get("cpu", "0")))
                limits_memory.append(
                    self.__convert_memory(resources.limits.get("memory", "0"))
                )
        self.requests_cpu: list[float] = requests_cpu
        self.requests_memory: list[float] = requests_memory
        self.limits_cpu: list[float] = limits_cpu
        self.limits_memory: list[float] = limits_memory

    def __convert_cpu(self, cpu: str) -> float:
        """Converts resource CPU string to float in units of cores."""
        if "m" in cpu:
            return float(cpu[:-1]) / 1000
        return float(cpu)

    def __convert_memory(self, memory: str) -> float:
        """Converts resource memory string to float in units of Mi (megabytes)."""
        if "Mi" in memory:
            return float(memory[:-2])
        elif "Gi" in memory:
            return float(memory[:-2]) * 1024
        elif "m" in memory:
            return float(memory[:-1]) / 1000 / 1024 ** 2
        return float(memory)

    def __get_pod_owner_by_owner_reference_kind(self) -> tuple[str, str]:
        """Get pods owner name and kind by owner reference kind."""
        owner_name: str = ""
        owner_kind: str = ""
        if self.__pod_owner_kind == "ReplicaSet":
            replicaset: V1ReplicaSet = self.apps_client.read_namespaced_replica_set(
                self.__pod_owner_name, self.namespace
            )
            owner_name = replicaset.metadata.owner_references[0].name
            owner_kind = replicaset.metadata.owner_references[0].kind
        elif self.__pod_owner_kind == "Job":
            job: V1Job = self.batch_client.read_namespaced_job(
                self.__pod_owner_name, self.namespace
            )
            owner_name = job.metadata.owner_references[0].name
            owner_kind = job.metadata.owner_references[0].kind
        return owner_name, owner_kind

    def get_pod_owner_kind_from_owner_reference(self) -> None:
        """Get pods owner name and kind."""
        (
            self.owner_name,
            self.owner_kind,
        ) = self.__get_pod_owner_by_owner_reference_kind()

    def __violation_pod_has_containers_with_resources_none(self) -> None:
        """Append violation if missing requests or limits on container resources."""
        resources: list[float] = (
            self.requests_cpu
            + self.requests_memory
            + self.limits_cpu
            + self.limits_memory
        )
        if 0 in resources:
            self.violations.append(Violations.NONE_RESOURCES.value)

    def __violation_pod_has_containers_with_high_cpu_resources(self) -> None:
        """Append violation if container has high requests or cpu limits defined."""
        resources: list[float] = self.requests_cpu + self.limits_cpu
        for resource in resources:
            if resource > 1:
                self.violations.append(Violations.HIGH_RESOURCES_CPU_CONTAINER.value)

    def __violation_pod_has_high_cpu_resources(self) -> None:
        """Append violation if pod (total) has high requests or cpu limits defined."""
        if sum(self.requests_cpu) > 1 or sum(self.limits_cpu) > 1:
            self.violations.append(Violations.HIGH_RESOURCES_CPU_POD.value)

    def __violation_pod_has_containers_with_high_memory_resources(self) -> None:
        """Append violation if container has high requests or memory limits defined."""
        resources: list[float] = self.requests_memory + self.limits_memory
        for resource in resources:
            if resource > 4096:
                self.violations.append(Violations.HIGH_RESOURCES_CPU_CONTAINER.value)

    def __violation_pod_has_high_memory_resources(self) -> None:
        """
        Append violation if pod (total) has high requests
        or memory limits defined.
        """
        if sum(self.requests_memory) > 4096 or sum(self.limits_memory) > 4096:
            self.violations.append(Violations.HIGH_RESOURCES_MEMORY_POD.value)

    def check_violations(self) -> bool:
        """Check all defined violations and return bool."""
        # self.__violation_pod_has_containers_with_resources_none()  # not in use
        self.__violation_pod_has_containers_with_high_cpu_resources()
        self.__violation_pod_has_high_cpu_resources()
        self.__violation_pod_has_containers_with_high_memory_resources()
        self.__violation_pod_has_high_memory_resources()

        if len(self.violations) > 0:
            return True
        return False

    def print_limit_range_analysis(self) -> None:
        """Shitty implementation of printing limit range analysis information."""
        print("\n")
        print("------------------------")
        print("\n")
        print("Namespace: %s" % self.namespace)
        print("Kind: %s" % self.owner_kind)
        print("Name: %s" % self.owner_name)
        print("LimitRange violations:")
        for violation in self.violations:
            print("\t" + "- %s" % violation)
        print("Resources defined per container:")
        for resource in self.resources:
            print(
                "\t"
                + "- requests: %s, limits: %s" % (resource.requests, resource.limits)
            )
