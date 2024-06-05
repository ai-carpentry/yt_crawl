################################################################################
# 원내정당 유튜브 채널 크롤링 스크립트
################################################################################

import os
import google_auth_oauthlib.flow
import googleapiclient.discovery
import googleapiclient.errors
from datetime import datetime
# from dotenv import load_dotenv
import pyarrow as pa
import pyarrow.parquet as pq

# .env 파일에서 API 키 로드
# load_dotenv()
API_KEY = os.getenv('YOUTUBE_API_KEY_GA')

# Create a YouTube Data API client
youtube = googleapiclient.discovery.build('youtube', 'v3', developerKey=API_KEY)

# 정당 유튜브 채널 ID 목록
channel_ids = [
    ('민주당', 'UCoQD2xsqwzJA93PTIYERokg'),
    ('국민의힘', 'UCGd1rNecfS_MND8PQsKOJhQ'),
    ('조국혁신당', 'UCKsehTG1cZIeb80J4AyiJ6Q'),
    ('개혁신당', 'UCdkv2W-p3wEK5REQHfu7OKA'),
    ('진보당', 'UCD2FurCIhOsG3FsTM1-jirA'),
    ('새로운미래', 'UC58ySWAGaH5AxRQCk3XGLzA'),
    ('기본소득당', 'UCvtJBm9C0rd6Py-GB8KLH1A'),
    ('사회민주당', 'UCHXfJ__xZs-BAA-tU8L19rQ')
]

# 크롤링한 데이터를 저장할 디렉토리 생성
os.makedirs('data', exist_ok=True)
os.makedirs('data/channel', exist_ok=True)

# 크롤링 일자
today = datetime.now().strftime('%Y%m%d')

for party_name, channel_id in channel_ids:
    # Retrieve the channel information
    channel_request = youtube.channels().list(
        part='snippet,contentDetails,statistics,brandingSettings,topicDetails,status',
        id=channel_id
    )
    channel_response = channel_request.execute()

    # Extract the channel information
    channel_info = channel_response['items'][0]
    channel_name = channel_info['snippet']['title']
    channel_description = channel_info['snippet']['description']
    subscriber_count = int(channel_info['statistics']['subscriberCount'])
    view_count = int(channel_info['statistics']['viewCount'])
    video_count = int(channel_info['statistics']['videoCount'])
    published_at = channel_info['snippet']['publishedAt']

    branding_settings = channel_info['brandingSettings']
    channel_keywords = branding_settings['channel'].get('keywords', '')
    banner_image_url = branding_settings['image']['bannerExternalUrl']

    topic_categories = ', '.join(channel_info['topicDetails']['topicIds'])

    privacy_status = channel_info['status']['privacyStatus']
    is_linked = channel_info['status']['isLinked']

    # Create a dictionary to store the channel information
    channel_data = {
        'Party Name': [party_name],
        'Channel Name': [channel_name],
        'Channel Description': [channel_description],
        'Subscriber Count': [subscriber_count],
        'View Count': [view_count],
        'Video Count': [video_count],
        'Published At': [published_at],
        'Channel Keywords': [channel_keywords],
        'Banner Image URL': [banner_image_url],
        'Topic Categories': [topic_categories],
        'Privacy Status': [privacy_status],
        'Is Linked': [is_linked]
    }

    # Create an Arrow table from the channel data
    table = pa.Table.from_pydict(channel_data)

    # Parquet 파일 경로
    parquet_file_path = f'data/channel/{party_name}_{channel_id}_{today}_channel_info.parquet'

    # Write the Arrow table to a Parquet file
    pq.write_table(table, parquet_file_path)

    print(f"{party_name} 채널 정보 크롤링이 완료되었습니다. 데이터가 {parquet_file_path}에 저장되었습니다.")
    
    
    
