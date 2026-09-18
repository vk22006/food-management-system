from pathlib import Path
from ollama import chat


# Load QuickBite knowledge base
faq_path = Path(__file__).parent / "knowledge" / "faq.md"
faq = faq_path.read_text(encoding="utf-8")


system_prompt = f"""
You are the QuickBite Customer Support Assistant.

Your job is to answer customer questions about QuickBite.

Use ONLY the information provided in the QuickBite knowledge base below.

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

If the knowledge base does not contain the answer, clearly say that the
information is not available rather than guessing.

Keep responses concise, friendly, and suitable for a customer support chat.

QUICKBITE KNOWLEDGE BASE:
-------------------------
{faq}
-------------------------
"""


response = chat(
    model="qwen3:4b",
    messages=[
        {
            "role": "system",
            "content": system_prompt
        },
        {
            "role": "user",
            "content": 'My order says "Preparing". What does that mean?'
        }
    ]
)


print("\nQuickBite AI:")
print(response.message.content)