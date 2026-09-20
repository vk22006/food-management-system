````markdown
# QuickBite: AI एकीकरण के साथ Salesforce खाद्य ऑर्डर प्रबंधन प्रणाली

[English](../README.md) | [தமிழ்](README_TA.md) | [简体中文](README_ZH.md) | हिन्दी

Salesforce पर आधारित खाद्य वितरण प्रबंधन प्लेटफ़ॉर्म, जो रेस्तराँ, मेनू, ग्राहक ऑर्डर, डिलीवरी, स्वचालन, रिपोर्टिंग, ग्राहक पहुँच, REST APIs और AI-सहायित सहायता को प्रबंधित करता है।

![screenshot](img/image.png)

---

## विशेषताएँ

- **रेस्तराँ और मेनू प्रबंधन** - रेस्तराँ, व्यंजन, मेनू आइटम, कीमत और उपलब्धता का प्रबंधन।

- **ऑर्डर प्रबंधन** - ग्राहक ऑर्डर, ऑर्डर आइटम, स्वचालित कुल राशि और स्टेटस सत्यापन।

- **डिलीवरी प्रबंधन** - डिलीवरी निर्माण, डिलीवरी पार्टनर असाइनमेंट, स्टेटस ट्रैकिंग और सिंक्रोनाइज़ेशन।

- **स्वचालन** - ऑर्डर, डिलीवरी, स्टेटस अपडेट और सूचनाओं के लिए Record-Triggered Flows।

- **Apex विकास** - Service Classes, Triggers, व्यावसायिक लॉजिक और Apex REST Controllers।

- **सुरक्षा** - OWD, Role Hierarchy, Permission Sets, Sharing Rules और Field-Level Security।

- **Experience Cloud** - रेस्तराँ, मेनू, ऑर्डर और डिलीवरी ब्राउज़ करने के लिए ग्राहक पोर्टल।

- **रिपोर्ट और Dashboards** - परिचालन और राजस्व संबंधी विश्लेषण।

- **REST API** - कस्टम Apex REST Endpoints के माध्यम से बाहरी सिस्टम के साथ एकीकरण।

- **Postman** - API परीक्षण और प्रदर्शन।

- **स्थानीय AI सहायता** - FAQ, मेनू, ऑर्डर और डिलीवरी से संबंधित प्रश्नों के लिए Qwen3 4B + Ollama Agent।

![cli-agent](img/agent.png)

> AI Assistant एक स्थानीय AI एकीकरण है और Salesforce Agentforce नहीं है।

---

## आर्किटेक्चर

![flowchart](img/flowchart.png)

---

## डेटा मॉडल

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

### मुख्य Objects

| Object          | उद्देश्य                         |
| --------------- | -------------------------------- |
| `Restaurant__c` | रेस्तराँ की जानकारी              |
| `Menu_Item__c`  | रेस्तराँ के मेनू आइटम            |
| `Order__c`      | ग्राहक ऑर्डर                     |
| `Order_Item__c` | किसी ऑर्डर में शामिल आइटम        |
| `Delivery__c`   | ऑर्डर से संबंधित डिलीवरी जानकारी |

---

## ऑर्डर जीवनचक्र

```text
Pending → Accepted → Preparing → Out for Delivery → Delivered
                  \
                   → Cancelled
```

## डिलीवरी जीवनचक्र

```text
Assigned → Picked Up → Out for Delivery → Delivered
```

---

## Apex

मुख्य Apex Components:

* `OrderService` - ऑर्डर बनाना, प्राप्त करना, स्टेटस अपडेट करना और व्यावसायिक लॉजिक।

* `OrderTotalCalculator` - Bulkified तरीके से ऑर्डर की कुल राशि की गणना।

* `DeliveryChargeCalculator` - डिलीवरी शुल्क की गणना।

* `OrderItemTrigger` - ऑर्डर आइटम में बदलाव होने पर ऑर्डर की कुल राशि को अपडेट करता है।

* `MenuRestController` - Menu REST API।

* `OrderRestController` - Order REST API।

* `DeliveryRestController` - Delivery REST API।

Apex Tests द्वारा Triggers, Services, गणनाओं, Validation और REST functionality का परीक्षण किया जाता है।

---

## REST API

| Method | Endpoint                             | उद्देश्य                |
| ------ | ------------------------------------ | ----------------------- |
| `GET`  | `/services/apexrest/menu`            | मेनू प्राप्त करना       |
| `GET`  | `/services/apexrest/orders/{id}`     | ऑर्डर प्राप्त करना      |
| `POST` | `/services/apexrest/orders`          | नया ऑर्डर बनाना         |
| `PUT`  | `/services/apexrest/orders/{id}`     | ऑर्डर स्टेटस अपडेट करना |
| `GET`  | `/services/apexrest/deliveries/{id}` | डिलीवरी ट्रैक करना      |

---

## सुरक्षा

एप्लिकेशन निम्नलिखित Salesforce सुरक्षा सुविधाओं का उपयोग करता है:

* Organization-Wide Defaults
* Role Hierarchy
* Permission Sets
* Sharing Rules
* Field-Level Security
* Experience Cloud Sharing Sets

Roles में शामिल हैं:

```text
CEO
 └── Restaurant Operations Manager
      ├── Restaurant Staff
      └── Delivery Partner
```

---

## Experience Cloud

**QuickBite Customer Portal** ग्राहकों को निम्नलिखित तक पहुँच प्रदान करता है:

* Restaurants
* Menu Items
* My Orders
* Order Items
* Delivery Information

---

## स्थानीय AI Agent

Agent यहाँ स्थित है:

```text
scripts/quickbite-agent/
```

Agent **Qwen3 4B via Ollama** का उपयोग करता है और REST APIs के माध्यम से Salesforce से जुड़ता है।

उपलब्ध Tools:

```text
get_menu()
get_order(order_name)
get_delivery(order_name)
```

Agent एक स्थानीय FAQ Knowledge Base और Salesforce Data का उपयोग करता है। ऑर्डर और डिलीवरी की गतिशील जानकारी के लिए Salesforce को **सत्य का स्रोत (source of truth)** माना जाता है।

Agent इस प्रकार के प्रश्नों का उत्तर दे सकता है:

```text
"What’s on the menu?"

"What is the status of order ORD-00001?"

"Where is my order ORD-00006?"

"What does 'Pending' mean?"
```

Agent Salesforce में उपलब्ध वास्तविक डेटा के आधार पर उत्तर देता है और बिना आधार के जानकारी मानने या गढ़ने के बजाय उपलब्ध Salesforce Data तथा FAQ Knowledge Base पर निर्भर करता है।

---

## प्रोजेक्ट संरचना

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

## तकनीकी स्टैक

**Salesforce:** Apex, SOQL, Flow, Lightning App, Experience Cloud, Reports, Dashboards

**Integration:** Apex REST, Postman, Salesforce CLI

**AI:** Python, Ollama, Qwen3 4B

**Development:** VS Code, Git, GitHub

---

## सेटअप

### Salesforce

```bash
sf org login web
sf project deploy start --target-org FoodOrderOrg --source-dir force-app
sf apex run test --target-org FoodOrderOrg --test-level RunLocalTests
```

### स्थानीय AI Agent

```bash
cd scripts/quickbite-agent
pip install -r requirements.txt
ollama pull qwen3:4b
python agent.py
```

---

## लाइसेंस

यह प्रोजेक्ट **MIT License** के अंतर्गत लाइसेंस प्राप्त है। अधिक जानकारी के लिए [LICENSE](LICENSE) फ़ाइल देखें।

```
```
