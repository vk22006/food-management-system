# QuickBite Customer Support Agent

A local AI-powered customer support chatbot for the **QuickBite Food Order Management System**. It runs entirely on your machine using **Qwen3 4B** (via Ollama) and connects to a **Salesforce** backend for live order, delivery, and menu data.

> **Note:** This is a local Qwen3 4B customer-support agent, **not** Salesforce Agentforce.

---

## Architecture

```
┌─────────────┐        ┌────────────┐        ┌─────────────────┐
│  CLI Chat   │◄──────►│  Qwen3 4B  │◄──────►│  Salesforce Org │
│  (agent.py) │        │  (Ollama)  │        │  (REST / Apex)  │
└─────────────┘        └────────────┘        └─────────────────┘
```

| File             | Purpose                                            |
| ---------------- | -------------------------------------------------- |
| `agent.py`       | Orchestration, conversation loop, LLM interaction  |
| `tools.py`       | LLM-callable tool wrappers for Salesforce          |
| `salesforce.py`  | Salesforce REST API / Apex integration              |
| `knowledge.py`   | Knowledge handling (reserved)                       |
| `config.py`      | Configuration (reserved)                            |
| `knowledge/faq.md` | QuickBite FAQ knowledge base                     |

---

## Requirements

- **Python 3.10+**
- **Ollama** with the `qwen3:4b` model pulled locally
- **Salesforce CLI (`sf`)** authenticated to your Salesforce org (`FoodOrderOrg`)
- Python packages (see `requirements.txt`):
  - `ollama`
  - `requests`
  - `python-dotenv`

---

## Setup

1. **Install Ollama** and pull the model:

   ```bash
   ollama pull qwen3:4b
   ```

2. **Authenticate Salesforce CLI:**

   ```bash
   sf org login web --alias FoodOrderOrg
   ```

3. **Install Python dependencies:**

   ```bash
   cd scripts/quickbite-agent
   pip install -r requirements.txt
   ```

4. **(Optional)** Copy `.env.example` to `.env` and configure as needed.

---

## How to Run

```bash
python agent.py
```

The agent starts an interactive CLI session. Type your questions and press Enter. Type `exit` or `quit` to end the session.

---

## Available Tools

The agent can call three Salesforce tools. Qwen3 4B decides which tool to use based on the customer's question.

| Tool            | Trigger                                        | Salesforce Endpoint         |
| --------------- | ---------------------------------------------- | --------------------------- |
| `get_menu`      | Menu or available food questions               | `GET /services/apexrest/menu` |
| `get_order`     | Order status, items, total, details            | `GET /services/apexrest/orders/{id}` |
| `get_delivery`  | "Where is my order?", delivery progress        | `GET /services/apexrest/deliveries/{id}` |

---

## FAQ Knowledge Base

The file `knowledge/faq.md` is loaded into the system prompt so the agent can answer general QuickBite questions without calling Salesforce:

- Order status definitions (Pending, Accepted, Preparing, Out for Delivery, Delivered, Cancelled)
- Delivery status definitions (Assigned, Picked Up, Out for Delivery, Delivered)
- Currency (INR / ₹)
- Support policy guardrails

---

## Salesforce REST Integration

The agent authenticates to Salesforce using the **Salesforce CLI** (`sf`):

1. `sf org display` retrieves the instance URL.
2. `sf org auth show-access-token` retrieves a fresh access token.
3. The agent then calls Apex REST endpoints for menu, order, and delivery data.

No credentials are stored in source code. Authentication is handled entirely through the Salesforce CLI's existing session.

---

## Example Conversations

### Menu Query

```
You: What's on the menu?

[Agent] Calling Salesforce: get_menu()

QuickBite AI: Here's what's available on QuickBite right now:
- Margherita Pizza — ₹250
- Chicken Biryani — ₹180
- Paneer Butter Masala — ₹200
...
```

### Order Status

```
You: What's the status of ORD-00006?

[Agent] Calling Salesforce: get_order(ORD-00006)

QuickBite AI: Your order ORD-00006 is currently being prepared by the restaurant.
```

### Multi-Turn Follow-Up

```
You: What's the status of ORD-00006?

QuickBite AI: Your order ORD-00006 is currently being prepared.

You: What did I order?

QuickBite AI: Your order ORD-00006 contains:
- 2× Chicken Biryani — ₹360
- 1× Masala Dosa — ₹120
Total: ₹480

You: Where is it?

QuickBite AI: Your order ORD-00006 has been picked up and is out for delivery.
```

### Unknown Order

```
You: Where is ORD-99999?

[Agent] Calling Salesforce: get_delivery(ORD-99999)

QuickBite AI: Sorry, order ORD-99999 was not found. Please check the order number and try again.
```

### FAQ Question (No Salesforce Call)

```
You: What does "Preparing" status mean?

QuickBite AI: "Preparing" means the restaurant has started making your order.
```

---

## Accuracy Guardrails

- Salesforce results are the single source of truth for customer data.
- The agent never invents order statuses, delivery times, refund policies, or phone numbers.
- If an order is not found, it says so — it does not fabricate a status.
- A delivery partner is only mentioned when `deliveryPartnerName` is present in the Salesforce response.

---

## Project Notes

- **Model:** Qwen3 4B running locally via Ollama.
- **Timing instrumentation** is included for later latency optimization.
- `config.py` and `knowledge.py` are reserved for future expansion.
- No `.env` files or secrets are committed to version control.
