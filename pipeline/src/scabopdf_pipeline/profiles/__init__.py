from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin

BUILTIN_PLUGINS: list[type[ProfilePlugin]] = [
    ManualeZanichelliGiuridicaProfile,
    UnknownGenericProfile,
]

__all__ = [
    "BUILTIN_PLUGINS",
    "ManualeZanichelliGiuridicaProfile",
    "UnknownGenericProfile",
]
