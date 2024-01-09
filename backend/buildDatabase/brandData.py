from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import time
from bs4 import BeautifulSoup as BS
from fuzzywuzzy import process
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

def find_closest_category(category, official_categories):
  highest_match = process.extractOne(category, official_categories)
  return highest_match[0] if highest_match else category

URL = 'https://fashionunited.com/brands'

options = Options()
options.add_argument('headless')

driver = webdriver.Chrome(service = Service(ChromeDriverManager().install()), options = options)
driver.get(URL)


brand_categories = driver.find_elements(By.CSS_SELECTOR, "div.MuiButtonBase-root.MuiChip-root.MuiChip-clickable")
brand_categories_text = []
brand_categories_to_remove = []
for cat in brand_categories:
  category_name = cat.find_element(By.CSS_SELECTOR, "span.MuiChip-label").text.strip()
  brand_categories_text.append(category_name)
  if category_name == 'All':
    brand_categories_to_remove.append(cat)

brand_categories_text.remove('All')

all_brand_data = []

num_scrolls = 100000
scroll_pause_time = 2
previous_length = 0

for _ in range(num_scrolls):
  brand_elements = driver.find_elements(By.CSS_SELECTOR, 'h2.MuiTypography-root.MuiTypography-h5.css-mz2blv')
  current_length = len(brand_elements)
  if brand_elements and current_length > previous_length:
    driver.execute_script("arguments[0].scrollIntoView();", brand_elements[-1])
    time.sleep(scroll_pause_time)
    previous_length = current_length
  else:
    break
  
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.CSS_SELECTOR, 'h2.MuiTypography-root.MuiTypography-h5.css-mz2blv'))
)

soup = BS(driver.page_source, 'html.parser')
brand_name_elements = soup.find_all('h2', class_ = 'MuiTypography-root MuiTypography-h5 css-mz2blv')
for brand_element in brand_name_elements:
  brand_name = brand_element.get_text().strip()

  li_element = brand_element.find_parent('li')
  if li_element:
    image_element = li_element.find('progressive-img')
    image_url = image_element['src'] if image_element else None
  else:
    image_url = None

  category_element = brand_element.find_next_sibling('div', class_ = 'MuiTypography-root MuiTypography-body2 e9tjgce0 css-19hla7v')
  if category_element:
    uncorrected_categories = category_element.get_text().strip().split(', ')
    category = [find_closest_category(cat, brand_categories_text) for cat in uncorrected_categories]
  else:
    category = []
  
  all_brand_data.append([brand_name, category, image_url])

driver.quit()

create_brandData_table_query = """
CREATE TABLE IF NOT EXISTS brandData (
  brand_name VARCHAR(255),
  category TEXT[],
  image_url TEXT
);
"""
cur.execute(create_brandData_table_query)
conn.commit()

create_brandCategories_table_query = """
CREATE TABLE IF NOT EXISTS brandCategories (
  category_name VARCHAR(255) UNIQUE
);
"""
cur.execute(create_brandCategories_table_query)
conn.commit()

delete_brandData_query = """
DELETE FROM
  brandData;
"""
cur.execute(delete_brandData_query)
conn.commit()

delete_brandCategories_query = """
DELETE FROM
  brandCategories;
"""
cur.execute(delete_brandCategories_query)
conn.commit()

insert_brandData_query = """
INSERT INTO brandData (
  brand_name,
  category,
  image_url
)
VALUES (
  %s,
  %s,
  %s
);
"""
for brand in all_brand_data:
  category_array = '{' + ','.join(brand[1]) + '}'
  cur.execute(insert_brandData_query, (brand[0], category_array, brand[2]))
conn.commit()

insert_brandCategories_query = """
INSERT INTO brandCategories (
  category_name
)
VALUES (
  %s
);
"""
for category in brand_categories_text:
  try:
    cur.execute(insert_brandCategories_query, (category,))
  except psycopg2.errors.UniqueViolation:
    conn.rollback()
conn.commit()

cur.close()
conn.close()






