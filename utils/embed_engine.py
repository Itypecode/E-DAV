from openai import OpenAI

client = OpenAI(
    base_url = "http://192.168.1.7:1234/v1",
    api_key = "lm-studio"
)

async def embed_text(text: str) -> list:
    try:
        #text = text.replace("\n"," ")
        embeddingVector = client.embeddings.create(
        input = [text],
        model = "text-embedding-nomic-embed-text-v1.5"
        ).data[0].embedding
        print("[EMBEDDING] Vector dimensions:", len(embeddingVector))
        if not embeddingVector:
            raise ValueError("Api failed to return embedding vector...")
        return embeddingVector

    except Exception as e:
        print("[EMBEDDING ERROR]", e)
        return [] 
        