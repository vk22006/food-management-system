"""
QuickBite Customer Support Agent

Interactive CLI chatbot powered by Qwen3 4B (via Ollama) with
Salesforce tool-calling for menu, order, and delivery queries.
"""

from pathlib import Path
from ollama import chat
from tools import get_menu_tool, get_order_tool, get_delivery_tool
import time
import json


# ---------------------------------------------------------------------------
# Knowledge base
# ---------------------------------------------------------------------------

faq_path = Path(__file__).parent / "knowledge" / "faq.md"
faq = faq_path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# System prompt
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = f"""\
You are the QuickBite Customer Support Assistant.

TOOL USAGE:
- Menu or available food questions → call get_menu.
- Order status, items, or total → call get_order with the order number.
- "Where is my order?", delivery progress, or pickup/delivery questions → call get_delivery with the order number.
- Call the appropriate tool immediately. Do not explain which tool you will use.

ACCURACY RULES:
- Salesforce tool results are the authoritative source for order and delivery information.
- Never invent order status, delivery times, preparation times, refund policies, discounts, phone numbers, guarantees, tracking information, or business policies.
- If an order is not found, say it was not found. Do not invent a status.
- Do not infer an order's status from the absence of a delivery record.
- Only say a delivery partner is assigned when deliveryPartnerName or deliveryPartnerId is present in the tool result.
- Treat deliveryStatus "Assigned" as the delivery record state, not proof that a specific partner is assigned.
- All monetary amounts are in INR. Use the ₹ symbol.

RESPONSE STYLE:
- Be concise, friendly, and professional.
- Answer the customer directly.

QUICKBITE KNOWLEDGE BASE:
{faq}
"""


# ---------------------------------------------------------------------------
# Tool definitions (sent to Ollama)
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_menu",
            "description": "Get the current QuickBite menu.",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_order",
            "description": "Get order details (status, items, total) by order number.",
            "parameters": {
                "type": "object",
                "properties": {
                    "order_name": {
                        "type": "string",
                        "description": "Order number, e.g. ORD-00006.",
                    }
                },
                "required": ["order_name"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_delivery",
            "description": "Get delivery status for an order number.",
            "parameters": {
                "type": "object",
                "properties": {
                    "order_name": {
                        "type": "string",
                        "description": "Order number, e.g. ORD-00006.",
                    }
                },
                "required": ["order_name"],
            },
        },
    },
]


# ---------------------------------------------------------------------------
# Instruction injected before the final LLM call (after tool results).
# Sent as a 'user' message so Qwen3 attends to it strongly.
# Removed from history after generation so it doesn't pollute future turns.
# ---------------------------------------------------------------------------

FINAL_ANSWER_INSTRUCTION = (
    "Reply to the customer in 1-2 sentences. "
    "Start your reply directly with the information. "
    "Example: 'Your order ORD-00006 is currently being prepared. "
    "No delivery partner has been assigned yet.'"
)


# ---------------------------------------------------------------------------
# Tool dispatch
# ---------------------------------------------------------------------------

TOOL_DISPATCH = {
    "get_menu": lambda _args: get_menu_tool(),
    "get_order": lambda args: get_order_tool(args["order_name"]),
    "get_delivery": lambda args: get_delivery_tool(args["order_name"]),
}


def execute_tool(tool_name, arguments):
    """Execute a Salesforce tool and return its result as a string."""
    handler = TOOL_DISPATCH.get(tool_name)
    if handler is None:
        return json.dumps({"success": False, "message": f"Unknown tool: {tool_name}"})
    try:
        result = handler(arguments)
        return json.dumps(result, default=str) if not isinstance(result, str) else result
    except Exception as exc:
        return json.dumps({"success": False, "message": f"Tool error: {exc}"})


# ---------------------------------------------------------------------------
# Response cleaning
# ---------------------------------------------------------------------------

# Phrases that indicate the model is dumping its internal reasoning.
_REASONING_PREFIXES = (
    "okay,", "okay ", "let me", "the user", "i need to",
    "i called", "i should", "hmm", "alright,", "alright ",
    "so,", "so ", "based on", "according to", "the response",
    "the tool", "looking at", "let's", "i'll", "wait,",
    "wait ", "i want", "now,", "now ", "first,", "first ",
)

# Keywords that suggest a sentence contains customer-facing content.
_CUSTOMER_KEYWORDS = (
    "ord-", "order", "delivery", "delivered", "preparing",
    "prepared", "accepted", "cancelled", "assigned", "picked up",
    "out for delivery", "pending", "menu", "₹", "inr",
    "not found", "sorry", "your ", "here",
)


def clean_response(text):
    """Strip reasoning preamble that Qwen3 4B sometimes emits despite
    instructions.  Uses two strategies:
    1. Strip leading reasoning lines (prefix check).
    2. If everything was stripped, scan sentences for customer-facing
       content (order numbers, statuses, prices).
    """
    if not text:
        return text

    lines = text.strip().splitlines()

    # --- Strategy 1: strip leading reasoning lines ---
    cleaned = []
    past_preamble = False
    for line in lines:
        stripped = line.strip().lower()
        if not past_preamble and any(stripped.startswith(p) for p in _REASONING_PREFIXES):
            continue
        past_preamble = True
        cleaned.append(line)

    if cleaned:
        return "\n".join(cleaned).strip()

    # --- Strategy 2: extract customer-facing sentences ---
    # Split the entire text into sentences and keep those that contain
    # customer-relevant keywords (order numbers, statuses, prices).
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text.strip())
    useful = [
        s for s in sentences
        if any(kw in s.lower() for kw in _CUSTOMER_KEYWORDS)
    ]
    if useful:
        # Strip reasoning preamble from the start of each sentence.
        # e.g. "I need to state that the order..." → "The order..."
        _STRIP_RE = re.compile(
            r'^(I need to (state|say|mention|tell|note) that\s*'
            r'|I should (state|say|mention|tell|note) that\s*'
            r'|I want to (state|say|mention|tell|note) that\s*)',
            re.IGNORECASE,
        )
        cleaned_sentences = [_STRIP_RE.sub('', s).strip() for s in useful]
        # Capitalize first letter after stripping
        cleaned_sentences = [
            s[0].upper() + s[1:] if s else s for s in cleaned_sentences
        ]
        return " ".join(cleaned_sentences).strip()

    # --- Fallback: return original ---
    return text.strip()


# ---------------------------------------------------------------------------
# Conversation loop
# ---------------------------------------------------------------------------

MODEL = "qwen3:4b"


def main():
    """Interactive CLI chatbot loop."""

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    print("=" * 60)
    print("  QuickBite Customer Support  (type 'exit' or 'quit')")
    print("=" * 60)

    while True:
        # --- Get user input ---------------------------------------------------
        try:
            user_input = input("\nYou: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye!")
            break

        if not user_input:
            continue
        if user_input.lower() in ("exit", "quit"):
            print("Goodbye! Thanks for using QuickBite. 🍔")
            break

        messages.append({"role": "user", "content": user_input})

        turn_start = time.perf_counter()

        # --- Initial LLM call (may request tool calls) -----------------------
        llm_start = time.perf_counter()
        try:
            response = chat(
                model=MODEL,
                messages=messages,
                tools=TOOLS,
                think=False,
                options={"temperature": 0.0, "num_predict": 256},
            )
        except Exception as exc:
            print(f"\n[Error] LLM call failed: {exc}")
            messages.pop()
            continue

        llm_time = time.perf_counter() - llm_start
        print(f"[Timing] Initial LLM: {llm_time:.2f}s")

        # --- Tool-call handling -----------------------------------------------
        if response.message.tool_calls:
            # Append the assistant's tool-call message exactly once
            messages.append(response.message)

            sf_start = time.perf_counter()

            for tool_call in response.message.tool_calls:
                tool_name = tool_call.function.name
                arguments = tool_call.function.arguments or {}

                if tool_name == "get_menu":
                    print(f"\n[Agent] Calling Salesforce: get_menu()")
                else:
                    arg_display = arguments.get("order_name", "")
                    print(f"\n[Agent] Calling Salesforce: {tool_name}({arg_display})")

                result_str = execute_tool(tool_name, arguments)
                messages.append({"role": "tool", "content": result_str})

            sf_time = time.perf_counter() - sf_start
            print(f"[Timing] Salesforce tool: {sf_time:.2f}s")

            # --- Final LLM call (generate customer-facing answer) -------------
            messages.append({"role": "user", "content": FINAL_ANSWER_INSTRUCTION})

            final_start = time.perf_counter()
            try:
                final_response = chat(
                    model=MODEL,
                    messages=messages,
                    think=False,
                    options={"temperature": 0.2, "num_predict": 100},
                )
            except Exception as exc:
                print(f"\n[Error] Final LLM call failed: {exc}")
                messages.pop()
                continue

            final_time = time.perf_counter() - final_start
            print(f"[Timing] Final LLM: {final_time:.2f}s")

            # Remove the temporary instruction, keep the assistant reply
            messages.pop()  # remove FINAL_ANSWER_INSTRUCTION

            answer = clean_response(final_response.message.content)
            messages.append({"role": "assistant", "content": answer})

        else:
            # No tool call — direct answer (FAQ / general question)
            answer = clean_response(response.message.content)
            messages.append({"role": "assistant", "content": answer})

        total_time = time.perf_counter() - turn_start
        print(f"[Timing] Total turn: {total_time:.2f}s")

        print(f"\nQuickBite AI: {answer}")


if __name__ == "__main__":
    main()