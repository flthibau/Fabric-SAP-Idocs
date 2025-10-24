#!/usr/bin/env python3
"""
SAP IDoc Simulator - Main Entry Point
Generates and publishes IDoc messages to Azure Event Hub
"""

import asyncio
import os
import sys
import time
import signal
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, Any
import yaml
from dotenv import load_dotenv

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from src.idoc_generator import IDocGenerator
from src.eventstream_publisher import EventStreamPublisher
from src.utils.logger import setup_logger

# Load environment variables
load_dotenv()

# Setup logger
logger = setup_logger("main", level=os.getenv("LOG_LEVEL", "INFO"))

# Global flag for graceful shutdown
shutdown_flag = False


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global shutdown_flag
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_flag = True


def load_config(config_path: str = "config/config.yaml") -> Dict[str, Any]:
    """Load configuration from YAML file"""
    try:
        # Expand environment variables in config
        with open(config_path, 'r') as f:
            config_content = f.read()
        
        # Replace environment variables
        import re
        def replace_env_var(match):
            var_name = match.group(1)
            default = match.group(2) if match.group(2) else ""
            return os.getenv(var_name, default.lstrip(":-"))
        
        config_content = re.sub(r'\$\{([^}:]+)(?::-(.*?))?\}', replace_env_var, config_content)
        
        config = yaml.safe_load(config_content)
        logger.info(f"Loaded configuration from {config_path}")
        return config
    except Exception as e:
        logger.error(f"Error loading configuration: {str(e)}")
        raise


async def run_simulator(config: Dict[str, Any], message_count: int = None):
    """
    Main simulator loop
    
    Args:
        config: Configuration dictionary
        message_count: Optional number of messages to send before stopping
    """
    global shutdown_flag
    
    # Extract configuration
    eventhub_config = config.get("eventhub", {})
    sap_config = config.get("sap", {})
    simulator_config = config.get("simulator", {})
    master_data_config = config.get("master_data", {})
    monitoring_config = config.get("monitoring", {})
    
    # Initialize IDoc generator
    generator = IDocGenerator(
        sap_system=sap_config.get("system_id", "S4HPRD"),
        sap_client=str(sap_config.get("client", "100")),  # Ensure string type
        warehouse_count=master_data_config.get("warehouse_count", 5),
        customer_count=master_data_config.get("customer_count", 100),
        carrier_count=master_data_config.get("carrier_count", 20)
    )
    
    # Initialize Event Hub publisher
    publisher = None
    if not simulator_config.get("dry_run", False):
        try:
            # Convert string "true"/"false" to boolean
            use_azure_cred = eventhub_config.get("use_azure_credential", False)
            if isinstance(use_azure_cred, str):
                use_azure_cred = use_azure_cred.lower() in ('true', '1', 'yes')
            
            if use_azure_cred:
                publisher = EventStreamPublisher(
                    namespace=eventhub_config.get("namespace"),
                    eventhub_name=eventhub_config.get("eventhub_name"),
                    use_azure_credential=True
                )
            else:
                publisher = EventStreamPublisher(
                    connection_string=eventhub_config.get("connection_string"),
                    eventhub_name=eventhub_config.get("eventhub_name")
                )
            logger.info("Event Hub publisher initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Event Hub publisher: {str(e)}")
            return
    else:
        logger.info("Running in DRY RUN mode - messages will not be sent")
    
    # Simulator parameters
    message_rate = simulator_config.get("message_rate", 10)  # messages per minute
    batch_size = simulator_config.get("batch_size", 100)
    run_duration = simulator_config.get("run_duration", 3600)  # seconds
    batch_delay = simulator_config.get("batch_delay", 5)
    
    # Calculate timing
    messages_per_second = message_rate / 60
    delay_between_messages = 1.0 / messages_per_second if messages_per_second > 0 else 1.0
    
    # Monitoring
    start_time = time.time()
    total_messages = 0
    total_batches = 0
    last_metrics_time = start_time
    metrics_interval = monitoring_config.get("metrics_interval", 60)
    print_samples = monitoring_config.get("print_sample_messages", True)
    sample_rate = monitoring_config.get("sample_rate", 0.1)
    
    logger.info(f"Starting IDoc simulator - Rate: {message_rate} msg/min, Batch size: {batch_size}")
    if message_count:
        logger.info(f"Target: {message_count} messages")
    else:
        logger.info(f"Run duration: {run_duration}s ({'continuous' if run_duration == 0 else f'{run_duration/3600:.1f} hours'})")
    
    try:
        while not shutdown_flag:
            # Check message count limit
            if message_count and total_messages >= message_count:
                logger.info(f"Target message count of {message_count} reached. Stopping simulator.")
                break
            
            # Check run duration
            elapsed_time = time.time() - start_time
            if run_duration > 0 and elapsed_time >= run_duration:
                logger.info(f"Run duration of {run_duration}s reached. Stopping simulator.")
                break
            
            # Adjust batch size if needed to not exceed message_count
            current_batch_size = batch_size
            if message_count:
                remaining = message_count - total_messages
                current_batch_size = min(batch_size, remaining)
                if current_batch_size <= 0:
                    break
            
            # Generate batch of IDocs
            batch_start = time.time()
            idocs = generator.generate_mixed_batch(current_batch_size)
            batch_gen_time = time.time() - batch_start
            
            # Print sample messages
            if print_samples and idocs:
                import random
                if random.random() < sample_rate:
                    sample_idoc = random.choice(idocs)
                    logger.info(f"Sample IDoc: Type={sample_idoc.get('idoc_type')}, "
                              f"Doc={sample_idoc.get('control', {}).get('docnum', 'N/A')}")
            
            # Send to Event Hub
            if publisher and not simulator_config.get("dry_run", False):
                send_start = time.time()
                sent_count = await publisher.send_batch(idocs)
                send_time = time.time() - send_start
                
                total_messages += sent_count
                total_batches += 1
                
                logger.debug(f"Batch {total_batches}: Generated {batch_size} IDocs in {batch_gen_time:.2f}s, "
                           f"Sent {sent_count} in {send_time:.2f}s")
            else:
                total_messages += len(idocs)
                total_batches += 1
                logger.debug(f"Batch {total_batches}: Generated {batch_size} IDocs (DRY RUN)")
            
            # Print metrics periodically
            current_time = time.time()
            if current_time - last_metrics_time >= metrics_interval:
                elapsed = current_time - start_time
                rate = total_messages / elapsed if elapsed > 0 else 0
                
                metrics = {
                    "elapsed_time_seconds": round(elapsed, 2),
                    "total_messages": total_messages,
                    "total_batches": total_batches,
                    "messages_per_second": round(rate, 2),
                    "messages_per_minute": round(rate * 60, 2)
                }
                
                if publisher:
                    pub_stats = publisher.get_statistics()
                    metrics.update({
                        "bytes_sent": pub_stats["bytes_sent"],
                        "avg_message_size_bytes": round(pub_stats["avg_message_size"], 2)
                    })
                
                logger.info(f"Metrics: {metrics}")
                last_metrics_time = current_time
            
            # Wait before next batch
            await asyncio.sleep(batch_delay)
    
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt, shutting down...")
    except Exception as e:
        logger.error(f"Error in simulator loop: {str(e)}", exc_info=True)
    finally:
        # Final statistics
        total_elapsed = time.time() - start_time
        final_rate = total_messages / total_elapsed if total_elapsed > 0 else 0
        
        logger.info("=" * 80)
        logger.info("Simulator Session Summary")
        logger.info("=" * 80)
        logger.info(f"Total runtime: {total_elapsed:.2f} seconds ({total_elapsed/3600:.2f} hours)")
        logger.info(f"Total messages generated: {total_messages}")
        logger.info(f"Total batches: {total_batches}")
        logger.info(f"Average rate: {final_rate:.2f} msg/s ({final_rate*60:.2f} msg/min)")
        
        if publisher:
            pub_stats = publisher.get_statistics()
            logger.info(f"Total bytes sent: {pub_stats['bytes_sent']:,} ({pub_stats['bytes_sent']/1024/1024:.2f} MB)")
            logger.info(f"Average message size: {pub_stats['avg_message_size']:.2f} bytes")
            await publisher.close()
        
        logger.info("=" * 80)


def main():
    """Main entry point"""
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="SAP IDoc Simulator for Microsoft Fabric")
    parser.add_argument(
        "--count",
        type=int,
        help="Number of messages to send before stopping (overrides config duration)"
    )
    parser.add_argument(
        "--config",
        type=str,
        default="config/config.yaml",
        help="Path to configuration file (default: config/config.yaml)"
    )
    args = parser.parse_args()
    
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("=" * 80)
    logger.info("SAP IDoc Simulator for 3PL - Microsoft Fabric Integration")
    logger.info(f"Started at: {datetime.now().isoformat()}")
    logger.info("=" * 80)
    
    try:
        # Load configuration
        config = load_config(args.config)
        
        # Run simulator
        asyncio.run(run_simulator(config, message_count=args.count))
        
    except Exception as e:
        logger.error(f"Fatal error: {str(e)}", exc_info=True)
        sys.exit(1)
    
    logger.info("Simulator stopped successfully")
    sys.exit(0)


if __name__ == "__main__":
    main()
