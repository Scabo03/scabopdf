from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin

BUILTIN_PLUGINS: list[type[ProfilePlugin]] = [UnknownGenericProfile]

__all__ = ["BUILTIN_PLUGINS", "UnknownGenericProfile"]
