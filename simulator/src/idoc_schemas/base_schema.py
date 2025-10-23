"""
Base IDoc schema class with common functionality
"""

from datetime import datetime
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field
import uuid


class IDocControl(BaseModel):
    """IDoc control record (EDIDC)"""
    tabnam: str = "EDIDC"
    mandt: str = Field(default="100", description="Client")
    docnum: str = Field(default_factory=lambda: str(uuid.uuid4().int)[:16], description="IDoc number")
    docrel: str = Field(default="740", description="SAP Release")
    status: str = Field(default="03", description="Status (03=Data passed to port OK)")
    direct: str = Field(default="2", description="Direction (2=Outbound)")
    outmod: str = Field(default="2", description="Output mode")
    idoctyp: str = Field(description="IDoc type")
    mestyp: str = Field(description="Message type")
    sndpor: str = Field(default="SAPS4H", description="Sender port")
    sndprt: str = Field(default="LS", description="Sender partner type")
    sndprn: str = Field(description="Sender partner number")
    rcvpor: str = Field(default="EVENTHUB", description="Receiver port")
    rcvprt: str = Field(default="LS", description="Receiver partner type")
    rcvprn: str = Field(default="FABRIC", description="Receiver partner number")
    credat: str = Field(default_factory=lambda: datetime.now().strftime("%Y%m%d"), description="Created date")
    cretim: str = Field(default_factory=lambda: datetime.now().strftime("%H%M%S"), description="Created time")
    serial: str = Field(default_factory=lambda: str(uuid.uuid4().int)[:20], description="Serialization")


class BaseIDocSchema:
    """Base class for all IDoc schemas"""
    
    def __init__(self, sap_system: str = "S4HPRD", sap_client: str = "100"):
        self.sap_system = sap_system
        self.sap_client = sap_client
        self.idoc_type: str = ""
        self.message_type: str = ""
    
    def create_control_record(self, sender: str) -> Dict[str, Any]:
        """Create IDoc control record"""
        control = IDocControl(
            idoctyp=self.idoc_type,
            mestyp=self.message_type,
            sndprn=sender,
            mandt=self.sap_client
        )
        return control.model_dump()
    
    def format_date(self, dt: datetime) -> str:
        """Format date as YYYYMMDD"""
        return dt.strftime("%Y%m%d")
    
    def format_time(self, dt: datetime) -> str:
        """Format time as HHMMSS"""
        return dt.strftime("%H%M%S")
    
    def format_amount(self, amount: float, decimals: int = 2) -> str:
        """Format amount with fixed decimals"""
        return f"{amount:.{decimals}f}"
    
    def format_quantity(self, qty: float, decimals: int = 3) -> str:
        """Format quantity with fixed decimals"""
        return f"{qty:.{decimals}f}"
    
    def generate(self, **kwargs) -> Dict[str, Any]:
        """Generate IDoc document - to be implemented by subclasses"""
        raise NotImplementedError("Subclasses must implement generate method")
    
    def to_json(self, idoc_data: Dict[str, Any]) -> Dict[str, Any]:
        """Convert IDoc to JSON format for Event Hub"""
        return {
            "idoc_type": self.idoc_type,
            "message_type": self.message_type,
            "sap_system": self.sap_system,
            "timestamp": datetime.now().isoformat(),
            "control": idoc_data.get("control", {}),
            "data": idoc_data.get("data", {})
        }
