import json
import sys
import os
import urllib.request
from google.oauth2 import service_account
import google.auth.transport.requests

# 0. Load credentials
sa_path = sys.argv[1]
creds = service_account.Credentials.from_service_account_file(
    sa_path,
    scopes=["https://www.googleapis.com/auth/cloud-platform"]
)

request = google.auth.transport.requests.Request()
creds.refresh(request)
token = creds.token

with open(sa_path, 'r') as f:
    project_id = json.load(f)["project_id"]

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

def make_request(url, method="GET", data=None):
    req = urllib.request.Request(url, headers=headers, method=method)
    if data:
        req.data = json.dumps(data).encode('utf-8')
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        print(f"HTTPError: {e.code} - {e.read().decode()}")
        sys.exit(1)

# 1. Check existing Web Apps
print(f"Listing internal Web Apps for project {project_id}...")
list_url = f"https://firebase.googleapis.com/v1beta1/projects/{project_id}/webApps"
apps_resp = make_request(list_url)
web_apps = apps_resp.get("apps", [])

if not web_apps:
    print("No Web App found. Creating one...")
    create_url = f"https://firebase.googleapis.com/v1beta1/projects/{project_id}/webApps"
    create_resp = make_request(create_url, method="POST", data={"displayName": "AwakeTime Web"})
    
    op_name = create_resp["name"]
    print(f"Waiting for creation operation {op_name}...")
    
    app_id = None
    import time
    for _ in range(15):
        op_res = make_request(f"https://firebase.googleapis.com/v1beta1/{op_name}")
        if op_res.get("done"):
            app_id = op_res["response"]["appId"]
            break
        time.sleep(1)
        
    if not app_id:
        print("Failed to get appId from creation.")
        sys.exit(1)
    
    app_name = f"projects/{project_id}/webApps/{app_id}"
else:
    app_name = web_apps[0]["name"]
    print(f"Found existing web app: {app_name}")

# 2. Get Config
config_url = f"https://firebase.googleapis.com/v1beta1/{app_name}/config"
config_data = make_request(config_url)
print("=== CONFIG_START ===")
print(json.dumps(config_data))
print("=== CONFIG_END ===")
