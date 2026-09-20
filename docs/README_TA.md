# QuickBite: AI ஒருங்கிணைப்புடன் கூடிய Salesforce உணவு ஆர்டர் மேலாண்மை அமைப்பு

[English](../README.md) | தமிழ் | [简体中文](README_ZH.md) | [हिन्दी](README_HI.md) | [Bahasa Indonesia](README_ID.md)

Salesforce அடிப்படையிலான உணவு விநியோக மேலாண்மை தளம். உணவகங்கள், மெனுக்கள், வாடிக்கையாளர் ஆர்டர்கள், விநியோகங்கள், தானியக்க செயல்முறைகள், அறிக்கைகள், வாடிக்கையாளர் அணுகல், REST API மற்றும் AI உதவியுடன் கூடிய வாடிக்கையாளர் ஆதரவை நிர்வகிக்கிறது.

![screenshot](img/image.png)

---

## அம்சங்கள்

- **உணவகம் மற்றும் மெனு மேலாண்மை** - உணவகங்கள், உணவு வகைகள், மெனு பொருட்கள், விலைகள் மற்றும் கிடைக்கும் நிலை ஆகியவற்றை நிர்வகித்தல்.
- **ஆர்டர் மேலாண்மை** - வாடிக்கையாளர் ஆர்டர்கள், ஆர்டர் பொருட்கள், தானியங்கி மொத்தத் தொகை கணக்கீடு மற்றும் நிலை சரிபார்ப்பு.
- **விநியோக மேலாண்மை** - விநியோக உருவாக்கம், விநியோகப் பணியாளர் ஒதுக்கீடு, நிலை கண்காணிப்பு மற்றும் ஒத்திசைவு.
- **தானியக்கம்** - ஆர்டர்கள், விநியோகங்கள், நிலை மாற்றங்கள் மற்றும் அறிவிப்புகளுக்கான Record-Triggered Flows.
- **Apex மேம்பாடு** - Service Classes, Triggers, வணிக விதிகள் மற்றும் Apex REST Controllers.
- **பாதுகாப்பு** - OWD, Role Hierarchy, Permission Sets, Sharing Rules மற்றும் Field-Level Security.
- **Experience Cloud** - உணவகங்கள், மெனுக்கள், ஆர்டர்கள் மற்றும் விநியோகங்களைப் பார்க்க வாடிக்கையாளர் இணையதளம்.
- **அறிக்கைகள் மற்றும் Dashboard-கள்** - செயல்பாட்டு மற்றும் வருவாய் பகுப்பாய்வு.
- **REST API** - தனிப்பயன் Apex REST Endpoints மூலம் வெளிப்புற அமைப்புகளுடன் ஒருங்கிணைப்பு.
- **Postman** - API சோதனை மற்றும் செயல்முறை விளக்கம்.
- **Local AI ஆதரவு** - FAQ, மெனு, ஆர்டர் மற்றும் விநியோகம் தொடர்பான கேள்விகளுக்கான Qwen3 4B + Ollama AI Agent.

![cli-agent](img/agent.png)

> AI Assistant என்பது Local AI ஒருங்கிணைப்பு ஆகும். இது Salesforce Agentforce அல்ல.

---

## கட்டமைப்பு

![flowchart](img/flowchart.png)

---

## தரவு மாதிரி

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

### முக்கிய Objects

| Object          | பயன்பாடு                    |
| --------------- | --------------------------- |
| `Restaurant__c` | உணவகத் தகவல்கள்             |
| `Menu_Item__c`  | உணவக மெனு பொருட்கள்         |
| `Order__c`      | வாடிக்கையாளர் ஆர்டர்கள்     |
| `Order_Item__c` | ஒரு ஆர்டரில் உள்ள பொருட்கள் |
| `Delivery__c`   | ஆர்டர் விநியோகத் தகவல்கள்   |

---

## ஆர்டர் செயல்முறை

```text
Pending → Accepted → Preparing → Out for Delivery → Delivered
                         \
                          → Cancelled
```

## விநியோக செயல்முறை

```text
Assigned → Picked Up → Out for Delivery → Delivered
```

---

## Apex

முக்கிய Apex கூறுகள்:

* `OrderService` - ஆர்டர் உருவாக்கம், தகவல் பெறுதல், நிலை மாற்றங்கள் மற்றும் வணிக விதிகள்.

* `OrderTotalCalculator` - பல பதிவுகளையும் ஒரே நேரத்தில் கையாளும் வகையில் ஆர்டர் மொத்தத் தொகையை கணக்கிடுதல்.

* `DeliveryChargeCalculator` - விநியோகக் கட்டணத்தை கணக்கிடுதல்.

* `OrderItemTrigger` - Order Items மாற்றப்படும்போது ஆர்டர் மொத்தத் தொகையைப் புதுப்பித்தல்.

* `MenuRestController` - Menu REST API.

* `OrderRestController` - Order REST API.

* `DeliveryRestController` - Delivery REST API.

Apex Tests மூலம் Triggers, Services, கணக்கீடுகள், Validation மற்றும் REST செயல்பாடுகள் சோதிக்கப்படுகின்றன.

---

## REST API

| முறை   | Endpoint                             | பயன்பாடு                      |
| ------ | ------------------------------------ | ----------------------------- |
| `GET`  | `/services/apexrest/menu`            | மெனுவைப் பெறுதல்              |
| `GET`  | `/services/apexrest/orders/{id}`     | ஆர்டர் தகவலைப் பெறுதல்        |
| `POST` | `/services/apexrest/orders`          | புதிய ஆர்டரை உருவாக்குதல்     |
| `PUT`  | `/services/apexrest/orders/{id}`     | ஆர்டர் நிலையைப் புதுப்பித்தல் |
| `GET`  | `/services/apexrest/deliveries/{id}` | விநியோகத்தை கண்காணித்தல்      |

---

## பாதுகாப்பு

இந்த பயன்பாடு பின்வரும் Salesforce பாதுகாப்பு அம்சங்களைப் பயன்படுத்துகிறது:

* Organization-Wide Defaults
* Role Hierarchy
* Permission Sets
* Sharing Rules
* Field-Level Security
* Experience Cloud Sharing Sets

பயன்பாட்டில் உள்ள Roles:

```text
CEO

└── Restaurant Operations Manager
     ├── Restaurant Staff
     └── Delivery Partner
```

---

## Experience Cloud

### **QuickBite Customer Portal**

வாடிக்கையாளர்கள் பின்வரும் தகவல்களை அணுகலாம்:

* Restaurants
* Menu Items
* My Orders
* Order Items
* Delivery Information

---

## Local AI Agent

Agent பின்வரும் இடத்தில் உள்ளது:

```text
scripts/quickbite-agent/
```

இந்த Agent **Qwen3 4B via Ollama**-ஐ பயன்படுத்துகிறது மற்றும் REST API மூலம் Salesforce உடன் இணைகிறது.

கிடைக்கும் Tools:

```text
get_menu()
get_order(order_name)
get_delivery(order_name)
```

Agent ஒரு local FAQ Knowledge Base-ஐ பயன்படுத்துகிறது. மாறிக்கொண்டிருக்கும் ஆர்டர் மற்றும் விநியோகத் தகவல்களுக்கு **Salesforce Data-ஐ உண்மையான தகவல் மூலமாக** பயன்படுத்துகிறது.

இதன் மூலம் Agent போன்ற கேள்விகளுக்கு பதிலளிக்க முடியும்:

```text
"What’s on the menu?"
"What is the status of order ORD-00001?"
"Where is my order ORD-00006?"
"What does 'Pending' mean?"
```

Agent Salesforce-ல் உள்ள உண்மையான தரவைப் பயன்படுத்தி பதிலளிக்கிறது. ஆதாரம் இல்லாத தகவல்களை தானாக உருவாக்குவதற்குப் பதிலாக, பயன்பாட்டின் தரவு மற்றும் FAQ அறிவுத் தளத்தின் அடிப்படையில் பதிலளிக்கும் வகையில் வடிவமைக்கப்பட்டுள்ளது.

---

## திட்ட அமைப்பு

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

## நிறுவல் மற்றும் அமைப்பு

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

## உரிமம்

இந்த திட்டம் **MIT License** கீழ் வெளியிடப்பட்டுள்ளது. கூடுதல் தகவல்களுக்கு [LICENSE](LICENSE) கோப்பைப் பார்க்கவும்.
