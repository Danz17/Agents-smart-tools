#!/usr/bin/env python3
"""
Enable RouterOS API service via SSH
This script connects via SSH and enables the API service
"""

import paramiko
import sys
import socket

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"

def enable_api_via_ssh():
    """Connect via SSH and enable RouterOS API service"""
    try:
        print(f"Connecting to {HOST} via SSH...")
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(HOST, username=USERNAME, password=PASSWORD, port=22, timeout=10)
        
        print("[OK] SSH connection established")
        
        # Enable API service
        print("\nEnabling RouterOS API service on port 8728...")
        commands = [
            "/ip service set [find name=api] port=8728",
            "/ip service enable api",
            "/ip service print where name=api"
        ]
        
        for cmd in commands:
            print(f"Executing: {cmd}")
            stdin, stdout, stderr = ssh.exec_command(cmd)
            
            # Wait for command to complete
            exit_status = stdout.channel.recv_exit_status()
            output = stdout.read().decode('utf-8', errors='ignore').strip()
            error = stderr.read().decode('utf-8', errors='ignore').strip()
            
            if error:
                print(f"  Error: {error}")
            if output:
                print(f"  Output: {output}")
            if exit_status == 0:
                print(f"  [OK] Command executed successfully")
            else:
                print(f"  [WARNING] Exit status: {exit_status}")
        
        print("\n[OK] RouterOS API service should now be enabled on port 8728")
        print("You can now try connecting using routeros_connect.py")
        
        ssh.close()
        return True
        
    except paramiko.AuthenticationException as e:
        print(f"[ERROR] Authentication failed: {str(e)}")
        print("Possible issues:")
        print("  - Username or password incorrect")
        print("  - SSH service may require different credentials")
        print("  - User may not have SSH access enabled")
        print("\nTry enabling API manually via Winbox/WebFig instead")
        return False
    except paramiko.SSHException as e:
        print(f"[ERROR] SSH connection failed: {str(e)}")
        return False
    except socket.timeout:
        print("[ERROR] Connection timeout - router may be unreachable")
        return False
    except Exception as e:
        print(f"[ERROR] Connection failed: {str(e)}")
        print(f"Error type: {type(e).__name__}")
        return False

if __name__ == "__main__":
    try:
        import paramiko
    except ImportError:
        print("[ERROR] paramiko library not installed")
        print("Install it with: pip install paramiko")
        sys.exit(1)
    
    enable_api_via_ssh()


