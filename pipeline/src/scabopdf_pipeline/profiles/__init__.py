from scabopdf_pipeline.profiles.compendio_utet import CompendioUtetProfile
from scabopdf_pipeline.profiles.dejure_dottrina import DejureDottrinaProfile
from scabopdf_pipeline.profiles.dejure_massime import DejureMassimeProfile
from scabopdf_pipeline.profiles.dejure_nota_sentenza import (
    DejureNotaSentenzaProfile,
)
from scabopdf_pipeline.profiles.enciclopedia_moderna import EnciclopediaModernaProfile
from scabopdf_pipeline.profiles.enciclopedia_storica import EnciclopediaStoricaProfile
from scabopdf_pipeline.profiles.manuale_bic import ManualeBicProfile
from scabopdf_pipeline.profiles.manuale_giappichelli import ManualeGiappichelliProfile
from scabopdf_pipeline.profiles.manuale_giuffre_diretto import (
    ManualeGiuffreDirectoProfile,
)
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
    DejureDottrinaProfile,
    DejureMassimeProfile,
    DejureNotaSentenzaProfile,
    EnciclopediaModernaProfile,
    EnciclopediaStoricaProfile,
    ManualeBicProfile,
    ManualeGiappichelliProfile,
    ManualeGiuffreDirectoProfile,
    ManualeUtetWolterskluwerProfile,
    ManualeZanichelliGiuridicaProfile,
    UnknownGenericProfile,
]

__all__ = [
    "BUILTIN_PLUGINS",
    "CompendioUtetProfile",
    "DejureDottrinaProfile",
    "DejureMassimeProfile",
    "DejureNotaSentenzaProfile",
    "EnciclopediaModernaProfile",
    "EnciclopediaStoricaProfile",
    "ManualeBicProfile",
    "ManualeGiappichelliProfile",
    "ManualeGiuffreDirectoProfile",
    "ManualeUtetWolterskluwerProfile",
    "ManualeZanichelliGiuridicaProfile",
    "UnknownGenericProfile",
]
