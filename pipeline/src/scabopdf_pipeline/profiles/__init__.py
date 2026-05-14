from scabopdf_pipeline.profiles.compendio_utet import CompendioUtetProfile
from scabopdf_pipeline.profiles.manuale_utet_wolterskluwer import (
    ManualeUtetWolterskluwerProfile,
)
from scabopdf_pipeline.profiles.manuale_zanichelli_giuridica import (
    ManualeZanichelliGiuridicaProfile,
)
from scabopdf_pipeline.profiles.unknown_generic import UnknownGenericProfile
from scabopdf_pipeline.profiling.plugin import ProfilePlugin

BUILTIN_PLUGINS: list[type[ProfilePlugin]] = [
    CompendioUtetProfile,
    ManualeUtetWolterskluwerProfile,
    ManualeZanichelliGiuridicaProfile,
    UnknownGenericProfile,
]

__all__ = [
    "BUILTIN_PLUGINS",
    "CompendioUtetProfile",
    "ManualeUtetWolterskluwerProfile",
    "ManualeZanichelliGiuridicaProfile",
    "UnknownGenericProfile",
]
