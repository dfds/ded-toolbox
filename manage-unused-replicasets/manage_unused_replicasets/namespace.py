from kubernetes import client, config


class Namespace:
    """
    A class that represent a Namespace
    """

    def __init__(self) -> None:
        """
        Class constructor.
        """
        config.load_kube_config()

    @staticmethod
    def _get_namespaces_definition() -> client.V1NamespaceList:
        """
        Get the whole spec for all namespaces.
        :return: client.V1NamespaceList
        """
        v1: client.CoreV1Api = client.CoreV1Api()
        return v1.list_namespace()

    def get_namespaces(self) -> list:
        """
        Get a list of namespaces.
        :return: list
        """
        namespaces_definition: client.V1NamespaceList = (
            self._get_namespaces_definition()
        )
        namespaces: list = []
        for item in namespaces_definition.items:
            namespaces.append(item.metadata.name)
        return namespaces
