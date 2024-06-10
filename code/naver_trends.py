import requests
import json
from dotenv import load_dotenv
import os
import pandas as pd
from datetime import datetime, timedelta

# .env 파일 로드
load_dotenv()

# .env 파일에서 클라이언트 ID와 시크릿 가져오기
client_id = os.getenv('NAVER_CLIENT_ID_PY')
client_secret = os.getenv('NAVER_CLIENT_SECRET_PY')

age_conv = {'1':'0∼12세','2':'13∼18세','3':'19∼24세','4':'25∼29세','5':'30∼34세', 
            '6':'35∼39세','7':'40∼44세','8':'45∼49세','9':'50∼54세','10':'55∼59세','11':'60세 이상'}

def getresult(startDate, endDate, timeUnit, keywordGroups, device, gender, ages):
    url = "https://openapi.naver.com/v1/datalab/search"
    response_results_all = pd.DataFrame()
    
    for age in ages:
        body_dict = {}  # 검색 정보를 저장할 변수
        body_dict['startDate'] = startDate
        body_dict['endDate'] = endDate
        body_dict['timeUnit'] = timeUnit
        body_dict['keywordGroups'] = keywordGroups
        body_dict['device'] = device
        body_dict['gender'] = gender
        body_dict['ages'] = [age]
        
        body = json.dumps(body_dict)
        
        headers = {
            'X-Naver-Client-Id': client_id,
            'X-Naver-Client-Secret': client_secret,
            'Content-Type': 'application/json'
        }
        
        response = requests.post(url, data=body, headers=headers)
        rescode = response.status_code
        
        if rescode == 200:
            response_json = response.json()
        else:
            print("Error Code:" + str(rescode))
            return None
        
        # 결과데이터중 'data'와 'title'만 따로 DataFrame으로 저장
        response_results = pd.DataFrame()
        for data in response_json['results']:
            result = pd.DataFrame(data['data'])
            result['title'] = data['title']
            result['age'] = age_conv[age]  # 연령대 정보를 추가하고 age_conv를 사용하여 변환
            response_results = pd.concat([response_results, result])
        
        response_results_all = pd.concat([response_results_all, response_results])
    
    return response_results_all

# 검색어 설정
keywords = ["김건희", "김정숙", "김혜경"]

# 최근 1년 기간 설정
end_date = datetime.now()
start_date = end_date - timedelta(days=365)
start = start_date.strftime('%Y-%m-%d')
end = end_date.strftime('%Y-%m-%d')

# 검색 조건 설정
timeUnit = "week"
keywordGroups = [{'groupName': keyword, 'keywords': [keyword]} for keyword in keywords]
device = ""
gender = ""
ages = ["3", "4", "5", "6", "7", "8", "9", "10", "11"]

# 검색 결과 가져오기
df = getresult(start, end, timeUnit, keywordGroups, device, gender, ages)

# 데이터프레임 출력
print(df)

# 데이터프레임을 CSV 파일로 저장
df.to_csv('data/trends/naver_trends_data_age_weekly.csv', index=False, encoding='utf-8-sig')
