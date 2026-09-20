# QuickBite：基于 Salesforce 的食品订单管理系统与 AI 集成

[English](../README.md) | [தமிழ்](README_TA.md) | 简体中文

一个基于 Salesforce 的食品配送管理平台，用于管理餐厅、菜单、客户订单、配送、自动化流程、报表、客户访问、REST API 以及 AI 辅助服务。

![screenshot](img/image.png)

---

## 功能特性

- **餐厅与菜单管理** - 管理餐厅、菜系、菜单项、价格和供应状态。
- **订单管理** - 管理客户订单、订单项、自动计算订单总额以及订单状态验证。
- **配送管理** - 创建配送记录、分配配送员、跟踪配送状态以及进行数据同步。
- **自动化** - 使用记录触发的 Flow 实现订单、配送、状态更新和通知等自动化流程。
- **Apex 开发** - 包括服务类、触发器、业务逻辑和 Apex REST 控制器。
- **安全性** - 使用 OWD、角色层级、权限集、共享规则和字段级安全控制。
- **Experience Cloud** - 为客户提供浏览餐厅、菜单、订单和配送信息的客户门户。
- **报表与 Dashboard** - 提供运营和收入分析。
- **REST API** - 通过自定义 Apex REST Endpoint 与外部系统进行集成。
- **Postman** - 用于 API 测试和演示。
- **本地 AI 支持** - 使用 Qwen3 4B + Ollama Agent 处理 FAQ、菜单、订单和配送相关查询。

![cli-agent](img/agent.png)

> AI 助手是一个本地 AI 集成，并非 Salesforce Agentforce。

---

## 系统架构

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

## 数据模型

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

### 核心对象

| Object          | 用途     |
| --------------- | ------ |
| `Restaurant__c` | 餐厅信息   |
| `Menu_Item__c`  | 餐厅菜单项  |
| `Order__c`      | 客户订单   |
| `Order_Item__c` | 订单中的商品 |
| `Delivery__c`   | 订单配送信息 |

---

## 订单生命周期

```text
Pending → Accepted → Preparing → Out for Delivery → Delivered
                  \
                   → Cancelled
```

## 配送生命周期

```text
Assigned → Picked Up → Out for Delivery → Delivered
```

---

## Apex

主要 Apex 组件：

* `OrderService` - 负责订单创建、查询、状态更新和业务逻辑。

* `OrderTotalCalculator` - 以 Bulkified 方式计算订单总额。

* `DeliveryChargeCalculator` - 计算配送费用。

* `OrderItemTrigger` - 当订单项发生变化时维护订单总额。

* `MenuRestController` - 菜单 REST API。

* `OrderRestController` - 订单 REST API。

* `DeliveryRestController` - 配送 REST API。

Apex Tests 覆盖触发器、服务类、计算逻辑、验证规则以及 REST 功能。

---

## REST API

| Method | Endpoint                             | 用途     |
| ------ | ------------------------------------ | ------ |
| `GET`  | `/services/apexrest/menu`            | 获取菜单   |
| `GET`  | `/services/apexrest/orders/{id}`     | 获取订单   |
| `POST` | `/services/apexrest/orders`          | 创建订单   |
| `PUT`  | `/services/apexrest/orders/{id}`     | 更新订单状态 |
| `GET`  | `/services/apexrest/deliveries/{id}` | 跟踪配送   |

---

## 安全性

该应用使用以下 Salesforce 安全机制：

* Organization-Wide Defaults
* Role Hierarchy
* Permission Sets
* Sharing Rules
* Field-Level Security
* Experience Cloud Sharing Sets

角色包括：

```text
CEO
 └── Restaurant Operations Manager
      ├── Restaurant Staff
      └── Delivery Partner
```

---

## Experience Cloud

**QuickBite Customer Portal** 为客户提供以下访问内容：

* Restaurants
* Menu Items
* My Orders
* Order Items
* Delivery Information

---

## 本地 AI Agent

Agent 位于：

```text
scripts/quickbite-agent/
```

该 Agent 使用 **Qwen3 4B via Ollama**，并通过 REST API 连接 Salesforce。

可用 Tools：

```text
get_menu()
get_order(order_name)
get_delivery(order_name)
```

Agent 使用本地 FAQ 知识库以及 Salesforce 数据。对于动态的订单和配送信息，**Salesforce 数据作为事实来源（source of truth）**。

例如，Agent 可以回答：

```text
"What’s on the menu?"
"What is the status of order ORD-00001?"
"Where is my order ORD-00006?"
"What does 'Pending' mean?"
```

Agent 根据 Salesforce 中实际存在的数据以及 FAQ 知识库生成回答，而不是在缺少依据时自行假设或生成未经支持的信息。

---

## 项目结构

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

## 技术栈

**Salesforce：** Apex、SOQL、Flow、Lightning App、Experience Cloud、Reports、Dashboards

**集成：** Apex REST、Postman、Salesforce CLI

**AI：** Python、Ollama、Qwen3 4B

**开发工具：** VS Code、Git、GitHub

---

## 安装与配置

### Salesforce

```bash
sf org login web
sf project deploy start --target-org FoodOrderOrg --source-dir force-app
sf apex run test --target-org FoodOrderOrg --test-level RunLocalTests
```

### 本地 AI Agent

```bash
cd scripts/quickbite-agent
pip install -r requirements.txt
ollama pull qwen3:4b
python agent.py
```

---

## 许可证

本项目采用 **MIT License** 许可证。详情请参阅 [LICENSE](LICENSE) 文件。
