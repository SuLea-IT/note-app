import json
with open('translations_filled.json','r',encoding='utf-8') as f:
    data=json.load(f)
print(data.get('笔记'))
