import sys
import asyncio

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json
from crawl4ai import AsyncWebCrawler
from google import genai
from google.genai import types
from notion_client import Client

app = FastAPI()

# Allow Flutter Web to talk to this local API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 1. Define the incoming data from Flutter
class ProcessRequest(BaseModel):
    url: str
    gemini_key: str
    notion_token: str
    database_id: str

# 2. Schema for Gemini
class LinkMetadata(BaseModel):
    category: str
    title: str
    organization: str
    tags: list[str]
    summary: str

@app.post("/process_link")
async def process_link(req: ProcessRequest):
    try:
        markdown = None
        # Step A: Crawl
        async with AsyncWebCrawler() as crawler:
            results = await crawler.arun(url=req.url)
            async for result in results:
                if not result.success:
                    raise HTTPException(status_code=400, detail="Failed to scrape website")
                
                markdown = result.markdown
                break

        if not markdown:
            raise HTTPException(status_code=400, detail="No content scraped")

        # Step B: AI Analysis
        ai_client = genai.Client(api_key=req.gemini_key)

        prompt = f"""
        Analyze this webpage. Is it a JOB POSTING or a YOUTUBE VIDEO?
        Extract category ("Job" or "YouTube"), title, organization, 3 tags, and a summary.
        Content: {markdown[:4000]}
        """

        response = ai_client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=LinkMetadata,
                temperature=0.1
            )
        )

        parsed = response.parsed

        if parsed is None:
            raise HTTPException(status_code=500, detail="AI returned no data")

        # Convert Pydantic model to dictionary
        if isinstance(parsed, LinkMetadata):
            data = parsed.model_dump()  # Use model_dump() for Pydantic v2
        elif isinstance(parsed, dict):
            data = parsed
        else:
            raise HTTPException(status_code=500, detail=f"Unexpected AI response type: {type(parsed)}")

        # Step C: Save to Notion
        notion = Client(auth=req.notion_token)

        notion.pages.create(
            parent={"database_id": req.database_id},
            properties={
                "Name": {"title": [{"text": {"content": data['title']}}]},
                "Category": {"select": {"name": data['category']}},
                "Source": {"url": req.url},
                "Organization": {"rich_text": [{"text": {"content": data['organization']}}]},
                "Tags": {"multi_select": [{"name": tag} for tag in data['tags']]},
                "Summary": {"rich_text": [{"text": {"content": data['summary']}}]}
            }
        )

        return {
            "status": "success",
            "category": data["category"],
            "title": data["title"]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))