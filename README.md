# QuickBite Food Order Management System

A Salesforce-based food delivery management platform for managing restaurants, menu items, customer orders, order items, deliveries, notifications, reporting, customer access, REST integrations, and AI-assisted customer support.

The project demonstrates Salesforce declarative development, Apex programming, automation, security and sharing, Experience Cloud, REST API integration, Postman testing, reporting, dashboards, and a local AI customer-support agent.

---

## Overview

QuickBite is designed around a typical food-delivery workflow involving four primary actors:

- **Customer** - browses restaurants and menu items, places orders, and tracks deliveries.
- **Restaurant Staff** - manages incoming orders and updates preparation status.
- **Delivery Partner** - accesses assigned deliveries and updates delivery progress.
- **Administrator / Operations Manager** - manages restaurants, menus, orders, deliveries, security, and reporting.

The system combines Salesforce declarative and programmatic capabilities to provide an end-to-end food order management platform.

---

## Key Features

### Restaurant & Menu Management

- Restaurant management
- Cuisine and address information
- Menu item management
- Menu availability
- Restaurant-to-menu-item relationships
- Customer-facing restaurant and menu browsing

### Order Management

- Auto-numbered orders
- Customer association
- Order date/time tracking
- Order lifecycle management
- Order item management
- Automatic order total calculation
- Order status validation
- Order history through Experience Cloud

### Delivery Management

- Delivery record creation
- Delivery partner assignment
- Delivery lifecycle tracking
- Delivery status synchronization
- Delivery tracking through REST API
- Customer delivery visibility

### Automation

Salesforce Flows automate key operational processes including:

- Order creation
- Delivery creation
- Order status transitions
- Delivery status synchronization
- Delivery partner assignment
- Customer notifications
- Restaurant staff notifications
- Delivery partner notifications

### Apex Development

The project includes Apex services, REST controllers, triggers, and automated tests.

### Reporting & Analytics

The system includes reports for:

- Orders by status
- Order revenue
- Menu item sales
- Delivery status
- Order item quantity and revenue

A dedicated dashboard provides an operational overview of the food delivery system.

### Security

The project implements Salesforce security using:

- Organization-Wide Defaults
- Role hierarchy
- Permission Sets
- Sharing Rules
- Field-Level Security
- Experience Cloud Sharing Sets

Different access levels are provided for:

- Restaurant Staff
- Delivery Partners
- Restaurant Operations Managers
- Customers

### Experience Cloud

A customer portal allows external customers to:

- Browse restaurants
- Browse menu items
- View their orders
- View order details
- View order items
- View delivery information

### REST API

Custom Apex REST endpoints provide integration with external applications.

### Postman Integration

Postman is used to demonstrate and test the QuickBite REST API.

### Local AI Customer Support

A local AI assistant powered by **Qwen3 4B** through Ollama provides customer-support functionality.

The assistant can:

- Answer QuickBite FAQs
- Retrieve the current menu
- Retrieve order information
- Retrieve delivery information
- Answer customer questions using Salesforce data
- Maintain conversational context

The AI assistant communicates with Salesforce through the project's REST APIs.

> **Note:** The local AI assistant is an external/local AI integration and is not Salesforce Agentforce.

---

# System Architecture

```text
                         QUICKBITE
                             |
             +---------------+---------------+
             |               |               |
       Salesforce        Experience       External
        Platform            Cloud         Integrations
             |               |               |
     +-------+-------+       |          +----+----+
     |       |       |       |          |         |
   Flow    Apex   Security   |       Postman    AI Agent
     |       |       |       |          |         |
     +-------+-------+       |          |       Qwen3 4B
             |               |          |         |
             +---------------+----------+---------+
                             |
                      Salesforce Data
````

---

# Data Model

The core Salesforce data model consists of five custom objects.

```text
                         Contact
                           |
                           | Customer
                           v
                       +--------+
                       | Order  |
                       +--------+
                           |
                    Master-Detail
                           |
                           v
                    +-------------+
                    | Order Item  |
                    +-------------+

Restaurant
    |
    | Master-Detail
    v
Menu Item


Order
    |
    | Master-Detail
    v
Delivery
    |
    | Lookup
    v
Contact
(Delivery Partner)
```

## Objects

### Restaurant__c

Stores restaurant information.

Key fields:

* Name
* Address
* Cuisine

---

### Menu_Item__c

Stores menu items belonging to restaurants.

Key fields:

* Name
* Category
* Price
* Availability
* Restaurant

Relationship:

```text
Restaurant → Menu Item
Master-Detail
```

---

### Order__c

Stores customer orders.

Key fields:

* Order Number
* Customer
* Order Date
* Status
* Total Amount

Order numbers use the format:

```text
ORD-00000
```

Relationship:

```text
Contact → Order
Lookup
```

---

### Order_Item__c

Stores individual items belonging to an order.

Key fields:

* Order Item Name
* Product Name
* Quantity
* Price
* Line Total
* Order

Relationship:

```text
Order → Order Item
Master-Detail
```

Line totals are calculated automatically from:

```text
Quantity × Price
```

---

### Delivery__c

Stores delivery information associated with an order.

Key fields:

* Delivery Name
* Delivery Partner
* Status
* Delivery Date
* Order

Relationships:

```text
Order → Delivery
Master-Detail

Contact → Delivery
Lookup
```

---

# Order Lifecycle

The order lifecycle is controlled through validation and automation.

```text
Pending
   ↓
Accepted
   ↓
Preparing
   ↓
Out for Delivery
   ↓
Delivered
```

An order may also transition to:

```text
Cancelled
```

The system prevents invalid status transitions through Salesforce validation rules.

---

# Delivery Lifecycle

Delivery records follow a separate lifecycle:

```text
Assigned
   ↓
Picked Up
   ↓
Out for Delivery
   ↓
Delivered
```

Delivery status is maintained separately from order status.

The system does not assume that a delivery partner is assigned merely because a delivery record has an `Assigned` status. Partner information is based on the actual delivery partner fields.

---

# Salesforce Automation

Salesforce Flow is used for declarative automation.

Major automation areas include:

### Order Automation

* Order creation processing
* Order status handling
* Customer notifications
* Restaurant staff notifications

### Delivery Automation

* Automatic delivery creation
* Delivery partner assignment
* Delivery status synchronization
* Delivery partner notifications

### Notifications

Notifications are provided to relevant users based on operational events.

Examples include:

* New order notification to restaurant staff
* Order preparation notification
* Customer order status notification
* Delivery partner assignment notification

---

# Apex Architecture

The programmatic layer follows a service-oriented approach.

## OrderService

Responsible for order-related business operations including:

* Creating orders
* Creating order items
* Updating order status
* Retrieving order details
* Calculating delivery charges
* Returning structured order information

---

## OrderTotalCalculator

Calculates order totals from related order items.

The implementation is bulkified and aggregates order item values in Apex rather than performing SOQL or DML operations inside loops.

---

## DeliveryChargeCalculator

Calculates delivery charges based on order subtotal.

The current implementation uses a base delivery charge and percentage-based calculation.

---

## REST Controllers

The project exposes custom Apex REST endpoints for external integrations.

### MenuRestController

Provides menu information.

```text
GET /services/apexrest/menu
```

### OrderRestController

Provides order operations.

```text
GET  /services/apexrest/orders/{orderId}
POST /services/apexrest/orders
PUT  /services/apexrest/orders/{orderId}
```

### DeliveryRestController

Provides delivery tracking.

```text
GET /services/apexrest/deliveries/{deliveryId}
```

---

# Apex Trigger

The project uses an Order Item trigger to maintain calculated order totals.

```text
Order Item
    |
    v
OrderItemTrigger
    |
    v
OrderTotalCalculator
    |
    v
Order Total
```

The implementation handles bulk operations and order-item reparenting scenarios.

---

# Testing

Apex tests cover the major programmatic components of the system.

Testing includes:

* Order total calculations
* Order item creation
* Order item updates
* Order item deletion
* Order reparenting
* Trigger behavior
* Order service functionality
* REST controller behavior
* Delivery calculations
* Validation behavior
* Governor-limit-aware implementation

A dedicated `OrderItemTriggerTest` validates the order-total trigger functionality.

---

# Security Model

The system uses Salesforce's declarative security model.

## Organization-Wide Defaults

| Object     | Access               |
| ---------- | -------------------- |
| Restaurant | Public Read Only     |
| Menu Item  | Controlled by Parent |
| Order      | Private              |
| Order Item | Controlled by Parent |
| Delivery   | Controlled by Parent |

---

## Role Hierarchy

```text
CEO
 |
 └── Restaurant Operations Manager
       |
       +── Restaurant Staff
       |
       └── Delivery Partner
```

---

## Permission Sets

### Restaurant Staff Access

Provides access to:

* Restaurants
* Menu Items
* Orders
* Order Items
* Deliveries

with permissions appropriate for restaurant operations.

### Delivery Partner Access

Provides access primarily to:

* Orders
* Order Items
* Deliveries

with delivery-specific editing permissions.

### Restaurant Operations Manager Access

Provides operational access to:

* Restaurants
* Menu Items
* Orders
* Order Items
* Deliveries

High-risk permissions such as Modify All and View All are intentionally not granted.

---

# Experience Cloud

The project includes a customer-facing Experience Cloud site:

**QuickBite Customer Portal**

The portal provides:

```text
Home
 |
 +-- Restaurants
 |
 +-- Menu Items
 |
 +-- My Orders
       |
       +-- Order Details
              |
              +-- Order Items
              |
              +-- Deliveries
```

Customer access is controlled using:

* Custom external profile
* Permission Set
* Sharing Set

The customer sharing configuration maps the authenticated external user's Contact to the `Order.Customer__c` field.

---

# REST API Integration

The QuickBite REST API can be consumed by external applications.

Example API operations:

```text
GET Menu
GET Order
POST Create Order
PUT Update Order Status
GET Track Delivery
```

Example workflow:

```text
External Application
        |
        v
Salesforce REST API
        |
        v
Apex REST Controller
        |
        v
OrderService / Salesforce Data
```

---

# Postman

The REST API is tested using a dedicated Postman collection.

Collection:

```text
QuickBite Food Order Management API
```

Requests include:

```text
GET  Get Menu
GET  Get Order
POST Create Order
PUT  Update Order Status
GET  Track Delivery
```

The API uses Salesforce Bearer authentication.

---

# Local AI Customer Support Agent

The project includes a local AI assistant located at:

```text
scripts/quickbite-agent/
```

Architecture:

```text
Customer
   |
   v
QuickBite AI
   |
   v
Qwen3 4B
   |
   +------------------+
   |                  |
 FAQ Knowledge     Salesforce Tools
                       |
             +---------+---------+
             |         |         |
          get_menu  get_order  get_delivery
             |         |         |
             +---------+---------+
                       |
                       v
                 Salesforce REST
```

## AI Tools

### get_menu()

Retrieves the current QuickBite menu from Salesforce.

### get_order(order_name)

Retrieves information about a specific order, including:

* Order status
* Items
* Quantities
* Prices
* Subtotal
* Delivery charge
* Grand total
* Delivery information

### get_delivery(order_name)

Retrieves delivery information including:

* Delivery status
* Order status
* Delivery partner information
* Delivery date
* Delivery charge
* Order total

---

# AI Knowledge Base

General QuickBite information is stored in:

```text
scripts/quickbite-agent/knowledge/faq.md
```

The knowledge base provides information such as:

* Order statuses
* Delivery statuses
* Currency
* Customer-support rules

The assistant is instructed not to invent undocumented business policies or customer/order information.

---

# Project Structure

```text
Food-management-system/
│
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/
│           ├── triggers/
│           ├── objects/
│           ├── flows/
│           ├── layouts/
│           ├── permissionsets/
│           ├── tabs/
│           ├── applications/
│           └── ...
│
├── scripts/
│   └── quickbite-agent/
│       ├── agent.py
│       ├── tools.py
│       ├── salesforce.py
│       ├── knowledge.py
│       ├── config.py
│       ├── knowledge/
│       │   └── faq.md
│       ├── requirements.txt
│       ├── .env.example
│       ├── .gitignore
│       └── README.md
│
├── sfdx-project.json
├── README.md
└── .gitignore
```

---

# Technology Stack

## Salesforce

* Salesforce Platform
* Lightning App
* Custom Objects
* Custom Fields
* Record-Triggered Flows
* Validation Rules
* Permission Sets
* Sharing Rules
* Role Hierarchy
* Apex
* SOQL
* Apex REST
* Reports
* Dashboards
* Experience Cloud

## Development & Integration

* Salesforce CLI
* Visual Studio Code
* Salesforce Extension Pack
* Postman
* Git
* GitHub

## AI

* Python
* Ollama
* Qwen3 4B
* Local FAQ knowledge base
* Salesforce REST API

---

# Example Workflow

A typical order workflow looks like:

```text
Customer places order
        |
        v
Order created as Pending
        |
        v
Restaurant accepts order
        |
        v
Order → Accepted
        |
        v
Delivery record created
        |
        v
Restaurant prepares order
        |
        v
Order → Preparing
        |
        v
Order → Out for Delivery
        |
        v
Delivery → Out for Delivery
        |
        v
Order → Delivered
        |
        v
Delivery → Delivered
```

Throughout the process:

* Salesforce Flow automates operational changes.
* Notifications inform relevant users.
* Apex maintains calculated values and API operations.
* Reports and dashboards provide operational visibility.
* Experience Cloud exposes customer-facing information.
* The local AI agent can retrieve current information through Salesforce REST APIs.

---

# Setup

## Salesforce

Authenticate the target Salesforce org:

```bash
sf org login web
```

Deploy the project:

```bash
sf project deploy start --target-org FoodOrderOrg --source-dir force-app
```

Run Apex tests:

```bash
sf apex run test --target-org FoodOrderOrg --test-level RunLocalTests
```

---

## Local AI Agent

Install Python dependencies:

```bash
cd scripts/quickbite-agent
pip install -r requirements.txt
```

Install and run Ollama with the Qwen3 4B model:

```bash
ollama pull qwen3:4b
```

Authenticate Salesforce CLI:

```bash
sf org login web
```

Verify the org:

```bash
sf org display --target-org FoodOrderOrg
```

Start the agent:

```bash
python agent.py
```

---

# Example AI Conversations

### Menu

```text
User:
What food is currently available?

QuickBite AI:
Burger Barn:
- Classic Burger
- French Fries

Dragon Wok:
- Spring Rolls
- Veg Hakka Noodles

Spice Garden:
- Garlic Naan
- Paneer Butter Masala
```

### Order Status

```text
User:
What's the status of ORD-00006?

QuickBite AI:
Your order ORD-00006 is currently Accepted.
The restaurant has accepted your order and will begin preparing it.
```

### Delivery

```text
User:
Where is my order ORD-00006?

QuickBite AI:
Your order ORD-00006 is currently being prepared by the restaurant.
No delivery partner has been confirmed yet.
```

### Unknown Order

```text
User:
Where is my order ORD-99999?

QuickBite AI:
The order ORD-99999 was not found in our system.
```

---

# Design Principles

The project follows several implementation principles:

### Declarative First

Salesforce Flow and configuration are used where appropriate before introducing custom Apex.

### Bulkification

Apex logic avoids SOQL and DML operations inside loops and is designed to handle bulk records.

### Separation of Concerns

Business logic, REST controllers, triggers, and external integrations are separated into dedicated components.

### Least Privilege

Security permissions are granted according to user responsibilities rather than providing unrestricted access.

### API-First Integration

External applications communicate with Salesforce through documented REST endpoints.

### AI Grounding

The local AI assistant uses Salesforce as the authoritative source for dynamic customer/order information and a controlled FAQ for static information.

---

# Future Improvements

Potential future enhancements include:

* Real-time delivery location tracking
* Customer order cancellation workflow
* Payment integration
* Restaurant-specific access filtering
* Advanced delivery assignment logic
* Customer support ticket creation
* AI-powered order recommendations
* AI-assisted restaurant operations
* Additional conversational tools
* More comprehensive automated integration testing
* Production-grade AI deployment

---

# Project Status

The core QuickBite Salesforce platform includes:

* Data model
* Salesforce automation
* Apex services
* Apex triggers
* Validation rules
* Notifications
* Security and sharing
* Reports
* Dashboard
* Experience Cloud
* REST API
* Postman integration
* Local AI customer-support integration

The system is designed as a demonstration of an end-to-end Salesforce application combining declarative configuration, programmatic development, external integration, customer experience, analytics, and local AI capabilities.

---

## License

This project uses MIT License. Refer [LICENSE](LICENSE) for more details.
