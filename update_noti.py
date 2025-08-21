import os
import subprocess
import json
import sys
import platform
import urllib.request
import urllib.parse
import socket
import datetime
import argparse

CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')
SLACK_WEBHOOK = ""

# Get system information
def get_system_info():
    hostname = socket.gethostname()
    
    # Get IP address
    try:
        # Connect to a remote address to get the local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
    except:
        ip = "Unknown"
    
    # Get current time
    current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Get OS info
    os_info = f"{platform.system()} {platform.release()}"
    
    # Get uptime (Linux/Unix systems)
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
            uptime_hours = int(uptime_seconds // 3600)
            uptime = f"{uptime_hours}h"
    except:
        uptime = "Unknown"
    
    return {
        "hostname": hostname,
        "ip": ip,
        "time": current_time,
        "os": os_info,
        "uptime": uptime
    }

# Detect package manager
def detect_package_manager():
    if os.path.exists('/usr/bin/apt'):
        return 'apt'
    elif os.path.exists('/usr/bin/dnf'):
        return 'dnf'
    elif os.path.exists('/usr/bin/yum'):
        return 'yum'
    elif os.path.exists('/usr/bin/pacman'):
        return 'pacman'
    elif os.path.exists('/usr/bin/zypper'):
        return 'zypper'
    else:
        return None

# Get upgradable packages
def get_upgradable_packages(pkg_mgr):
    if pkg_mgr == 'apt':
        cmd = ['apt', 'list', '--upgradable']
        result = subprocess.run(cmd, capture_output=True, text=True)
        lines = result.stdout.splitlines()[1:]
        pkgs = [line.split('/')[0] for line in lines if line]
        return pkgs
    elif pkg_mgr == 'dnf':
        cmd = ['dnf', 'check-update']
        result = subprocess.run(cmd, capture_output=True, text=True)
        pkgs = []
        for line in result.stdout.splitlines():
            if line and not line.startswith('Last metadata expiration') and not line.startswith('Obsoleting Packages'):
                parts = line.split()
                if len(parts) > 0 and not parts[0].startswith('='):
                    pkgs.append(parts[0])
        return pkgs
    elif pkg_mgr == 'yum':
        cmd = ['yum', 'check-update']
        result = subprocess.run(cmd, capture_output=True, text=True)
        pkgs = []
        for line in result.stdout.splitlines():
            if line and not line.startswith('Loaded plugins') and not line.startswith('Obsoleting Packages'):
                parts = line.split()
                if len(parts) > 0 and not parts[0].startswith('='):
                    pkgs.append(parts[0])
        return pkgs
    elif pkg_mgr == 'pacman':
        cmd = ['pacman', '-Qu']
        result = subprocess.run(cmd, capture_output=True, text=True)
        pkgs = [line.split()[0] for line in result.stdout.splitlines() if line]
        return pkgs
    elif pkg_mgr == 'zypper':
        cmd = ['zypper', 'list-updates']
        result = subprocess.run(cmd, capture_output=True, text=True)
        pkgs = [line.split('|')[2].strip() for line in result.stdout.splitlines() if '|' in line and 'Package' not in line]
        return pkgs
    else:
        return []

# Auto-update selected packages
def auto_update_packages(pkg_mgr, pkgs):
    if not pkgs:
        return []
    updated = []
    for pkg in pkgs:
        try:
            if pkg_mgr == 'apt':
                subprocess.run(['apt-get', 'install', '-y', pkg], check=True)
            elif pkg_mgr == 'dnf':
                subprocess.run(['dnf', 'upgrade', '-y', pkg], check=True)
            elif pkg_mgr == 'yum':
                subprocess.run(['yum', 'update', '-y', pkg], check=True)
            elif pkg_mgr == 'pacman':
                subprocess.run(['pacman', '-S', '--noconfirm', pkg], check=True)
            elif pkg_mgr == 'zypper':
                subprocess.run(['zypper', '--non-interactive', 'update', pkg], check=True)
            updated.append(pkg)
        except subprocess.CalledProcessError:
            pass
    return updated

# Send message to Slack
def send_slack_message(text):
    payload = {"text": text}
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            SLACK_WEBHOOK,
            data=data,
            headers={'Content-type': 'application/json'}
        )
        with urllib.request.urlopen(req) as response:
            return response.read().decode() == "ok"
    except Exception as e:
        print(f"Failed to send Slack message: {e}")
        return False

def send_install_notification():
    """Send installation completion notification to Slack"""
    sys_info = get_system_info()
    
    install_message = f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    install_message += f"🎉 *UPDATE-NOTI INSTALLED!* 🎉\n"
    install_message += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    install_message += f"📅 **Time:** `{sys_info['time']}`\n"
    install_message += f"🖥️ **Host:** `{sys_info['hostname']}` (`{sys_info['ip']}`)\n"
    install_message += f"💻 **OS:** `{sys_info['os']}`\n"
    install_message += f"⏰ **Uptime:** `{sys_info['uptime']}`\n"
    install_message += f"📍 **Location:** `/opt/update-noti`\n"
    install_message += f"📦 **Method:** Binary from GitHub releases\n"
    install_message += f"✅ **Status:** Installation completed successfully! 🚀\n"
    install_message += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    install_message += f"⏰ **Schedule:** Daily at 00:00 + boot backup\n"
    install_message += f"🔄 **Auto-update:** Enabled\n"
    install_message += f"📝 **Config:** `/opt/update-noti/config.json`\n"
    install_message += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if send_slack_message(install_message):
        print("✅ Installation notification sent to Slack")
        return True
    else:
        print("⚠️ Failed to send installation notification to Slack")
        return False

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Package Updates Notification System')
    parser.add_argument('--install-complete', action='store_true',
                       help='Send installation completion notification and exit')
    args = parser.parse_args()
    
    # Handle installation complete notification
    if args.install_complete:
        send_install_notification()
        return
    
    pkg_mgr = detect_package_manager()
    if not pkg_mgr:
        print("No supported package manager found.")
        sys.exit(1)

    # Get system information
    sys_info = get_system_info()

    upgradable = get_upgradable_packages(pkg_mgr)
    if not upgradable:
        msg = f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        msg += f"🔍 *SYSTEM UPDATE CHECK* 🔍\n"
        msg += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        msg += f"📅 **Time:** `{sys_info['time']}`\n"
        msg += f"🖥️ **Host:** `{sys_info['hostname']}` (`{sys_info['ip']}`)\n"
        msg += f"💻 **OS:** `{sys_info['os']}`\n"
        msg += f"⏰ **Uptime:** `{sys_info['uptime']}`\n"
        msg += f"📦 **Package Manager:** `{pkg_mgr}`\n"
        msg += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        msg += f"✅ **STATUS:** All packages are up to date! 🎉\n"
        msg += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        send_slack_message(msg)
        return

    # Load config
    with open(CONFIG_FILE) as f:
        config = json.load(f)
    auto_update = config.get('auto_update', [])

    # Find which auto-update packages are upgradable
    to_update = [pkg for pkg in upgradable if pkg in auto_update]
    updated = auto_update_packages(pkg_mgr, to_update)

    # Create detailed message with system info and visual formatting
    msg = f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    msg += f"🔍 *SYSTEM UPDATE CHECK* 🔍\n"
    msg += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    msg += f"📅 **Time:** `{sys_info['time']}`\n"
    msg += f"🖥️ **Host:** `{sys_info['hostname']}` (`{sys_info['ip']}`)\n"
    msg += f"💻 **OS:** `{sys_info['os']}`\n"
    msg += f"⏰ **Uptime:** `{sys_info['uptime']}`\n"
    msg += f"📦 **Package Manager:** `{pkg_mgr}`\n"
    msg += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    # Format package list with better visual structure
    if len(upgradable) <= 10:
        # Show packages in a clean list format for small numbers
        package_list = '\n'.join([f"  • `{pkg}`" for pkg in upgradable])
        msg += f"🔄 **AVAILABLE UPDATES ({len(upgradable)}):**\n{package_list}\n"
    else:
        # Show packages inline for large numbers
        msg += f"🔄 **AVAILABLE UPDATES ({len(upgradable)}):**\n"
        msg += f"`{', '.join(upgradable)}`\n"
    
    msg += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
    
    if updated:
        if len(updated) <= 5:
            updated_list = '\n'.join([f"  ✅ `{pkg}`" for pkg in updated])
            msg += f"🔧 **AUTO-UPDATED ({len(updated)}):**\n{updated_list}\n"
        else:
            msg += f"🔧 **AUTO-UPDATED ({len(updated)}):**\n"
            msg += f"`{', '.join(updated)}`\n"
        msg += f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        msg += f"✅ **STATUS:** Updates completed successfully! 🚀"
    else:
        msg += f"⚠️ **STATUS:** Updates available but none auto-updated"
    
    msg += f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    send_slack_message(msg)

if __name__ == "__main__":
    main()
