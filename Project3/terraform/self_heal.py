#!/usr/bin/env python3
import subprocess
import psutil
import os
import socket
import requests

def restart_process_by_name(name):
    """Restart a process by killing and relaunching it"""
    for proc in psutil.process_iter(['pid', 'name']):
        if proc.info['name'] and name in proc.info['name']:
            print(f"[INFO] Restarting {proc.info['name']}")
            proc.kill()
            # Example: Relaunch (customize this part)
            subprocess.Popen(["/usr/bin/node", "/opt/app/index.js"])
            break

def kill_top_memory_consumer():
    """Find and kill the top memory-consuming process"""
    processes = [(p.pid, p.memory_info().rss) for p in psutil.process_iter()]
    if processes:
        top_pid = sorted(processes, key=lambda x: x[1], reverse=True)[0][0]
        try:
            p = psutil.Process(top_pid)
            print(f"[INFO] Killing high memory process: {p.name()} (PID {top_pid})")
            p.kill()
        except Exception as e:
            print(f"[WARN] Could not kill process: {e}")

def clear_disk_space():
    """Delete logs or temp files to recover disk space"""
    print("[INFO] Clearing log files...")
    subprocess.call("rm -rf /var/log/*.log /tmp/*", shell=True)

def is_port_open(port):
    """Check if something is listening on the given port"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0

def restart_web_app():
    """Restart your web app listening on port 3000"""
    if not is_port_open(3000):
        print("[INFO] Web app is down. Restarting...")
        subprocess.Popen(["/usr/bin/node", "/opt/app/index.js"])
    else:
        print("[OK] Web app is running.")

def check_http_5xx(prometheus_url="http://localhost:9090"):
    """Check HTTP 5xx error rate via Prometheus"""
    query = 'sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))'
    try:
        r = requests.get(f"{prometheus_url}/api/v1/query", params={'query': query})
        result = r.json()['data']['result']
        if result and float(result[0]['value'][1]) > 5:  # Adjust threshold as needed
            print("[ALERT] High 5xx rate detected from Prometheus")
            return True
    except Exception as e:
        print(f"[ERROR] Failed to query Prometheus: {e}")
    return False

def main():
    # CPU usage
    cpu = psutil.cpu_percent(interval=5)
    if cpu > 80:
        restart_process_by_name("node")  # customize process name

    # Memory usage
    mem = psutil.virtual_memory()
    if mem.percent > 80:
        kill_top_memory_consumer()

    # Disk usage
    disk = psutil.disk_usage('/')
    if disk.percent > 90:
        clear_disk_space()

    # Check if app on port 3000 is up
    restart_web_app()

    # Check for high 5xx rate via Prometheus
    if check_http_5xx():
        # Implement any additional actions you want for HTTP 5xx errors, such as restarting the app
        restart_web_app()

if __name__ == "__main__":
    main()
