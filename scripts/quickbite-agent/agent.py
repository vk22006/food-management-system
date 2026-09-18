from ollama import chat

response = chat(
    model="qwen3:4b",
    messages=[
        {
            "role": "user",
            "content": 'A QuickBite customer asks: "My order says Preparing. What does that mean?"'
        }
    ]
)

print(response.message.content)