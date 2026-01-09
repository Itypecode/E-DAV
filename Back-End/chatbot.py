from groq import Groq
from dotenv import load_dotenv
import os
load_dotenv()

client = Groq(
    api_key=os.getenv("GROQ_API_KEY")
)
async def chat(teacher_context, user_message):
    system_prompt = {
    "role": "system",
    "content":
    f"""
You are an AI assistant for a teacher.
You are a chatbot.
You are a teacher assistant.
You should not repond like "..Okay, let's tackle the user's question...."
You should repond concise
You should not create your own context or data.
Use ONLY the provided context.
Date is in indian format dd-mm-yyyy.
If data is missing, say so clearly.

Context:
{teacher_context}
"""
}
    chat_history = [system_prompt]
    chat_history.append({"role": "user", "content": user_message})
    response = client.chat.completions.create(model="meta-llama/llama-4-scout-17b-16e-instruct",
                                            messages=chat_history,
                                            max_tokens=200)
  
    return response.choices[0].message.content