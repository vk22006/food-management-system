import subprocess
import requests


BASE_URL = "https://playful-hawk-lkhl9c-dev-ed.trailblaze.my.salesforce.com"


import json
import subprocess


import json
import subprocess


def get_salesforce_token():
    result = subprocess.run(
        [
            "cmd",
            "/c",
            "sf",
            "org",
            "auth",
            "show-access-token",
            "--target-org",
            "FoodOrderOrg",
            "--json",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    )

    data = json.loads(result.stdout)

    return data["result"]["accessToken"]

def get_menu():
    token = get_salesforce_token()

    url = f"{BASE_URL}/services/apexrest/menu"

    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {token}",
        },
        timeout=15,
    )

    print("Status:", response.status_code)
    print("Response:", response.text)

    response.raise_for_status()

    return response.json()