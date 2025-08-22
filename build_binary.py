#!/usr/bin/env python3
"""
Binary Builder for Package Updates Notifier
Builds standalone executables using PyInstaller
"""

import os
import sys
import shutil
import subprocess
import json
import logging
from datetime import datetime
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('build.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

def clean_build_directories():
    """Clean existing build directories"""
    dirs_to_clean = ['build', 'dist', '__pycache__']
    for dir_name in dirs_to_clean:
        if os.path.exists(dir_name):
            logging.info(f"Cleaning directory: {dir_name}")
            shutil.rmtree(dir_name)
    
    # Clean spec files
    for spec_file in Path('.').glob('*.spec'):
        logging.info(f"Removing spec file: {spec_file}")
        spec_file.unlink()

def check_dependencies():
    """Check if PyInstaller is installed"""
    try:
        subprocess.run(['pyinstaller', '--version'], 
                      capture_output=True, check=True)
        logging.info("✅ PyInstaller is available")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        logging.error("❌ PyInstaller not found. Install with: pip install pyinstaller>=6.0.0")
        return False

def get_version_info():
    """Extract version info from git or use current date"""
    try:
        # Try to get git tag
        result = subprocess.run(['git', 'describe', '--tags', '--abbrev=0'], 
                              capture_output=True, text=True, check=True)
        version = result.stdout.strip()
        logging.info(f"Using git tag version: {version}")
        return version
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Fallback to date-based version
        version = f"v{datetime.now().strftime('%Y.%m.%d')}"
        logging.info(f"Using date-based version: {version}")
        return version

def build_binary():
    """Build the binary using PyInstaller"""
    version = get_version_info()
    
    # PyInstaller command with optimizations
    cmd = [
        'pyinstaller',
        '--onefile',                    # Single executable
        '--name=update-noti',           # Output name
        '--distpath=dist',              # Output directory
        '--workpath=build',             # Build directory
        '--clean',                      # Clean cache
        '--noconfirm',                  # Overwrite without confirmation
        '--optimize=2',                 # Python optimization level
        '--strip',                      # Strip debug symbols (Linux/macOS)
        '--console',                    # Console application
        '--add-data=LICENSE:.',         # Include license
        'update_noti.py'                # Main script
    ]
    
    logging.info("Building binary with PyInstaller...")
    logging.info(f"Command: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        logging.info("✅ Binary build completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        logging.error(f"❌ Build failed: {e}")
        if e.stdout:
            logging.error(f"STDOUT: {e.stdout}")
        if e.stderr:
            logging.error(f"STDERR: {e.stderr}")
        return False

def test_binary():
    """Test the built binary"""
    binary_path = os.path.join('dist', 'update-noti')
    
    if not os.path.exists(binary_path):
        logging.error(f"❌ Binary not found: {binary_path}")
        return False
    
    # Check if file is executable
    if not os.access(binary_path, os.X_OK):
        logging.error(f"❌ Binary is not executable: {binary_path}")
        return False
    
    # Test binary execution
    try:
        result = subprocess.run([binary_path, '--help'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            logging.info("✅ Binary test successful")
            return True
        else:
            logging.error(f"❌ Binary test failed with return code: {result.returncode}")
            return False
    except subprocess.TimeoutExpired:
        logging.error("❌ Binary test timeout")
        return False
    except Exception as e:
        logging.error(f"❌ Binary test error: {e}")
        return False

def get_binary_info():
    """Get information about the built binary"""
    binary_path = os.path.join('dist', 'update-noti')
    
    if not os.path.exists(binary_path):
        return None
    
    stat = os.stat(binary_path)
    size_mb = stat.st_size / (1024 * 1024)
    
    return {
        'path': binary_path,
        'size': stat.st_size,
        'size_mb': round(size_mb, 2),
        'created': datetime.fromtimestamp(stat.st_ctime).isoformat()
    }

def create_release_info():
    """Create release information file"""
    version = get_version_info()
    binary_info = get_binary_info()
    
    if not binary_info:
        logging.error("❌ Cannot create release info - binary not found")
        return False
    
    release_info = {
        'version': version,
        'build_date': datetime.now().isoformat(),
        'binary': {
            'name': 'update-noti',
            'size_bytes': binary_info['size'],
            'size_mb': binary_info['size_mb']
        },
        'build_info': {
            'python_version': f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
            'platform': sys.platform,
            'architecture': os.uname().machine if hasattr(os, 'uname') else 'unknown'
        }
    }
    
    # Write release info
    with open('dist/release-info.json', 'w') as f:
        json.dump(release_info, f, indent=2)
    
    logging.info(f"✅ Release info created: {version}")
    return True

def main():
    """Main build process"""
    logging.info("🚀 Starting binary build process...")
    
    # Check if main script exists
    if not os.path.exists('update_noti.py'):
        logging.error("❌ Main script 'update_noti.py' not found")
        sys.exit(1)
    
    # Step 1: Check dependencies
    if not check_dependencies():
        sys.exit(1)
    
    # Step 2: Clean build directories
    clean_build_directories()
    
    # Step 3: Build binary
    if not build_binary():
        sys.exit(1)
    
    # Step 4: Test binary
    if not test_binary():
        sys.exit(1)
    
    # Step 5: Create release info
    if not create_release_info():
        sys.exit(1)
    
    # Final summary
    binary_info = get_binary_info()
    if binary_info:
        logging.info("🎉 Build completed successfully!")
        logging.info(f"📁 Binary location: {binary_info['path']}")
        logging.info(f"📏 Binary size: {binary_info['size_mb']} MB")
        logging.info(f"✅ Binary is ready for distribution")
    else:
        logging.error("❌ Failed to get binary information")
        sys.exit(1)

if __name__ == '__main__':
    main()