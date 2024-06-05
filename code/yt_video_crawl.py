
# 국민의힘 유튜브 채널: UCGd1rNecfS_MND8PQsKOJhQ

import os
import google_auth_oauthlib.flow
import googleapiclient.discovery
import googleapiclient.errors
import csv
from datetime import datetime
from dotenv import load_dotenv

# .env 파일에서 API 키 로드
# load_dotenv()
API_KEY = os.getenv('YOUTUBE_API_KEY_GA')

# Create a YouTube Data API client
youtube = googleapiclient.discovery.build('youtube', 'v3', developerKey=API_KEY)

# Replace with the channel ID you want to crawl
channel_id = 'UCGd1rNecfS_MND8PQsKOJhQ'

# Retrieve the channel information
channel_request = youtube.channels().list(
    part='snippet,contentDetails,statistics',
    id=channel_id
)
channel_response = channel_request.execute()

# Extract the playlist ID of the channel's uploaded videos
uploads_playlist_id = channel_response['items'][0]['contentDetails']['relatedPlaylists']['uploads']

# Retrieve the videos in the uploads playlist
video_request = youtube.playlistItems().list(
    part='snippet',
    playlistId=uploads_playlist_id,
    maxResults=50
)

# 크롤링한 데이터를 저장할 디렉토리 생성
os.makedirs('data', exist_ok=True)

# 크롤링 일자
today = datetime.now().strftime('%Y%m%d')

# CSV 파일 경로
csv_file_path = f'data/{channel_id}_{today}_videos.csv'

# CSV 파일 열기
with open(csv_file_path, 'w', newline='', encoding='utf-8') as csv_file:
    # CSV writer 생성
    csv_writer = csv.writer(csv_file)
    
    # 헤더 작성
    csv_writer.writerow(['Video Title', 'Video Description', 'Video URL'])
    
    while video_request:
        video_response = video_request.execute()
        
        # Process each video
        for video in video_response['items']:
            video_title = video['snippet']['title']
            video_description = video['snippet']['description']
            video_url = f"https://www.youtube.com/watch?v={video['snippet']['resourceId']['videoId']}"
            
            # CSV 파일에 비디오 정보 작성
            csv_writer.writerow([video_title, video_description, video_url])
        
        # Check if there are more pages of videos
        video_request = youtube.playlistItems().list_next(video_request, video_response)

print(f"크롤링이 완료되었습니다. 데이터가 {csv_file_path}에 저장되었습니다.")



