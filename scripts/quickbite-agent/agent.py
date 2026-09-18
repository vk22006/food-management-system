from pathlib import Path
from ollama import chat
from tools import (
    get_menu_tool,
    get_order_tool,
    get_delivery_tool
)


# Load QuickBite knowledge base
faq_path = Path(__file__).parent / "knowledge" / "faq.md"
faq = faq_path.read_text(encoding="utf-8")


system_prompt = f"""
You are the QuickBite Customer Support Assistant.

Your job is to answer customer questions about QuickBite.

Use the QuickBite knowledge base below as the source of truth.

Do not invent:
- delivery times
- preparation times
- phone numbers
- refund policies
- discounts
- guarantees
- tracking information
- business policies
- facts about a customer's order

All QuickBite monetary amounts are in Indian Rupees (INR).
When displaying prices or monetary amounts, use the ₹ symbol.

If information about the customer's actual order is required, use an
available Salesforce tool rather than guessing.

Keep responses concise, friendly, and suitable for customer support.

QUICKBITE KNOWLEDGE BASE:
-------------------------
{faq}
-------------------------
"""


tools = [
    {
        "type": "function",
        "function": {
            "name": "get_menu",
            "description": "Get the current QuickBite menu from Salesforce. Use this when the customer asks about available food, menu items, or what they can order.",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_order",
            "description": (
                "Look up a QuickBite customer's order using its order number, "
                "such as ORD-00006. Use this when the customer asks about their "
                "order status, order details, items, total, or delivery."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "order_name": {
                        "type": "string",
                        "description": "The QuickBite order number, such as ORD-00006."
                    }
                },
                "required": ["order_name"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_delivery",
            "description": (
                "Get the current delivery status for a QuickBite order. "
                "Use this when the customer asks where their order is, "
                "whether it has been picked up, or about delivery progress."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "order_name": {
                        "type": "string",
                        "description": "The QuickBite order number, such as ORD-00006."
                    }
                },
                "required": ["order_name"]
            }
        }
    }    
]


messages = [
    {
        "role": "system",
        "content": system_prompt
    },
    {
        "role": "user",
        "content": "Tell me about ORD-00006"
    }
]


response = chat(
    model="qwen3:4b",
    messages=messages,
    tools=tools
)

if response.message.tool_calls:
    for tool_call in response.message.tool_calls:

        tool_name = tool_call.function.name

        if tool_name == "get_menu":
            print("\n[Agent] Calling Salesforce: get_menu()")
            result = get_menu_tool()

        elif tool_name == "get_order":
            order_name = tool_call.function.arguments["order_name"]

            print(
                f"\n[Agent] Calling Salesforce: "
                f"get_order({order_name})"
            )

            result = get_order_tool(order_name)

        elif tool_name == "get_delivery":
            order_name = tool_call.function.arguments["order_name"]

            print(
                f"\n[Agent] Calling Salesforce: "
                f"get_delivery({order_name})"
            )

            result = get_delivery_tool(order_name)

        else:
            result = {
                "success": False,
                "message": f"Unknown tool: {tool_name}"
            }

        messages.append(response.message)

        messages.append(
            {
                "role": "tool",
                "content": str(result)
            }
        )

    final_response = chat(
        model="qwen3:4b",
        messages=messages
    )

    print("\nQuickBite AI:")
    print(final_response.message.content)

else:
    print("\nQuickBite AI:")
    print(response.message.content)