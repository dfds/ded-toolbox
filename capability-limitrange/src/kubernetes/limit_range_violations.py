from enum import Enum


class Violations(Enum):
    """Violation options to choose from."""

    NONE_RESOURCES: str = (
        "WARNING: Pod has not defined some or all resources for its containers."
    )
    HIGH_RESOURCES_CPU_CONTAINER: str = (
        "CRITICAL: Pod has a container with CPU limit or request higher than allowed."
    )
    HIGH_RESOURCES_MEMORY_CONTAINER: str = (
        "CRITICAL: Pod has a container with MEMORY limit or request higher than"
        " allowed."
    )
    HIGH_RESOURCES_CPU_POD: str = (
        "CRITICAL: Pod has total CPU limit or request higher than allowed."
    )
    HIGH_RESOURCES_MEMORY_POD: str = (
        "CRITICAL: Pod has total MEMORY limit or request higher than allowed."
    )
