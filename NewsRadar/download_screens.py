import json
import urllib.request
import os

os.makedirs('d:/google_hackathon/NewsRadar/frontend_web', exist_ok=True)

with open('C:/Users/Chaudary Abdullah/.gemini/antigravity/brain/dfee4896-10f4-48cf-ac6f-3b74dafe2680/.system_generated/steps/20/output.txt', 'r', encoding='utf-8') as f:
    data = json.load(f)

for screen in data['screens']:
    title = screen['title'].lower().replace(' ', '_').replace('&', 'and')
    url = screen['htmlCode']['downloadUrl']
    filename = f"d:/google_hackathon/NewsRadar/frontend_web/{title}.html"
    print(f"Downloading {title}...")
    urllib.request.urlretrieve(url, filename)

print("Done downloading all screens!")
