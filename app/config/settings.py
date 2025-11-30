from dotenv import load_dotenv
import os

load_dotenv()

class Settings:
    GROQ_API_KEY = os.getenv("GROQ_API_KEY")
    TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")

    ALLOWED_MODEL_NAMES =[
        "llama-3.1-8b-instant",           # Meta Llama 3.1 8B - Fast, 560 t/s, $0.05/$0.08 per 1M tokens
        "llama-3.3-70b-versatile",        # Meta Llama 3.3 70B - 280 t/s, $0.59/$0.79 per 1M tokens
        "openai/gpt-oss-120b",            # OpenAI GPT OSS 120B - 500 t/s, $0.15/$0.60 per 1M tokens
        "openai/gpt-oss-20b",             # OpenAI GPT OSS 20B - 1000 t/s, $0.075/$0.30 per 1M tokens
        "meta-llama/llama-guard-4-12b"    # Meta Llama Guard 4 12B - Content moderation, 1200 t/s
    ]

settings=Settings()
