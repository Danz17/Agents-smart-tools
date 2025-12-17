#!/usr/bin/env python3
"""
Enable RouterOS API via Web Interface (REST API)
This tries to use the MikroTik REST API if available
"""

import requests
import urllib3

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"

def enable_api_via_rest():
    """Try to enable API via REST API"""
    base_url = f"https://{HOST}/rest"
    
    # Try to authenticate and enable API
    try:
        print(f"Attempting to connect to {HOST} via REST API...")
        
        # MikroTik REST API authentication
        session = requests.Session()
        session.verify = False  # Disable SSL verification for self-signed certs
        
        # Try to get system identity first
        url = f"{base_url}/system/identity"
        response = session.get(url, auth=(USERNAME, PASSWORD), timeout=5)
        
        if response.status_code == 200:
            print("[OK] REST API connection successful!")
            print(f"Router Identity: {response.json()}")
            
            # Try to enable API service
            print("\nEnabling RouterOS API service...")
            api_url = f"{base_url}/ip/service/api"
            
            # Set port to 8728
            data = {"port": "8728"}
            response = session.patch(api_url, json=data, auth=(USERNAME, PASSWORD))
            
            # Enable the service
            data = {"disabled": "false"}
            response = session.patch(api_url, json=data, auth=(USERNAME, PASSWORD))
            
            if response.status_code in [200, 204]:
                print("[OK] RouterOS API service enabled on port 8728")
                return True
            else:
                print(f"[WARNING] Could not enable API: {response.status_code}")
                print("You may need to enable it manually via Winbox/WebFig")
                return False
        else:
            print(f"[INFO] REST API not available (status: {response.status_code})")
            print("RouterOS API must be enabled manually")
            return False
            
    except requests.exceptions.SSLError:
        # Try HTTP instead of HTTPS
        print("HTTPS failed, trying HTTP...")
        base_url = f"http://{HOST}/rest"
        try:
            url = f"{base_url}/system/identity"
            response = requests.get(url, auth=(USERNAME, PASSWORD), timeout=5)
            if response.status_code == 200:
                print("[OK] REST API connection via HTTP successful!")
                return True
        except:
            pass
    except Exception as e:
        print(f"[INFO] REST API not available: {str(e)}")
        print("\nTo enable RouterOS API manually:")
        print("1. Connect via Winbox (port 8291) or WebFig (port 80)")
        print("2. Go to IP > Services")
        print("3. Find 'api' service and enable it")
        print("4. Set port to 8728")
        return False
    
    return False

if __name__ == "__main__":
    enable_api_via_rest()

