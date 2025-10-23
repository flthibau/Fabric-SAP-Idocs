"""
IDoc schema definitions for 3PL business processes
"""

from .base_schema import BaseIDocSchema
from .desadv_schema import DESADVSchema
from .shpmnt_schema import SHPMNTSchema
from .invoice_schema import INVOICESchema
from .orders_schema import ORDERSSchema
from .whscon_schema import WHSCONSchema

__all__ = [
    "BaseIDocSchema",
    "DESADVSchema",
    "SHPMNTSchema",
    "INVOICESchema",
    "ORDERSSchema",
    "WHSCONSchema"
]
