from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import time
from bs4 import BeautifulSoup as BS
import psycopg2
from dotenv import load_dotenv
import os

load_dotenv()

db_user = os.getenv('DB_USER')
db_host = os.getenv('DB_HOST')
db_database = os.getenv('DB_DATABASE')
db_password = os.getenv('DB_PASSWORD')

db_params = {
  'dbname': db_database,
  'user': db_user,
  'password': db_password,
  'host': db_host
}

conn = psycopg2.connect(**db_params)
cur = conn.cursor()

URL = 'https://fashionunited.com/just-in'

options = Options()
options.add_argument('headless')

driver = webdriver.Chrome(service = Service(ChromeDriverManager().install()), options = options)
driver.get(URL)

article_data = []

num_scrolls = 250
scroll_pause_time = 2
previous_length = 0

for _ in range(num_scrolls):
  articles = driver.find_elements(By.CSS_SELECTOR, 'h2.MuiTypography-root.MuiTypography-h5.e1g8p6mc5.css-1h7uhg5')
  current_length = len(articles)
  if articles and current_length > previous_length:
    driver.execute_script("arguments[0].scrollIntoView();", articles[-1])
    time.sleep(scroll_pause_time)
    previous_length = current_length
  else:
    break

soup = BS(driver.page_source, 'html.parser')
article_elements = soup.find_all('h2', class_ = 'MuiTypography-root MuiTypography-h5 e1g8p6mc5 css-1h7uhg5')

for article in article_elements:
  article_name = article.get_text().strip()
  article_data.append(article_name)

driver.quit()

create_trendData_table_query = """
CREATE TABLE IF NOT EXISTS trendData (
    headline TEXT
);
"""
cur.execute(create_trendData_table_query)
conn.commit()

delete_trendData_query = """
DELETE FROM
    trendData;
"""
cur.execute(delete_trendData_query)
conn.commit()

insert_trendData_query = """
INSERT INTO trendData (
    headline
)
VALUES (
    %s
);
"""
for headline in article_data:
  cur.execute(insert_trendData_query, (headline,))
conn.commit()

cur.close()
conn.close()


