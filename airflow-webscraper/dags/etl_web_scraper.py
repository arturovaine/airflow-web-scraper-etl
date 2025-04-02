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
