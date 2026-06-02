import time
from groq import Groq

class GroqClient:
    def __init__(self, api_key: str, model: str, sleep_seconds: float = 1.0):
        self.client = Groq(api_key=api_key)
        self.model = model
        self.sleep_seconds = sleep_seconds

    def generate(self, prompt: str) -> str:
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2
        )
        time.sleep(self.sleep_seconds)
        return response.choices[0].message.content or ""