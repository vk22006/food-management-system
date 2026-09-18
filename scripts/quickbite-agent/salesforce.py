import subprocess
import requests
import json


BASE_URL = "https://playful-hawk-lkhl9c-dev-ed.trailblaze.my.salesforce.com"

# Enable Salesforce Connectivity
def get_salesforce_connection():
    result = subprocess.run(
        [
            "cmd",
            "/c",
            "sf",
            "org",
            "display",
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

    result_data = data["result"]

    # Access token must be retrieved separately because
    # newer Salesforce CLI versions don't expose it through org display.
    token_result = subprocess.run(
        [
            "cmd",
            "/c",
            "sf",
            "org",
            "auth",
            "show-access-token",
            "--target-org",
            "FoodOrderOrg",
            "--no-prompt",
            "--json",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    )

    token_data = json.loads(token_result.stdout)

    return {
        "access_token": token_data["result"]["accessToken"],
        "instance_url": result_data["instanceUrl"],
    }

# GET - Menu Details

def get_menu():
    token = get_salesforce_connection()

    url = f"{BASE_URL}/services/apexrest/menu"

    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {token}",
        },
        timeout=15,
    )

    response.raise_for_status()

    return response.json()

# GET - Order by Name

def find_order_by_name(order_name):
    connection = get_salesforce_connection()

    safe_order_name = (
        order_name
        .replace("\\", "\\\\")
        .replace("'", "\\'")
    )

    query = (
        "SELECT Id, Name "
        "FROM Order__c "
        f"WHERE Name = '{safe_order_name}' "
        "LIMIT 1"
    )

    url = f"{connection['instance_url']}/services/data/v67.0/query"

    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {connection['access_token']}",
        },
        params={"q": query},
        timeout=15,
    )

    response.raise_for_status()

    data = response.json()

    records = data.get("records", [])

    if not records:
        return None

    return records[0]["Id"]

def get_order(order_name):
    connection = get_salesforce_connection()

    order_id = find_order_by_name(order_name)

    if not order_id:
        return {
            "success": False,
            "message": f"Order {order_name} was not found."
        }

    url = f"{connection['instance_url']}/services/apexrest/orders/{order_id}"

    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {connection['access_token']}",
        },
        timeout=15,
    )

    response.raise_for_status()

    return response.json()

# GET - Delivery details

def find_delivery_by_order(order_name):
    connection = get_salesforce_connection()

    safe_order_name = (
        order_name
        .replace("\\", "\\\\")
        .replace("'", "\\'")
    )

    query = (
        "SELECT Id, Order__c, Order__r.Name "
        "FROM Delivery__c "
        f"WHERE Order__r.Name = '{safe_order_name}' "
        "LIMIT 1"
    )

    url = f"{connection['instance_url']}/services/data/v67.0/query"

    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {connection['access_token']}",
        },
        params={"q": query},
        timeout=15,
    )

    response.raise_for_status()

    data = response.json()
    records = data.get("records", [])

    if not records:
        return None

    return records[0]["Id"]

def get_delivery(order_name):
    connection = get_salesforce_connection()

    delivery_id = find_delivery_by_order(order_name)

    if not delivery_id:
        return {
            "success": False,
            "message": f"No delivery was found for order {order_name}."
        }

    url = (
        f"{connection['instance_url']}"
        f"/services/apexrest/deliveries/{delivery_id}"
    )

    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {connection['access_token']}",
        },
        timeout=15,
    )

    response.raise_for_status()

    return response.json()