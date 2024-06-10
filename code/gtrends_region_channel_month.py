from pytrends.request import TrendReq
import pandas as pd
from datetime import datetime, timedelta

# pytrends 객체 생성
pytrends = TrendReq(hl='ko-KR', tz=360)

# 관심 검색어 설정
keywords = ["김건희", "김정숙", "김혜경"]

# 시작 날짜와 종료 날짜 설정
start_date = datetime(2023, 5, 1)
end_date = datetime(2024, 6, 30)

# 결과를 저장할 데이터프레임 초기화
all_data = pd.DataFrame()

# 채널별 설정
channels = ['web', 'youtube', 'news', 'images', 'froogle']

# 권역 설정
def get_region(geoName):
    if geoName in ["서울특별시", "인천광역시", "경기도"]:
        return "수도권"
    elif geoName in ["부산광역시", "울산광역시", "경상남도"]:
        return "부울경"
    elif geoName in ["대구광역시", "경상북도"]:
        return "대구경북"
    elif geoName in ["대전광역시", "세종특별자치시", "충청북도", "충청남도"]:
        return "대전충청"
    elif geoName in ["광주광역시", "전라북도", "전라남도"]:
        return "광주전라"
    elif geoName in ["강원도", "제주특별자치도"]:
        return "강원제주"
    else:
        return "기타"

# 월별로 데이터를 수집
while start_date <= end_date:
    # 현재 달의 첫날과 마지막 날 설정
    current_start_date = start_date
    current_end_date = (start_date + timedelta(days=31)).replace(day=1) - timedelta(days=1)
    
    for channel in channels:
        # 검색 채널 설정
        if channel == 'web':
            gprop = ''
        elif channel == 'youtube':
            gprop = 'youtube'
        elif channel == 'news':
            gprop = 'news'
        elif channel == 'images':
            gprop = 'images'
        elif channel == 'froogle':
            gprop = 'froogle'
        
        # 현재 달의 검색어 트렌드 요청
        timeframe = f'{current_start_date.strftime("%Y-%m-%d")} {current_end_date.strftime("%Y-%m-%d")}'
        pytrends.build_payload(keywords, cat=0, timeframe=timeframe, geo='KR', gprop=gprop)
        
        # 지역별 관심도 추출
        interest_by_region_df = pytrends.interest_by_region(resolution='REGION', inc_low_vol=True, inc_geo_code=False)
        interest_by_region_df['timeframe'] = timeframe  # 시간 프레임 추가
        interest_by_region_df['channel'] = channel      # 채널 추가
        all_data = pd.concat([all_data, interest_by_region_df])
    
    # 다음 달로 이동
    start_date = current_end_date + timedelta(days=1)

# 권역별로 데이터 변환
all_data.reset_index(inplace=True)
all_data['권역'] = all_data['geoName'].apply(get_region)

# 데이터프레임 출력
print(all_data)

# 데이터프레임 저장 (옵션)
all_data.to_csv('data/channel/google_trends_data_by_region_and_month_and_channel_kr.csv', index=False)

