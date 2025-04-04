#!/bin/bash

# Define project name and folder
PROJECT_NAME="airflow-webscraper"
mkdir $PROJECT_NAME && cd $PROJECT_NAME

echo "Creating project in $(pwd)..."

# 1. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 2. Install Airflow and dependencies
echo "Installing Airflow and Python dependencies..."
pip install --upgrade pip
pip install apache-airflow requests psycopg2-binary requests beautifulsoup4

# 3. Freeze requirements
pip freeze > requirements.txt

# 4. Create folder structure
mkdir -p dags logs plugins

# 5. Create DAG file

cat <<EOF > dags/etl_web_scraper.py
from airflow import DAG
from airflow.decorators import task
from airflow.utils.dates import days_ago
from bs4 import BeautifulSoup
import requests
import psycopg2
import logging
from datetime import datetime

default_args = {
    "owner": "airflow",
}

with DAG(
    dag_id="etl_web_scraper",
    default_args=default_args,
    schedule_interval=None,
    start_date=days_ago(1),
    catchup=False,
    tags=["etl", "scraping", "quotes"],
) as dag:

    @task
    def extract():
        url = "https://quotes.toscrape.com"
        response = requests.get(url)
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")
        quote_blocks = soup.find_all("div", class_="quote")

        scraped_data = []
        for idx, block in enumerate(quote_blocks):
            quote = block.find("span", class_="text").get_text()
            author = block.find("small", class_="author").get_text()
            tags = [tag.get_text() for tag in block.find_all("a", class_="tag")]

            scraped_data.append({
                "id": idx,
                "quote": quote,
                "author": author,
                "tags": tags,
                "created_at": datetime.utcnow().isoformat()
            })

        return scraped_data

    @task
    def transform(data):
        logging.info("Transforming scraped quotes...")
        return data

    @task
    def load(data):
        logging.info(f"Inserting {len(data)} quotes into the database.")
        conn = psycopg2.connect(
            host="postgres",
            database="scraperdb",
            user="airflow",
            password="airflow"
        )
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS quotes (
                id INTEGER PRIMARY KEY,
                quote TEXT,
                author TEXT,
                tags TEXT[],
                created_at TIMESTAMP
            );
        """)
        for item in data:
            cur.execute("""
                INSERT INTO quotes (id, quote, author, tags, created_at)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING;
            """, (
                item["id"],
                item["quote"],
                item["author"],
                item["tags"],
                item["created_at"]
            ))
        conn.commit()
        cur.close()
        conn.close()

    load(transform(extract()))
EOF

# 6. Create docker-compose.yaml
cat <<EOF > docker-compose.yaml
version: '3.8'

services:
  postgres:
    image: postgres:13
    container_name: airflow-postgres
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: scraperdb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  airflow-webserver:
    image: apache/airflow:2.7.2
    container_name: airflow-webserver
    restart: always
    depends_on:
      - postgres
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/scraperdb
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
      AIRFLOW__LOGGING__REMOTE_LOGGING: 'False'
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
    ports:
      - "8080:8080"
    command: >
      bash -c "
        airflow db init &&
        airflow users create \
          --username admin \
          --password admin \
          --firstname admin \
          --lastname admin \
          --role Admin \
          --email admin@example.com &&
        airflow webserver
      "

  airflow-scheduler:
    image: apache/airflow:2.7.2
    container_name: airflow-scheduler
    restart: always
    depends_on:
      - airflow-webserver
    environment:
      AIRFLOW__CORE__EXECUTOR: LocalExecutor
      AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/scraperdb
      AIRFLOW__LOGGING__REMOTE_LOGGING: 'False'
    volumes:
      - ./dags:/opt/airflow/dags
      - ./logs:/opt/airflow/logs
    command: >
      bash -c "
        airflow scheduler
      "

volumes:
  postgres_data:
EOF

echo "✅ Project created at $(pwd)"
echo "👉 To start:"
echo "   cd $PROJECT_NAME"
echo "   source venv/bin/activate"
echo "   docker compose up --build"

# chmod +x create_airflow_scraper_project.sh
