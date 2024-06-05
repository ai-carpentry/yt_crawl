################################################################################
# 유튜브 채널 크롤링 스크립트
################################################################################

# 국민의힘 유튜브 채널: UCGd1rNecfS_MND8PQsKOJhQ
import os
import google_auth_oauthlib.flow
import googleapiclient.discovery
import googleapiclient.errors
from datetime import datetime
from dotenv import load_dotenv
import pyarrow as pa
import pyarrow.parquet as pq

# .env 파일에서 API 키 로드
load_dotenv()
API_KEY = os.getenv('YOUTUBE_API_KEY_GA')

# Create a YouTube Data API client
youtube = googleapiclient.discovery.build('youtube', 'v3', developerKey=API_KEY)

# Replace with the channel ID you want to crawl
channel_id = 'UCGd1rNecfS_MND8PQsKOJhQ'

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
channel_keywords = branding_settings['channel']['keywords']
banner_image_url = branding_settings['image']['bannerExternalUrl']

topic_categories = ', '.join(channel_info['topicDetails']['topicIds'])

privacy_status = channel_info['status']['privacyStatus']
is_linked = channel_info['status']['isLinked']

# Create a dictionary to store the channel information
channel_data = {
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

# 크롤링한 데이터를 저장할 디렉토리 생성
os.makedirs('data', exist_ok=True)

# 크롤링 일자
today = datetime.now().strftime('%Y%m%d')

# Parquet 파일 경로
parquet_file_path = f'data/{channel_id}_{today}_channel_info.parquet'

# Write the Arrow table to a Parquet file
pq.write_table(table, parquet_file_path)

print(f"채널 정보 크롤링이 완료되었습니다. 데이터가 {parquet_file_path}에 저장되었습니다.")
