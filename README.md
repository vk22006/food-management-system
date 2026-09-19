# Food Order Management System

English | [தமிழ்](docs/README_TA.md)

A Salesforce-based food delivery management platform for managing restaurants, menus, customer orders, deliveries, automation, reporting, customer access, REST APIs, and AI-assisted support.

![screenshot](docs/img/image.png)

---

## Features

- **Restaurant & Menu Management** - Restaurants, cuisines, menu items, pricing, and availability.
- **Order Management** - Customer orders, order items, automatic totals, and status validation.
- **Delivery Management** - Delivery creation, partner assignment, status tracking, and synchronization.
- **Automation** - Record-triggered Flows for orders, deliveries, status updates, and notifications.
- **Apex Development** - Service classes, triggers, business logic, and Apex REST controllers.
- **Security** - OWD, role hierarchy, permission sets, sharing rules, and field-level security.
- **Experience Cloud** - Customer portal for browsing restaurants, menus, orders, and deliveries.
- **Reports & Dashboards** - Operational and revenue analytics.
- **REST API** - External integration through custom Apex REST endpoints.
- **Postman** - API testing and demonstration.
- **Local AI Support** - Qwen3 4B + Ollama agent for FAQ, menu, order, and delivery queries.

![cli-agent](docs/img/agent.png)

> The AI assistant is a local AI integration and is not Salesforce Agentforce.

---

## Architecture

```text
                         QuickBite
                             |
             +---------------+---------------+
             |               |               |
        Salesforce      Experience       External
         Platform          Cloud        Integrations
             |               |               |
       +-----+-----+         |         +-----+-----+
       |     |     |         |         |           |
     Flow  Apex  Security    |      Postman     AI Agent
       |     |     |         |                    |
       +-----+-----+         |                 Qwen3 4B
             |               |                    |
             +---------------+--------------------+
                             |
                      Salesforce Data
````

---

## Data Model

```text
Restaurant
    |
    └── Menu Item

Contact
    |
    └── Order
          |
          └── Order Item
          |
          └── Delivery
                |
                └── Delivery Partner (Contact)
```

### Core Objects

| Object          | Purpose                    |
| --------------- | -------------------------- |
| `Restaurant__c` | Restaurant information     |
| `Menu_Item__c`  | Restaurant menu items      |
| `Order__c`      | Customer orders            |
| `Order_Item__c` | Items within an order      |
| `Delivery__c`   | Order delivery information |

---

## Order Lifecycle

```text
Pending → Accepted → Preparing → Out for Delivery → Delivered
                  \
                   → Cancelled
```

## Delivery Lifecycle

```text
Assigned → Picked Up → Out for Delivery → Delivered
```

---

## Apex

Key Apex components:

* `OrderService` - Order creation, retrieval, status updates, and business logic.
* `OrderTotalCalculator` - Bulkified order total calculation.
* `DeliveryChargeCalculator` - Delivery charge calculation.
* `OrderItemTrigger` - Maintains order totals when order items change.
* `MenuRestController` - Menu REST API.
* `OrderRestController` - Order REST API.
* `DeliveryRestController` - Delivery REST API.

Apex tests cover triggers, services, calculations, validation, and REST functionality.

---

## REST API

| Method | Endpoint                             | Purpose             |
| ------ | ------------------------------------ | ------------------- |
| `GET`  | `/services/apexrest/menu`            | Get menu            |
| `GET`  | `/services/apexrest/orders/{id}`     | Get order           |
| `POST` | `/services/apexrest/orders`          | Create order        |
| `PUT`  | `/services/apexrest/orders/{id}`     | Update order status |
| `GET`  | `/services/apexrest/deliveries/{id}` | Track delivery      |

---

## Security

The application uses:

* Organization-Wide Defaults
* Role Hierarchy
* Permission Sets
* Sharing Rules
* Field-Level Security
* Experience Cloud Sharing Sets

Roles include:

```text
CEO
 └── Restaurant Operations Manager
      ├── Restaurant Staff
      └── Delivery Partner
```

---

## Experience Cloud

**QuickBite Customer Portal** provides customers with access to:

* Restaurants
* Menu Items
* My Orders
* Order Items
* Delivery information

---

## Local AI Agent

Located in:

```text
scripts/quickbite-agent/
```

The agent uses **Qwen3 4B via Ollama** and connects to Salesforce through REST APIs.

Available tools:

```text
get_menu()
get_order(order_name)
get_delivery(order_name)
```

The agent uses a local FAQ knowledge base and Salesforce data as the source of truth for dynamic order and delivery information.

---

## Project Structure

```text
Food-management-system/
├── force-app/
│   └── main/default/
│       ├── classes/
│       ├── triggers/
│       ├── objects/
│       ├── flows/
│       ├── layouts/
│       ├── permissionsets/
│       ├── tabs/
│       └── applications/
│
├── scripts/
│   └── quickbite-agent/
│       ├── agent.py
│       ├── tools.py
│       ├── salesforce.py
│       ├── knowledge.py
│       ├── config.py
│       └── knowledge/
│           └── faq.md
│
├── docs/
│   └── img/
│
├── sfdx-project.json
└── README.md
```

---

## Technology Stack

**Salesforce:** Apex, SOQL, Flow, Lightning App, Experience Cloud, Reports, Dashboards

**Integration:** Apex REST, Postman, Salesforce CLI

**AI:** Python, Ollama, Qwen3 4B

**Development:** VS Code, Git, GitHub

---

## Setup

### Salesforce

```bash
sf org login web
sf project deploy start --target-org FoodOrderOrg --source-dir force-app
sf apex run test --target-org FoodOrderOrg --test-level RunLocalTests
```

### Local AI Agent

```bash
cd scripts/quickbite-agent
pip install -r requirements.txt
ollama pull qwen3:4b
python agent.py
```

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
