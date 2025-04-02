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
pip install apache-airflow requests psycopg2-binary

# 3. Freeze requirements
pip freeze > requirements.txt

# 4. Create folder structure
mkdir -p dags logs plugins

# 5. Create DAG file
cat <<EOF > dags/etl_web_scraper.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import requests
import psycopg2

def extract():
    url = "https://jsonplaceholder.typicode.com/posts"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

def transform(raw_data):
    return [{"id": item["id"], "title": item["title"]} for item in raw_data]

def load(data):
    conn = psycopg2.connect(
        host="postgres",
        database="scraperdb",
        user="airflow",
        password="airflow"
    )
    cur = conn.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS posts (id INTEGER PRIMARY KEY, title TEXT);")
    for item in data:
        cur.execute("INSERT INTO posts (id, title) VALUES (%s, %s) ON CONFLICT (id) DO NOTHING;", (item["id"], item["title"]))
    conn.commit()
    cur.close()
    conn.close()

with DAG(
    dag_id="etl_web_scraper",
    start_date=datetime(2024, 1, 1),
    schedule_interval="@daily",
    catchup=False
) as dag:
    extract_task = PythonOperator(task_id="extract_data", python_callable=extract)
    transform_task = PythonOperator(task_id="transform_data", python_callable=lambda **context: transform(context["ti"].xcom_pull(task_ids="extract_data")), provide_context=True)
    load_task = PythonOperator(task_id="load_data", python_callable=lambda **context: load(context["ti"].xcom_pull(task_ids="transform_data")), provide_context=True)

    extract_task >> transform_task >> load_task
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
